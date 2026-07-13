# Servarr Clan service

Media automation service for the *arr stack. It configures enabled suite services such as Sonarr, Radarr, Lidarr, and Prowlarr, plus the supporting download/search components used by the implementation.

Each enabled suite service claims a PostgreSQL database through the persistence interface and exports a gateway service endpoint. Optional per-service hosts can be supplied to publish public routes through the network gateway.

Instance settings provide the shared media path, database endpoint, enabled services, root folders, and optional host names.