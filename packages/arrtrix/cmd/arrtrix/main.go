package main

import (
	"sneeuwvlok/packages/arrtrix/pkg/connector"
	"sneeuwvlok/packages/arrtrix/pkg/runtime"
)

var (
	Tag       = "unknown"
	Commit    = "unknown"
	BuildTime = "unknown"
)

var m = runtime.Main{
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
