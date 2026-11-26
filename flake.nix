{
  description = "Versioned Plex Media Server";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.zst";
  };

  outputs = { self, nixpkgs }:
    let
      release = builtins.fromJSON (builtins.readFile ./plex-release.json);
      supportedSystems = builtins.attrNames release.systems;

      # Only applies to this flake's `packages` output. Consumers using
      # `lib.mkPlex` are governed by their own nixpkgs config.
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "plexmediaserver" ];
        };

      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system:
          f system (mkPkgs system)
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
