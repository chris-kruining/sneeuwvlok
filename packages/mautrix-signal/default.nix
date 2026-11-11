# Temporary: mautrix-signal from main until a release > v26.10 lands in nixpkgs.
# Needed for https://github.com/mautrix/signal/pull/703 (Matrix -> Signal attachment uploads).
# Remove this package (and the `package` override in the matrix module) once nixpkgs has it.
{
  lib,
  fetchFromGitHub,
  mautrix-signal,
  libsignal-ffi,
}: let
  rev = "a96f214609cbe04426c637845902bc2fa5a0c537";

  # must match pkg/libsignalgo/libsignal in mautrix-signal
  libsignal-ffi' = libsignal-ffi.overrideAttrs (finalAttrs: _: {
    version = "0.106.1";

    src = fetchFromGitHub {
      fetchSubmodules = true;
      owner = "signalapp";
      repo = "libsignal";
      tag = "v${finalAttrs.version}";
      hash = "sha256-oNpdzlRf8T+wheiZLM3kfxeC7YGlg5mxOlON3S9E4CY=";
    };

    cargoHash = "sha256-bKUfnHyhmX9ee/Bgwos+GOSy0ra7KsdKsIyUUAz7PAw=";
  });
in
  (mautrix-signal.override {libsignal-ffi = libsignal-ffi';}).overrideAttrs {
    src = fetchFromGitHub {
      owner = "mautrix";
      repo = "signal";
      inherit rev;
      hash = "sha256-BtWmgpncV5DN+O75Q6taYYGFN/gjOsTI6zWi6vtgNP8=";
    };

    vendorHash = "sha256-MehpR+TT0ELINYtHs0fy0WZnbzEP4nIYjIaZ70XKUBQ=";
  }
