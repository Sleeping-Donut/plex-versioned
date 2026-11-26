{
  pkgs,
  release ? builtins.fromJSON (builtins.readFile ./plex-release.json),
}:
let
  sys = pkgs.stdenv.hostPlatform.system;
  entry =
    release.systems.${sys}
    or (throw "Unsupported system for plex-release.json: ${sys}");
  inherit (release) version;
  inherit (entry) url hash;

  plexVersionedRaw = pkgs.plexRaw.overrideAttrs (old: {
    inherit version;
    name = "${old.pname}-${version}";
    src = pkgs.fetchurl { inherit url hash; };
  });
in
  pkgs.plex.override { plexRaw = plexVersionedRaw; }
