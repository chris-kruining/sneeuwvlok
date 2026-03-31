{lib, ...}: {
  imports =
    ./.
    |> builtins.readDir
    |> lib.attrsToList
    |> builtins.map ({
      name,
      value,
    }: {
      type = value;
      path = ./. + "/${name}/flake-module.nix";
    })
    |> builtins.filter ({
      type,
      path,
    }:
      type == "directory" && (builtins.pathExists path))
    |> builtins.map ({path, ...}: path);
}
