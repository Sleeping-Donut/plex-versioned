{
  description = "Versioned Plex Media Server";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.zst";
  };

  outputs = { self, nixpkgs }:
    let
      release = builtins.fromJSON (builtins.readFile ./plex-release.json);
      supportedSystems = builtins.attrNames release.systems;

      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system:
          f system (import nixpkgs { inherit system; })
        );
    in
    {
      lib.mkPlex = { pkgs }: pkgs.callPackage ./default.nix { inherit release; };
      packages = forAllSystems (_system: pkgs:
        let
          plex = pkgs.callPackage ./default.nix { inherit release; };
        in
        {
          inherit plex;
          default = plex;
        }
      );
    };
}
