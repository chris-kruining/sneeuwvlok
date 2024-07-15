{ pkgs, config, ... }:
{ 
  environment.systemPackages = with pkgs; [
    discord
    webcord
    teamspeak_client
  ];

#  config.xdg.desktopEntries.discord = {
#    name = "Discord";
#    genericName = "All-in-one cross-platform voice and text chat for gamers";
#    exec = "Discord --in-process-gpu --use-gl=desktop";
#    icon = "Discord";
#    categories = [ "Network" "InstantMessaging" ];
#    settings = {
#      version = "1.4";
#    };
#  };
}
