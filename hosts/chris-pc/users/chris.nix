// { config, lib, pkgs, ... }:
// {
//   full_name = "WOOT";

//   modules = {
//     themes = {
//       enable = true;
//       theme = "everforest";
//       polarity = "dark";
//     };

//     develop = {
//       rust.enable = true;
//       js.enable = true;
//       dotnet.enable = true;
//     };

//     # EXPERIMENTS
//     # services.games.minecraft.enable = true;
//     services.auth.enable = true;

//     desktop = {
//       plasma.enable = true;
//       type = "wayland";

//       applications = {
//         communication.enable = true;
//         email.enable = true;
//         office.enable = true;
//         steam.enable = true;
//         recording.enable = true;
//       };

//       terminal = {
//         default = "ghostty";
//         alacritty.enable = true;
//         ghostty.enable = true;
//       };

//       editors = {
//         default = "zed";
//         vscodium.enable = true;
//         zed.enable = true;
//         nvim.enable = true;
//         nano.enable = true;
//         kate.enable = true;
//       };

//       browsers = {
//         default = "chromium";
//         firefox.enable = true;
//         chrome.enable = true;
//       };

//       games = {
//         minecraft.enable = true;
//       };
//     };

//     shell = {
//       default = "zsh";
//       corePkgs.enable = true;
//     };
//   };
// }
