{
  description = "pydantic: version-bumped ahead of nixpkgs through a Python package overlay.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-lib = {
      url = "github:jgus/flake-lib/v1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    pydantic-core = {
      url = "github:jgus/pydantic-core-flake/v2.46.5";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.flake-lib.follows = "flake-lib";
    };
  };

  outputs = { nixpkgs, flake-utils, flake-lib, pydantic-core, ... }:
    let
      pin = import ./pin.nix;
      inherit (pin) version hash;
      source = { type = "pypi"; pname = "pydantic"; format = "sdist"; };
      pydanticOverlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {
            pydantic = pyprev.pydantic.overridePythonAttrs (_: {
              inherit version;
              doCheck = false;
              src = pyfinal.fetchPypi { inherit version hash; pname = "pydantic"; };
              patches = [ ];
            });
          })
        ];
      };
      overlay = nixpkgs.lib.composeManyExtensions [
        pydantic-core.overlays.default
        pydanticOverlay
      ];
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            pydantic = pkgs.python3.pkgs.pydantic;
            default = pkgs.python3.pkgs.pydantic;
            update-version = flake-lib.lib.mkUpdateVersion {
              inherit pkgs source;
              buildAttr = "pydantic";
              siblings = [
                {
                  reqName = "pydantic-core";
                  pypiName = "pydantic-core";
                  flakeRepo = "jgus/pydantic-core-flake";
                  mode = "exact";
                }
              ];
            };
            update-branches = flake-lib.lib.mkUpdateBranches {
              inherit pkgs source;
              pinSchema = "pypi";
              branchOwnedFiles = [
                "pin.nix"
                "flake.lock"
                "flake.nix"
              ];
            };
          };
        }) // {
      overlays.default = overlay;
    };
}
