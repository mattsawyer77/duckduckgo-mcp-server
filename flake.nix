{
  description = "nix flake for building duckduckgo-mcp-server";

  inputs.pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
  inputs.pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { nixpkgs, pyproject-nix, flake-utils, ... }:
    let
      # Loads pyproject.toml into a high-level project representation
      # Do you notice how this is not tied to any `system` attribute or package sets?
      # That is because `project` refers to a pure data representation.
      project = pyproject-nix.lib.project.loadPyproject {
        # Read & unmarshal pyproject.toml relative to this project root.
        # projectRoot is also used to set `src` for renderers such as buildPythonPackage.
        projectRoot = ./.;
      };
    in
      flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # We are using the default nixpkgs Python3 interpreter & package set.
          #
          # This means that you are purposefully ignoring:
          # - Version bounds
          # - Dependency sources (meaning local path dependencies won't resolve to the local path)
          #
          # To use packages from local sources see "Overriding Python packages" in the nixpkgs manual:
          # https://nixos.org/manual/nixpkgs/stable/#reference
          #
          # Or use an overlay generator such as uv2nix:
          # https://github.com/pyproject-nix/uv2nix
          python = pkgs.python3;

          # Returns a function that can be passed to `python.withPackages`
          arg = project.renderers.withPackages { inherit python; };

          # Returns a wrapped environment (virtualenv like) with all our packages
          pythonEnv = python.withPackages arg;

          # Returns an attribute set that can be passed to `buildPythonPackage`.
          attrs = project.renderers.buildPythonPackage { inherit python; };
        in
          {
            # Create a development shell containing dependencies from `pyproject.toml`
            devShells.default = pkgs.mkShell { packages = [ pythonEnv ]; };

            # Build our package using `buildPythonPackage`
            packages.default =
              python.pkgs.buildPythonPackage (attrs // {
                env.CUSTOM_ENVVAR = "hello";
              });
          }
      );
}
