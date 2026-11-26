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

With `allowUnfree = true`:

```nix
{ pkgs, plex-versioned, ... }:
{
  nixpkgs.config.allowUnfree = true;

  services.plex = {
    enable = true;
    package = plex-versioned.packages.${pkgs.stdenv.hostPlatform.system}.plex;
  };
}
```

Or with `allowUnfreePredicate`:

```nix
{ lib, pkgs, plex-versioned, ... }:
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "plexmediaserver"
    ];

  services.plex = {
    enable = true;
    package = plex-versioned.packages.${pkgs.stdenv.hostPlatform.system}.plex;
  };
}
```

