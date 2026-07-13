{
  lib,
  clanLib ? null,
  ...
}: let
  inherit (lib) concatMapAttrsStringSep listToAttrs;
  capturedClanLib = clanLib;

  trimSlashes = str: str |> builtins.match "^/*(.+?)/*$" |> builtins.head;
  encodeAttrs = attrs: concatMapAttrsStringSep "&" (name: value: "${name}=${value}") attrs;
  endpointToString = endpoint: let
    protocol =
      if endpoint.protocol != null
      then "${endpoint.protocol}://"
      else "";
    port =
      if endpoint.port != null
      then ":${toString endpoint.port}"
      else "";
    path =
      if endpoint.path != null
      then "/${trimSlashes endpoint.path}"
      else "";
    query =
      if endpoint.query != null
      then "?${encodeAttrs endpoint.query}"
      else "";
    hash =
      if endpoint.hash != null
      then "#${encodeAttrs endpoint.hash}"
      else "";
  in "${protocol}${endpoint.host}${port}${path}${query}${hash}";

  mkEndpoint = endpoint:
    {
      protocol = "http";
      host = "localhost";
      port = null;
      user = null;
      password = null;
      path = null;
      query = null;
      hash = null;
    }
    // endpoint;
in {
  claimKey = {
    serviceName,
    instanceName,
    name,
  }: "${serviceName}/${instanceName}/${name}";

  inherit mkEndpoint;

  assignPorts = {
    machineName,
    range,
    claimNames,
  }: let
    rangeSize = range.end - range.start + 1;
    uniqueClaimNames = lib.unique claimNames;
    duplicateClaimNames =
      uniqueClaimNames
      |> lib.filter (claim: (lib.count (name: name == claim) claimNames) > 1);
    sortedClaimNames = lib.sort builtins.lessThan uniqueClaimNames;
  in
    lib.throwIf (range.start > range.end) ''
      network.default: invalid port range for machine ${machineName}

      Start: ${toString range.start}
      End:   ${toString range.end}
    ''
    lib.throwIf (duplicateClaimNames != []) ''
      network.default: duplicate endpoint claims for machine ${machineName}

      Duplicate claims:
      ${lib.concatMapStringsSep "\n" (claim: "  - ${claim}") duplicateClaimNames}
    ''
    lib.throwIf (lib.length sortedClaimNames > rangeSize) ''
      network.default: port range exhausted for machine ${machineName}

      Claims: ${toString (lib.length sortedClaimNames)}
      Range:  ${toString range.start}-${toString range.end} (${toString rangeSize} ports)
    ''
    (sortedClaimNames
      |> lib.imap0 (index: claim: {
        name = claim;
        value = range.start + index;
      })
      |> lib.listToAttrs);

  forService = {
    exports,
    machine,
    serviceName,
    instanceName,
    clanLib ? capturedClanLib,
    allocationServiceName ? "network",
    allocationInstanceName ? allocationServiceName,
    roleName ? "default",
  }: let
    _clanLib =
      if clanLib != null
      then clanLib
      else
        throw ''
        endpoints.forService: clanLib is required

        Import the helper with clanLib:
          endpointsLib = import ../../lib/endpoints.nix { inherit lib clanLib; };

        Or pass clanLib directly to forService.
      '';

    machineName = machine.name or machine;

    assignedPorts =
      (_clanLib.getExport {
        serviceName = allocationServiceName;
        instanceName = allocationInstanceName;
        inherit roleName machineName;
      } exports).ports.assigned;

    mkInternal = name: let
      key = "${serviceName}/${instanceName}/${name}";
      port =
        assignedPorts.${key}
        or (throw ''
          network.default: missing assigned port

          Machine: ${machineName}
          Claim: ${key}

          Ensure the network.default allocation role is enabled on this machine
          and that this claim is exported through ports.claims.
        '');
    in {
      inherit key;
      claims.${key} = {};
      endpoint = mkEndpoint {inherit port;};
    };
  in {
    internal = names: let
      entries =
        names
        |> map (name: let
          internal = mkInternal name;
        in {
          inherit name;
          value = internal.endpoint;
        });

      claims =
        names
        |> map (name: (mkInternal name).claims)
        |> lib.foldl' (acc: claim: acc // claim) {};
    in
      listToAttrs entries
      // {
        inherit claims;
      };
  };
}
