#!/usr/bin/env python3
# usage: render.py <targets.json> <out> <scheme>=<tokens.json>...
#
# Writes every target once per colour scheme, to <out>/<scheme>/<target>, with each `{{token}}` replaced by that
# scheme's value. Every colour token also comes as `<token>-hex`, without the `#`, which base16 templates use, and as
# `<token>-rgb`, `r, g, b` in decimal
import json, os, re, sys

targets = json.load(open(sys.argv[1]))
out = sys.argv[2]

for arg in sys.argv[3:]:
    scheme, path = arg.split("=", 1)
    tokens = json.load(open(path))
    colours = {k: v[1:] for k, v in tokens.items() if v.startswith("#")}
    tokens.update({f"{k}-hex": v for k, v in colours.items()})
    tokens.update({f"{k}-rgb": ", ".join(str(int(v[i:i + 2], 16)) for i in (0, 2, 4)) for k, v in colours.items()})

    d = os.path.join(out, scheme)
    os.makedirs(d)
    for name, text in targets.items():
        def token(m):
            if m.group(1) not in tokens:
                sys.exit(f"theme target {name}: unknown token {m.group(1)}, there are: {' '.join(sorted(tokens))}")
            return tokens[m.group(1)]

        open(os.path.join(d, name), "w").write(re.sub(r"\{\{([\w-]+)\}\}", token, text))
