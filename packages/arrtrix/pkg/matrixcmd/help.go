package matrixcmd

import (
	"fmt"
	"sort"
	"strings"
)

func NewHelpHandler(proc *Processor) Handler {
	return NewHandler(Meta{
		Name:        "help",
		Description: "Show this help message.",
	}, func(ctx *Context) {
		ctx.Reply(formatHelp(proc, ctx))
	})
}

func formatHelp(proc *Processor, ctx *Context) string {
	var builder strings.Builder

	switch {
	case ctx.RoomID == ctx.User.ManagementRoom:
		builder.WriteString(fmt.Sprintf("This is your management room: prefixing commands with `%s` is not required.\n", ctx.Bridge.Config.CommandPrefix))
	case ctx.Portal != nil:
		builder.WriteString(fmt.Sprintf("**This is a portal room**: you must always prefix commands with `%s`. Management commands will not be bridged.\n", ctx.Bridge.Config.CommandPrefix))
	default:
		builder.WriteString(fmt.Sprintf("This is not your management room: prefixing commands with `%s` is required.\n", ctx.Bridge.Config.CommandPrefix))
	}

	builder.WriteString("Parameters in [square brackets] are optional, while parameters in <angle brackets> are required.\n\n")
	builder.WriteString("#### General\n")

	handlers := proc.Handlers()
	sort.SliceStable(handlers, func(i, j int) bool {
		return handlers[i].Meta().Name < handlers[j].Meta().Name
	})
	for _, handler := range handlers {
		meta := handler.Meta()
		builder.WriteString("**")
		builder.WriteString(meta.Name)
		builder.WriteString("**")
		if meta.Usage != "" {
			builder.WriteByte(' ')
			builder.WriteString(meta.Usage)
		}
		if meta.Description != "" {
			builder.WriteString(" - ")
			builder.WriteString(meta.Description)
		}
		builder.WriteByte('\n')
	}

	if extra := strings.TrimSpace(ctx.Processor.texts.AdditionalHelp); extra != "" {
		builder.WriteByte('\n')
		builder.WriteString(extra)
		builder.WriteByte('\n')
	}

	return builder.String()
}
