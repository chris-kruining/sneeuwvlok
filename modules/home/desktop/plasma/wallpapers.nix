# The rotation's wallpapers, in the order the days go through them (picked to alternate hues)
# wallpapers/: middle-earth scenes, 3840x1600 so they fill an ultrawide and crop to their composition on 16:10
{ fetchurl }:
[
  { name = "fire-tower"; src = fetchurl { url = "https://raw.githubusercontent.com/dharmx/walls/6bf4d733ebf2b484a37c17d742eb47e5139e6a14/digital/a_tower_in_a_forest.png"; hash = "sha256-tDOl6w3uBB6iPTYG18OJbhLjo79CxBTzMbAyK8SDx8A="; }; }
  { name = "desert-cacti"; src = fetchurl { url = "https://w.wallhaven.cc/full/2e/wallhaven-2e9q96.png"; hash = "sha256-qT6xrt9+Cxefe2df/Qzg2+1J01KY9dnlILlGf0H4Wa8="; }; }
  { name = "firewatch"; src = ../../themes/everforest.jpg; }
  { name = "balloons-city"; src = fetchurl { url = "https://w.wallhaven.cc/full/ym/wallhaven-ymx71d.jpg"; hash = "sha256-qZaCr+UNf+ehFSyTc6XmyOMdw2TMrcTjpryBRyWfhTs="; }; }
  { name = "starry-ridges"; src = fetchurl { url = "https://raw.githubusercontent.com/dharmx/walls/6bf4d733ebf2b484a37c17d742eb47e5139e6a14/minimal/a_landscape_with_mountains_and_stars_01.png"; hash = "sha256-3nOlJNKZENz4duchBszIhZj4TYhh4s/z7iYpqDefLdU="; }; }
  { name = "mount-doom"; src = ./wallpapers/mount-doom.png; }
  { name = "bear-deer-dusk"; src = fetchurl { url = "https://w.wallhaven.cc/full/x1/wallhaven-x1rowv.jpg"; hash = "sha256-Tm02F1A/2eQk3+qgaSIquS1cEEuSiK5CFr39Rb36NxE="; }; }
  { name = "cliff-hiker"; src = fetchurl { url = "https://raw.githubusercontent.com/D3Ext/aesthetic-wallpapers/e34f05935c5b768f4c016b0893924d18ec1dba61/images/cliff-edge.jpg"; hash = "sha256-Q0KFVd0TdTfSpLfP2b2Y0h1l4QuAGKI66ej1L6AodJA="; }; }
  { name = "river-valley"; src = fetchurl { url = "https://w.wallhaven.cc/full/83/wallhaven-83rg31.jpg"; hash = "sha256-loHdCSC6+nn7NO7Tl5JBehI542LmMM1GjGfxfSpqgmI="; }; }
  { name = "sunset-ridges"; src = fetchurl { url = "https://raw.githubusercontent.com/dharmx/walls/6bf4d733ebf2b484a37c17d742eb47e5139e6a14/minimal/a_sunset_over_a_mountain_range.png"; hash = "sha256-HYQRRhcFUA+wzvQ3xTPBUtn9Jzwo2OOIIygyvD7gsOk="; }; }
  { name = "minas-tirith"; src = ./wallpapers/minas-tirith.png; }
  { name = "ringed-planet"; src = fetchurl { url = "https://raw.githubusercontent.com/D3Ext/aesthetic-wallpapers/e34f05935c5b768f4c016b0893924d18ec1dba61/images/saturn-rings.jpg"; hash = "sha256-9rIIglDt1nuTLtHD4jMRiSiw0k70EbNspGIe4TF2TL8="; }; }
  { name = "savanna-horse"; src = fetchurl { url = "https://w.wallhaven.cc/full/vg/wallhaven-vgy6y3.png"; hash = "sha256-b2XGfVWi9QgBKg67sW5EHnSpHe5oj2oBSUynnEnjdAg="; }; }
  { name = "moon-pines"; src = fetchurl { url = "https://raw.githubusercontent.com/dharmx/walls/6bf4d733ebf2b484a37c17d742eb47e5139e6a14/minimal/a_mountain_with_trees_and_moon.jpg"; hash = "sha256-iy0FiNLoGlK3blA1sVCP5o2qa//VWtcwSJuvPpsws1w="; }; }
  { name = "pyramids"; src = fetchurl { url = "https://w.wallhaven.cc/full/mp/wallhaven-mp5ll8.jpg"; hash = "sha256-fxvRgu2Buv9OiTNnmbaTSXUpPkVv4jw5IRpz64y3vcw="; }; }
  { name = "grey-havens"; src = ./wallpapers/grey-havens.png; }
  { name = "mountain-train"; src = fetchurl { url = "https://raw.githubusercontent.com/dharmx/walls/6bf4d733ebf2b484a37c17d742eb47e5139e6a14/minimal/a_train_crossing_a_bridge_over_a_bridge_with_mountains_in_the_background.png"; hash = "sha256-4BEONR4/YkAUPE2mmuhD+kVLfo6vpm61EMI8ciLIcuM="; }; }
]
