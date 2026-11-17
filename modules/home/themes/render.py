#!/usr/bin/env python3
# usage: render.py <targets.json> <out> <scheme>=<tokens.json>...
#
# Writes every target once per colour scheme, to <out>/<scheme>/<target>, with each `{{token}}` replaced by that
# scheme's value. Every colour token also comes as `<token>-hex`, without the `#`, which base16 templates use
import json, os, re, sys

targets = json.load(open(sys.argv[1]))
out = sys.argv[2]

for arg in sys.argv[3:]:
    scheme, path = arg.split("=", 1)
    tokens = json.load(open(path))
    tokens.update({f"{k}-hex": v[1:] for k, v in list(tokens.items()) if v.startswith("#")})

    d = os.path.join(out, scheme)
    os.makedirs(d)
    for name, text in targets.items():
        def token(m):
            if m.group(1) not in tokens:
                sys.exit(f"theme target {name}: unknown token {m.group(1)}, there are: {' '.join(sorted(tokens))}")
            return tokens[m.group(1)]

        open(os.path.join(d, name), "w").write(re.sub(r"\{\{([\w-]+)\}\}", token, text))
