package matrixcmd

import (
	"context"
	"fmt"
	"runtime/debug"
	"sort"
	"strings"

	"github.com/rs/zerolog"

	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/bridgev2/bridgeconfig"
	"maunium.net/go/mautrix/bridgev2/status"
	"maunium.net/go/mautrix/event"
	"maunium.net/go/mautrix/format"
	"maunium.net/go/mautrix/id"
)

type Handler interface {
	Meta() Meta
	Run(*Context)
}

type Meta struct {
	Name        string
	Description string
	Usage       string
	Aliases     []string
}

type HandlerFunc struct {
	meta Meta
	run  func(*Context)
}

func NewHandler(meta Meta, run func(*Context)) Handler {
	return HandlerFunc{meta: meta, run: run}
}

func (h HandlerFunc) Meta() Meta {
	return h.meta
}

func (h HandlerFunc) Run(ctx *Context) {
	h.run(ctx)
}

type Processor struct {
	bridge  *bridgev2.Bridge
	bot     bridgev2.MatrixAPI
	texts   bridgeconfig.ManagementRoomTexts
	command map[string]Handler
	alias   map[string]string
	order   []string
}

type Context struct {
	Bridge     *bridgev2.Bridge
	Bot        bridgev2.MatrixAPI
	RoomID     id.RoomID
	OrigRoomID id.RoomID
	EventID    id.EventID
	ReplyTo    id.EventID
	User       *bridgev2.User
	Portal     *bridgev2.Portal
	Command    string
	Args       []string
	RawArgs    string
	Ctx        context.Context
	Log        *zerolog.Logger
	Processor  *Processor
}

var _ bridgev2.CommandProcessor = (*Processor)(nil)

func NewProcessor(bridge *bridgev2.Bridge, texts bridgeconfig.ManagementRoomTexts) *Processor {
	proc := &Processor{
		bridge:  bridge,
		bot:     bridge.Bot,
		texts:   texts,
		command: make(map[string]Handler),
		alias:   make(map[string]string),
	}
	proc.Add(NewHelpHandler(proc))
	return proc
}

func (p *Processor) Add(handler Handler) {
	meta := handler.Meta()
	p.command[meta.Name] = handler
	p.order = append(p.order, meta.Name)
	for _, alias := range meta.Aliases {
		p.alias[alias] = meta.Name
	}
}

func (p *Processor) Handlers() []Handler {
	names := append([]string(nil), p.order...)
	sort.Strings(names)

	handlers := make([]Handler, 0, len(names))
	for _, name := range names {
		handler, ok := p.command[name]
		if ok {
			handlers = append(handlers, handler)
		}
	}
	return handlers
}

func (p *Processor) Handle(ctx context.Context, roomID id.RoomID, eventID id.EventID, user *bridgev2.User, message string, replyTo id.EventID) {
	ms := &bridgev2.MessageStatus{
		Step:   status.MsgStepCommand,
		Status: event.MessageStatusSuccess,
	}

	logCopy := zerolog.Ctx(ctx).With().Logger()
	log := &logCopy

	defer func() {
		statusInfo := &bridgev2.MessageStatusEventInfo{
			RoomID:        roomID,
			SourceEventID: eventID,
			EventType:     event.EventMessage,
			Sender:        user.MXID,
		}

		if recovered := recover(); recovered != nil {
			logEvt := log.Error().Bytes(zerolog.ErrorStackFieldName, debug.Stack())
			if err, ok := recovered.(error); ok {
				logEvt = logEvt.Err(err)
				ms.InternalError = err
			} else {
				logEvt = logEvt.Any(zerolog.ErrorFieldName, recovered)
				ms.InternalError = fmt.Errorf("%v", recovered)
			}
			logEvt.Msg("Panic in arrtrix Matrix command handler")
			ms.Status = event.MessageStatusFail
			ms.IsCertain = true
			ms.ErrorAsMessage = true
		}

		p.bridge.Matrix.SendMessageStatus(ctx, ms, statusInfo)
	}()

	args := strings.Fields(message)
	if len(args) == 0 {
		args = []string{"unknown-command"}
	}

	commandName := strings.ToLower(args[0])
	if actual, ok := p.alias[commandName]; ok {
		commandName = actual
	}

	portal, err := p.bridge.GetPortalByMXID(ctx, roomID)
	if err != nil {
		log.Err(err).Msg("Failed to get portal")
	}

	commandCtx := &Context{
		Bridge:     p.bridge,
		Bot:        p.bot,
		RoomID:     roomID,
		OrigRoomID: roomID,
		EventID:    eventID,
		ReplyTo:    replyTo,
		User:       user,
		Portal:     portal,
		Command:    commandName,
		Args:       args[1:],
		RawArgs:    strings.TrimSpace(strings.TrimPrefix(message, args[0])),
		Ctx:        ctx,
		Log:        log,
		Processor:  p,
	}

	handler, ok := p.command[commandName]
	if !ok {
		log.Debug().Str("mx_command", commandName).Msg("Received unknown Matrix room command")
		commandCtx.Reply("Unknown command, use the `help` command for help.")
		return
	}

	log.UpdateContext(func(c zerolog.Context) zerolog.Context {
		return c.Str("mx_command", commandName)
	})
	log.Debug().Msg("Received Matrix room command")
	handler.Run(commandCtx)
}

func (c *Context) Reply(message string, args ...any) {
	message = strings.ReplaceAll(message, "$cmdprefix ", c.Bridge.Config.CommandPrefix+" ")
	if len(args) > 0 {
		message = fmt.Sprintf(message, args...)
	}

	content := format.RenderMarkdown(message, true, false)
	content.MsgType = event.MsgNotice
	if _, err := c.Bot.SendMessage(c.Ctx, c.OrigRoomID, event.EventMessage, &event.Content{Parsed: &content}, nil); err != nil {
		c.Log.Err(err).Msg("Failed to reply to Matrix room command")
	}
}
