{...}: {
  clan.inventory.tags = {
    config,
    machines,
    ...
  }: {
    # tag_name = [ "list" "of" "machines" ]
    "capability:hardware:gpu" = [""];
    "capability:hardware:audio" = [""];
    "capability:hardware:bluetooth" = [""];
  };
}
