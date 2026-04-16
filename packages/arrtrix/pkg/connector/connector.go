package connector

import (
	"context"
	"fmt"

	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/bridgev2/database"
	"maunium.net/go/mautrix/bridgev2/networkid"
	"maunium.net/go/mautrix/event"
	"maunium.net/go/mautrix/id"
)

type ArrtrixConnector struct {
	Bridge *bridgev2.Bridge
	Config Config
}

var _ bridgev2.NetworkConnector = (*ArrtrixConnector)(nil)

func (s *ArrtrixConnector) GetName() bridgev2.BridgeName {
	return bridgev2.BridgeName{
		DisplayName:          "Arrtrix",
		NetworkURL:           "https://wiki.servarr.com/",
		NetworkID:            "arrtrix",
		BeeperBridgeType:     "arrtrix",
		DefaultPort:          29329,
		DefaultCommandPrefix: "!arr",
	}
}

func (s *ArrtrixConnector) Init(bridge *bridgev2.Bridge) {
	s.Bridge = bridge
}

func (s *ArrtrixConnector) Start(context.Context) error {
	return nil
}

func (s *ArrtrixConnector) GetDBMetaTypes() database.MetaTypes {
	return database.MetaTypes{}
}

func (s *ArrtrixConnector) GetCapabilities() *bridgev2.NetworkGeneralCapabilities {
	return &bridgev2.NetworkGeneralCapabilities{}
}

func (s *ArrtrixConnector) LoadUserLogin(_ context.Context, login *bridgev2.UserLogin) error {
	login.Client = &ArrtrixClient{
		Main:      s,
		UserLogin: login,
	}
	return nil
}

func (s *ArrtrixConnector) GetLoginFlows() []bridgev2.LoginFlow {
	return nil
}

func (s *ArrtrixConnector) CreateLogin(_ context.Context, _ *bridgev2.User, flowID string) (bridgev2.LoginProcess, error) {
	return nil, fmt.Errorf("login flow %q is not implemented", flowID)
}

func (s *ArrtrixConnector) GetBridgeInfoVersion() (info, capabilities int) {
	return 1, 1
}

type ArrtrixClient struct {
	Main      *ArrtrixConnector
	UserLogin *bridgev2.UserLogin
}

var _ bridgev2.NetworkAPI = (*ArrtrixClient)(nil)

func (c *ArrtrixClient) Connect(context.Context) {}

func (c *ArrtrixClient) Disconnect() {}

func (c *ArrtrixClient) IsLoggedIn() bool {
	return false
}

func (c *ArrtrixClient) LogoutRemote(context.Context) {}

func (c *ArrtrixClient) IsThisUser(context.Context, networkid.UserID) bool {
	return false
}

func (c *ArrtrixClient) GetChatInfo(context.Context, *bridgev2.Portal) (*bridgev2.ChatInfo, error) {
	return &bridgev2.ChatInfo{}, nil
}

func (c *ArrtrixClient) GetUserInfo(context.Context, *bridgev2.Ghost) (*bridgev2.UserInfo, error) {
	return &bridgev2.UserInfo{}, nil
}

func (c *ArrtrixClient) GetCapabilities(context.Context, *bridgev2.Portal) *event.RoomFeatures {
	return &event.RoomFeatures{}
}

func (c *ArrtrixClient) HandleMatrixMessage(context.Context, *bridgev2.MatrixMessage) (*bridgev2.MatrixMessageResponse, error) {
	return nil, fmt.Errorf("bridging Matrix messages is not implemented")
}

func (c *ArrtrixClient) GenerateTransactionID(userID id.UserID, roomID id.RoomID, eventType event.Type) networkid.RawTransactionID {
	return networkid.RawTransactionID("")
}
