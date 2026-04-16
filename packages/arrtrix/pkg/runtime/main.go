package runtime

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"strings"
	"syscall"
	"time"

	"github.com/rs/zerolog"
	"go.mau.fi/util/dbutil"
	"go.mau.fi/util/exerrors"
	"go.mau.fi/util/exzerolog"
	"go.mau.fi/util/progver"
	"gopkg.in/yaml.v3"
	flag "maunium.net/go/mauflag"
	"maunium.net/go/mautrix/appservice"

	"maunium.net/go/mautrix"
	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/bridgev2/bridgeconfig"
	"maunium.net/go/mautrix/bridgev2/commands"
	"maunium.net/go/mautrix/bridgev2/matrix"
	"maunium.net/go/mautrix/event"

	arrconfig "sneeuwvlok/packages/arrtrix/pkg/config"
	"sneeuwvlok/packages/arrtrix/pkg/matrixcmd"
	"sneeuwvlok/packages/arrtrix/pkg/onboarding"
)

var configPath = flag.MakeFull("c", "config", "The path to your config file.", "config.yaml").String()
var writeExampleConfig = flag.MakeFull("e", "generate-example-config", "Save the example config to the config path and quit.", "false").Bool()
var dontSaveConfig = flag.MakeFull("n", "no-update", "Don't save updated config to disk.", "false").Bool()
var registrationPath = flag.MakeFull("r", "registration", "The path where to save the appservice registration.", "registration.yaml").String()
var generateRegistration = flag.MakeFull("g", "generate-registration", "Generate registration and quit.", "false").Bool()
var version = flag.MakeFull("v", "version", "View bridge version and quit.", "false").Bool()
var versionJSON = flag.Make().LongKey("version-json").Usage("Print a JSON object representing the bridge version and quit.").Default("false").Bool()
var ignoreUnsupportedDatabase = flag.Make().LongKey("ignore-unsupported-database").Usage("Run even if the database schema is too new").Default("false").Bool()
var ignoreForeignTables = flag.Make().LongKey("ignore-foreign-tables").Usage("Run even if the database contains tables from other programs (like Synapse)").Default("false").Bool()
var ignoreUnsupportedServer = flag.Make().LongKey("ignore-unsupported-server").Usage("Run even if the Matrix homeserver is outdated").Default("false").Bool()
var wantHelp, _ = flag.MakeHelpFlag()

type Main struct {
	Name        string
	Description string
	URL         string
	Version     string

	Connector bridgev2.NetworkConnector
	PostInit  func()
	PostStart func()

	Log          *zerolog.Logger
	DB           *dbutil.Database
	PublicConfig *arrconfig.Config
	Config       *bridgeconfig.Config
	Matrix       *matrix.Connector
	Bridge       *bridgev2.Bridge

	ConfigPath       string
	RegistrationPath string
	SaveConfig       bool

	ver        progver.ProgramVersion
	manualStop chan int
}

type versionJSONOutput struct {
	progver.ProgramVersion

	OS   string
	Arch string

	Mautrix struct {
		Version string
		Commit  string
	}
}

type routeMounter interface {
	MountRoutes(*http.ServeMux) error
}

func (m *Main) Run() {
	m.PreInit()
	m.Init()
	m.Start()
	exitCode := m.WaitForInterrupt()
	m.Stop()
	os.Exit(exitCode)
}

func (m *Main) PreInit() {
	m.manualStop = make(chan int, 1)
	flag.SetHelpTitles(
		fmt.Sprintf("%s - %s", m.Name, m.Description),
		fmt.Sprintf("%s [-hgvn] [-c <path>] [-r <path>]", m.Name),
	)

	err := flag.Parse()
	m.ConfigPath = *configPath
	m.RegistrationPath = *registrationPath
	m.SaveConfig = !*dontSaveConfig
	if err != nil {
		_, _ = fmt.Fprintln(os.Stderr, err)
		flag.PrintHelp()
		os.Exit(1)
	}

	switch {
	case *wantHelp:
		flag.PrintHelp()
		os.Exit(0)
	case *version:
		fmt.Println(m.ver.VersionDescription)
		os.Exit(0)
	case *versionJSON:
		output := versionJSONOutput{
			ProgramVersion: m.ver,
			OS:             runtime.GOOS,
			Arch:           runtime.GOARCH,
		}
		output.Mautrix.Version = mautrix.Version
		output.Mautrix.Commit = mautrix.Commit
		_ = json.NewEncoder(os.Stdout).Encode(output)
		os.Exit(0)
	case *writeExampleConfig:
		m.writeExampleConfig()
		os.Exit(0)
	}

	m.LoadConfig()
	if *generateRegistration {
		m.GenerateRegistration()
		os.Exit(0)
	}
}

func (m *Main) writeExampleConfig() {
	if *configPath != "-" {
		if _, err := os.Stat(*configPath); !errors.Is(err, os.ErrNotExist) {
			_, _ = fmt.Fprintln(os.Stderr, *configPath, "already exists, please remove it if you want to generate a new example")
			os.Exit(1)
		}
	}

	networkExample, _, _ := m.Connector.GetConfig()
	example := makeExampleConfig(m.Connector.GetName(), networkExample)
	if *configPath == "-" {
		fmt.Print(example)
		return
	}

	exerrors.PanicIfNotNil(os.WriteFile(*configPath, []byte(example), 0o600))
	fmt.Println("Wrote example config to", *configPath)
}

func (m *Main) GenerateRegistration() {
	if !m.SaveConfig {
		_, _ = fmt.Fprintln(os.Stderr, "--no-update is not compatible with --generate-registration")
		os.Exit(5)
	}
	if m.Config.Homeserver.Domain == "example.com" {
		_, _ = fmt.Fprintln(os.Stderr, "Homeserver domain is not set")
		os.Exit(20)
	}

	registration := m.Config.GenerateRegistration()
	if err := registration.Save(m.RegistrationPath); err != nil {
		_, _ = fmt.Fprintln(os.Stderr, "Failed to save registration:", err)
		os.Exit(21)
	}

	if err := m.saveConfig(); err != nil {
		_, _ = fmt.Fprintln(os.Stderr, "Failed to save config:", err)
		os.Exit(22)
	}

	fmt.Println("Registration generated. See https://docs.mau.fi/bridges/general/registering-appservices.html for instructions on installing the registration.")
}

func (m *Main) LoadConfig() {
	configData, err := os.ReadFile(m.ConfigPath)
	if err != nil {
		_, _ = fmt.Fprintln(os.Stderr, "Failed to read config:", err)
		os.Exit(10)
	}

	publicConfig, err := arrconfig.Load(configData)
	if err != nil {
		_, _ = fmt.Fprintln(os.Stderr, "Failed to parse config:", err)
		os.Exit(10)
	}
	cfg := publicConfig.Compile()
	if err = m.loadRegistrationTokens(&cfg); err != nil {
		_, _ = fmt.Fprintln(os.Stderr, "Failed to parse registration:", err)
		os.Exit(10)
	}

	_, networkData, _ := m.Connector.GetConfig()
	if networkData != nil {
		if err = cfg.Network.Decode(networkData); err != nil {
			_, _ = fmt.Fprintln(os.Stderr, "Failed to parse network config:", err)
			os.Exit(10)
		}
	}

	cfg.Bridge.Backfill = cfg.Backfill
	if err = updateConfigFromEnv(&cfg, networkData, cfg.EnvConfigPrefix); err != nil {
		_, _ = fmt.Fprintln(os.Stderr, "Failed to parse environment variables:", err)
		os.Exit(10)
	}

	m.PublicConfig = publicConfig
	m.Config = &cfg
}

func (m *Main) loadRegistrationTokens(cfg *bridgeconfig.Config) error {
	if m.RegistrationPath == "" {
		return nil
	}

	data, err := os.ReadFile(m.RegistrationPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil {
		return err
	}

	var tokens struct {
		AppToken    string `yaml:"as_token"`
		ServerToken string `yaml:"hs_token"`
	}
	if err = yaml.Unmarshal(data, &tokens); err != nil {
		return err
	}

	if tokens.AppToken != "" {
		cfg.AppService.ASToken = tokens.AppToken
	}
	if tokens.ServerToken != "" {
		cfg.AppService.HSToken = tokens.ServerToken
	}
	return nil
}

func (m *Main) Init() {
	var err error
	m.Log, err = m.Config.Logging.Compile()
	if err != nil {
		_, _ = fmt.Fprintln(os.Stderr, "Failed to initialize logger:", err)
		os.Exit(12)
	}
	exzerolog.SetupDefaults(m.Log)

	if err = m.validateConfig(); err != nil {
		m.Log.WithLevel(zerolog.FatalLevel).Err(err).Msg("Configuration error")
		m.Log.Info().Msg("See https://docs.mau.fi/faq/field-unconfigured for more info")
		os.Exit(11)
	}

	m.Log.Info().
		Str("name", m.Name).
		Str("version", m.ver.FormattedVersion).
		Time("built_at", m.ver.BuildTime).
		Str("go_version", runtime.Version()).
		Msg("Initializing bridge")

	m.initDB()
	m.Matrix = matrix.NewConnector(m.Config)
	m.Matrix.OnWebsocketReplaced = func() {
		m.TriggerStop(0)
	}
	m.Matrix.IgnoreUnsupportedServer = *ignoreUnsupportedServer
	m.Bridge = bridgev2.NewBridge("", m.DB, *m.Log, &m.Config.Bridge, m.Matrix, m.Connector, commands.NewProcessor)
	m.Bridge.Commands = matrixcmd.NewProcessor(m.Bridge, m.Config.ManagementRoomTexts)

	if m.Matrix.EventProcessor != nil {
		if m.Config.AppService.AsyncTransactions {
			m.Matrix.EventProcessor.ExecMode = appservice.AsyncLoop
		} else {
			m.Matrix.EventProcessor.ExecMode = appservice.Sync
		}
		m.Matrix.EventProcessor.PrependHandler(event.StateMember, func(ctx context.Context, evt *event.Event) {
			onboarding.HandleBotInvite(ctx, m.Bridge, m.Config.ManagementRoomTexts, evt)
		})
	}

	m.Matrix.AS.DoublePuppetValue = m.Name
	if mounter, ok := m.Connector.(routeMounter); ok {
		if err = mounter.MountRoutes(m.Matrix.AS.Router); err != nil {
			_, _ = fmt.Fprintln(os.Stderr, "Failed to mount HTTP routes:", err)
			os.Exit(13)
		}
	}

	if m.PostInit != nil {
		m.PostInit()
	}
}

func (m *Main) Start() {
	ctx := m.Log.WithContext(context.Background())
	if err := m.Bridge.Start(ctx); err != nil {
		m.Log.Fatal().Err(err).Msg("Failed to start bridge")
	}
	if m.PostStart != nil {
		m.PostStart()
	}
}

func (m *Main) Stop() {
	m.Bridge.StopWithTimeout(5 * time.Second)
}

func (m *Main) WaitForInterrupt() int {
	interrupts := make(chan os.Signal, 1)
	signal.Notify(interrupts, os.Interrupt, syscall.SIGTERM)
	select {
	case <-interrupts:
		m.Log.Info().Msg("Interrupt signal received from OS")
		return 0
	case exitCode := <-m.manualStop:
		m.Log.Info().Msg("Internal stop signal received")
		return exitCode
	}
}

func (m *Main) TriggerStop(exitCode int) {
	select {
	case m.manualStop <- exitCode:
	default:
	}
}

func (m *Main) InitVersion(tag, commit, rawBuildTime string) {
	m.ver = progver.ProgramVersion{
		Name:        m.Name,
		URL:         m.URL,
		BaseVersion: m.Version,
	}.Init(tag, commit, rawBuildTime)
	mautrix.DefaultUserAgent = fmt.Sprintf("%s/%s %s", m.Name, m.ver.FormattedVersion, mautrix.DefaultUserAgent)
	m.Version = m.ver.FormattedVersion
}

func (m *Main) validateConfig() error {
	switch {
	case m.Config.Homeserver.Address == "http://example.localhost:8008":
		return errors.New("homeserver.address not configured")
	case m.Config.Homeserver.Domain == "example.com":
		return errors.New("homeserver.domain not configured")
	case !bridgeconfig.AllowedHomeserverSoftware[m.Config.Homeserver.Software]:
		return errors.New("invalid value for homeserver.software (use `standard` if you don't know what the field is for)")
	case m.Config.AppService.ASToken == "This value is generated when generating the registration":
		return errors.New("appservice.as_token not configured. Did you forget to generate the registration?")
	case m.Config.AppService.HSToken == "This value is generated when generating the registration":
		return errors.New("appservice.hs_token not configured. Did you forget to generate the registration?")
	case m.Config.Database.URI == "postgres://user:password@host/database?sslmode=disable":
		return errors.New("database.uri not configured")
	case !m.Config.Bridge.Permissions.IsConfigured():
		return errors.New("bridge.permissions not configured")
	case !strings.Contains(m.Config.AppService.FormatUsername("1234567890"), "1234567890"):
		return errors.New("username template is missing user ID placeholder")
	default:
		if validator, ok := m.Connector.(bridgev2.ConfigValidatingNetwork); ok {
			return validator.ValidateConfig()
		}
		return nil
	}
}

func (m *Main) initDB() {
	if m.Config.Database.Type == "sqlite3" {
		m.Log.WithLevel(zerolog.FatalLevel).Msg("Invalid database type sqlite3. Use sqlite3-fk-wal instead.")
		os.Exit(14)
	}
	if (m.Config.Database.Type == "sqlite3-fk-wal" || m.Config.Database.Type == "litestream") &&
		m.Config.Database.MaxOpenConns != 1 &&
		!strings.Contains(m.Config.Database.URI, "_txlock=immediate") {
		var fixedURI string
		switch {
		case !strings.HasPrefix(m.Config.Database.URI, "file:"):
			fixedURI = fmt.Sprintf("file:%s?_txlock=immediate", m.Config.Database.URI)
		case !strings.ContainsRune(m.Config.Database.URI, '?'):
			fixedURI = fmt.Sprintf("%s?_txlock=immediate", m.Config.Database.URI)
		default:
			fixedURI = fmt.Sprintf("%s&_txlock=immediate", m.Config.Database.URI)
		}
		m.Log.Warn().Str("fixed_uri_example", fixedURI).Msg("Using SQLite without _txlock=immediate is not recommended")
	}

	var err error
	m.DB, err = dbutil.NewFromConfig("megabridge/"+m.Name, m.Config.Database, dbutil.ZeroLogger(m.Log.With().Str("db_section", "main").Logger()))
	if err != nil {
		m.Log.WithLevel(zerolog.FatalLevel).Err(err).Msg("Failed to initialize database connection")
		os.Exit(14)
	}
	m.DB.IgnoreUnsupportedDatabase = *ignoreUnsupportedDatabase
	m.DB.IgnoreForeignTables = *ignoreForeignTables
}

func (m *Main) saveConfig() error {
	publicConfig := *m.PublicConfig
	publicConfig.AppService.ASToken = m.Config.AppService.ASToken
	publicConfig.AppService.HSToken = m.Config.AppService.HSToken

	configData, err := yaml.Marshal(&publicConfig)
	if err != nil {
		return err
	}
	return os.WriteFile(m.ConfigPath, configData, 0o600)
}
