#!/usr/bin/env python3
# usage: wallpaper-themes.py <matugen> <papirus share/icons> <out> <name>=<image>...
#
# For every wallpaper: a plasma colour scheme `Wallpaper-<name>` with the whole palette taken from the wallpaper
# (material you, through matugen), a ghostty palette and the papirus folder colour nearest its accent. The folder
# colours used get their own icon theme `Papirus-Accent-<colour>`, so switching is just picking another theme.
import colorsys, json, os, re, subprocess, sys

matugen, papirus, out = sys.argv[1:4]
walls = [a.split("=", 1) for a in sys.argv[4:]]

FOLDERS = dict(blue="#5294e2", bluegrey="#607d8b", breeze="#57b8ec", brown="#ae8e6c", carmine="#a30002",
               cyan="#00bcd4", darkcyan="#45abb7", deeporange="#e95420", green="#87b158", indigo="#5c6bc0",
               magenta="#ca71df", nordic="#81a1c1", orange="#ee923a", paleorange="#eeca8f", pink="#ec407a",
               red="#e25252", teal="#16a085", violet="#7e57c2", yellow="#f9bd30")


def rgb(h): return tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
def kde(h): return ",".join(map(str, rgb(h)))
def hexc(t): return "#%02x%02x%02x" % tuple(max(0, min(255, round(x))) for x in t)
def mix(a, b, t): return hexc(x + (y - x) * t for x, y in zip(rgb(a), rgb(b)))
def hls(h): return colorsys.rgb_to_hls(*[x / 255 for x in rgb(h)])


def palette(image):
    res = subprocess.run([matugen, "image", image, "-m", "dark", "--dry-run", "-j", "hex", "--prefer", "saturation"],
                         capture_output=True, text=True, check=True).stdout
    c = {k: v["dark"]["color"] for k, v in json.loads(res)["colors"].items()}
    # material's dark surfaces are almost grey, tint them towards the wallpaper like everforest's backgrounds
    for k in list(c):
        if k.startswith("surface") and k not in ("surface_tint", "surface_variant"):
            c[k] = mix(c[k], c["primary_container"], 0.22)
    return c


def ansi(c):
    ph = hls(c["primary"])[0] * 360

    # the usual terminal hues, nudged a little towards the accent so they sit with the wallpaper
    def harmonize(hue):
        d = ((ph - hue + 180) % 360) - 180
        h = (hue + max(-15, min(15, d * 0.5))) % 360
        return hexc(x * 255 for x in colorsys.hls_to_rgb(h / 360, 0.68, 0.55))

    return {n: harmonize(h) for n, h in dict(red=5, green=110, yellow=45, blue=215, magenta=300, cyan=180).items()}


def scheme(name, c, a):
    def section(title, body): return f"[{title}]\n" + "".join(f"{k}={v}\n" for k, v in body.items()) + "\n"

    def group(bg, alt):
        return dict(
            BackgroundNormal=kde(bg), BackgroundAlternate=kde(alt),
            DecorationFocus=kde(c["primary"]), DecorationHover=kde(c["primary"]),
            ForegroundNormal=kde(c["on_surface"]), ForegroundInactive=kde(c["on_surface_variant"]),
            ForegroundActive=kde(c["primary"]), ForegroundLink=kde(c["primary"]),
            ForegroundVisited=kde(c["tertiary"]), ForegroundNegative=kde(c["error"]),
            ForegroundNeutral=kde(a["yellow"]), ForegroundPositive=kde(a["green"]),
        )

    selection = group(c["primary"], c["primary_container"])
    selection.update(ForegroundNormal=kde(c["on_primary"]), ForegroundInactive=kde(c["on_primary_container"]),
                     ForegroundActive=kde(c["on_primary"]))

    return (
        section("General", dict(Name=f"Wallpaper ({name})", ColorScheme=f"Wallpaper-{name}")) +
        section("KDE", dict(contrast=4)) +
        section("ColorEffects:Disabled", dict(Color="56,56,56", ColorAmount=0, ColorEffect=0, ContrastAmount=0.65,
                                              ContrastEffect=1, IntensityAmount=0.1, IntensityEffect=2)) +
        section("ColorEffects:Inactive", dict(ChangeSelectionColor="true", Enable="false")) +
        # one base surface for every app, so they read as one desktop instead of each having its own shade
        section("Colors:Window", group(c["surface_container"], c["surface_container_high"])) +
        section("Colors:View", group(c["surface_container"], c["surface_container"])) +
        section("Colors:Button", group(c["surface_container_high"], c["surface_container_highest"])) +
        section("Colors:Header", group(c["surface_container"], c["surface_container_high"])) +
        section("Colors:Header][Inactive", group(c["surface_container"], c["surface_container_high"])) +
        section("Colors:Tooltip", group(c["surface_container_highest"], c["surface_container_high"])) +
        section("Colors:Complementary", group(c["surface_dim"], c["surface_container"])) +
        section("Colors:Selection", selection) +
        section("WM", dict(activeBackground=kde(c["surface_container"]), activeForeground=kde(c["on_surface"]),
                           activeBlend=kde(c["on_surface"]), inactiveBackground=kde(c["surface_container"]),
                           inactiveForeground=kde(c["on_surface_variant"]),
                           inactiveBlend=kde(c["on_surface_variant"])))
    )


def ghostty(c, a):
    pal = [c["surface_container_high"], a["red"], a["green"], a["yellow"], a["blue"], a["magenta"], a["cyan"],
           c["on_surface_variant"], c["outline"], a["red"], a["green"], a["yellow"], a["blue"], a["magenta"],
           a["cyan"], c["on_surface"]]
    return (f"background = {c['surface_container']}\nforeground = {c['on_surface']}\n"
            f"cursor-color = {c['primary']}\nselection-background = {c['primary_container']}\n"
            f"selection-foreground = {c['on_primary_container']}\n"
            + "".join(f"palette = {i}={p}\n" for i, p in enumerate(pal)))


def folder(accent):
    ah, al, as_ = hls(accent)

    def dist(h):
        ch, cl, cs = hls(h)
        dh = min(abs(ah - ch), 1 - abs(ah - ch))
        return dh * 4 + abs(as_ - cs) * 0.5 + abs(al - cl) * 0.5

    return min(FOLDERS, key=lambda k: dist(FOLDERS[k]))


def papirus_accent(colour):
    # Papirus-Dark with only the places relinked to another colour (what papirus-folders does in place). Every size is
    # a full copy of links, an overlay that inherits would let the larger sizes fall through to the default green
    dark = os.path.join(papirus, "Papirus-Dark")
    theme = os.path.join(out, "share/icons", f"Papirus-Accent-{colour}")
    os.makedirs(theme)
    for size in os.listdir(dark):
        sp = os.path.join(dark, size)
        if size == "index.theme":
            continue
        if not os.path.isdir(sp):
            os.symlink(os.path.realpath(sp), os.path.join(theme, size))
            continue
        os.makedirs(os.path.join(theme, size))
        for ctx in os.listdir(sp):
            cp = os.path.realpath(os.path.join(sp, ctx))
            dst = os.path.join(theme, size, ctx)
            if ctx != "places" or not os.path.isdir(cp):
                os.symlink(cp, dst)
                continue
            os.makedirs(dst)
            for f in os.listdir(cp):
                real = os.path.realpath(os.path.join(cp, f))
                b = os.path.basename(real)
                if "-green" in b:
                    real = os.path.join(os.path.dirname(real), b.replace("-green", f"-{colour}"))
                os.symlink(real, os.path.join(dst, f))
    idx = open(os.path.join(dark, "index.theme")).read()
    idx = re.sub(r"^Name=.*$", f"Name=Papirus Accent ({colour})", idx, count=1, flags=re.M)
    open(os.path.join(theme, "index.theme"), "w").write(idx)


os.makedirs(os.path.join(out, "share/color-schemes"))
used = set()
order = []
for name, image in walls:
    c = palette(image)
    a = ansi(c)
    d = os.path.join(out, "share/wallpaper-themes", name)
    os.makedirs(d)
    os.symlink(image, os.path.join(d, "image"))
    open(os.path.join(out, "share/color-schemes", f"Wallpaper-{name}.colors"), "w").write(scheme(name, c, a))
    open(os.path.join(d, "ghostty"), "w").write(ghostty(c, a))
    f = folder(c["primary"])
    open(os.path.join(d, "folder"), "w").write(f + "\n")
    used.add(f)
    order.append(name)
    print(f"{name}: accent {c['primary']}, folders {f}")

open(os.path.join(out, "share/wallpaper-themes/order"), "w").write("\n".join(order) + "\n")
for colour in sorted(used):
    papirus_accent(colour)
