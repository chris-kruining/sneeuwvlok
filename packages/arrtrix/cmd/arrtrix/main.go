package main

import (
	"maunium.net/go/mautrix/bridgev2/matrix/mxmain"

	"sneeuwvlok/packages/arrtrix/pkg/connector"
)

var (
	Tag       = "unknown"
	Commit    = "unknown"
	BuildTime = "unknown"
)

var m = mxmain.BridgeMain{
	Name:        "arrtrix",
	URL:         "https://github.com/chris-kruining/sneeuwvlok",
	Description: "An Arr-focused Matrix appservice bridge.",
	Version:     "0.1.0",
	Connector:   &connector.ArrtrixConnector{},
}

func main() {
	m.InitVersion(Tag, Commit, BuildTime)
	m.Run()
}
