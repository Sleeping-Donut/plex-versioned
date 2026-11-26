# plex-versioned

[![Update Plex Beta Release](https://github.com/Sleeping-Donut/plex-versioned/actions/workflows/update-plex.yml/badge.svg)](https://github.com/Sleeping-Donut/plex-versioned/actions/workflows/update-plex.yml)

Versioned Plex Media Server flake driven by `plex-release.json` and a manual GitHub Actions workflow.

## Usage in NixOS

### 1. Add the flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    plex-versioned = {
      url = "github:Sleeping-Donut/plex-versioned";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, plex-versioned, ... }: {
    nixosConfigurations.my-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        { _module.args = { inherit plex-versioned; }; }
      ];
    };
  };
}
```

### 2. Enable `services.plex`

Use `lib.mkPlex` and pass your own `pkgs`, so the package is evaluated inside
your nixpkgs instance and your unfree policy applies:

```nix
{ lib, pkgs, plex-versioned, ... }:
{
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "plexmediaserver" ];

  services.plex = {
    enable = true;
    package = plex-versioned.lib.mkPlex { inherit pkgs; };
  };
}
```

`allowUnfree = true` works just as well if you already allow unfree globally.

### Why not `packages.${system}.plex`?

The `packages` output is built with this flake's own `import nixpkgs`. Plex is
unfree, so it is only usable where this flake's predicate applies — i.e. inside
this repo, or with `NIXPKGS_ALLOW_UNFREE=1 --impure`. A predicate set in the
consuming configuration cannot reach it, because nixpkgs bakes the unfree check
into the derivation when the package is evaluated, not when it is used.

`inputs.nixpkgs.follows = "nixpkgs"` does not change this: it pins the nixpkgs
source, not its configuration.

