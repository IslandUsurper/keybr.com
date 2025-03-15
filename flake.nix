{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (import (inputs.nixpkgs) { inherit system; });
      in
      {
        formatter = pkgs.nixfmt-rfc-style;
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.nodePackages.nodejs
            pkgs.nodePackages.typescript
            pkgs.nodePackages.typescript-language-server
          ];
        };

        packages.default =
          with pkgs;
          buildNpmPackage {
            pname = "keybr";
            version = "0.0.0";
            src = ./.;

            npmDeps = importNpmLock {
              npmRoot = ./.;
            };

            npmConfigHook = importNpmLock.npmConfigHook;
          };

        nixosModules.default =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            inherit (lib)
              mkDefault
              mkIf
              mkOption
              types
              ;
            cfg = config.services.keybr;
            fmt = pkgs.formats.ini;
          in
          {
            options.services.keybr = {
              enable = mkOption {
                type = types.bool;
                default = false;
                example = true;
                description = ''
                  A typing practice web app.
                '';
              };
              settings = mkOption {
                type = fmt.type { };
                default = { };
                description = ''
                  Env values for keybr.
                  See <link
                  xlink:href="https://github.com/aradzie/keybr.com/blob/master/.env.example"/>
                  for example settings.
                '';
              };
            };

            config = mkIf cfg.enable {
              services.keybr.settings = {
                APP_DIR = mkDefault "http://localhost:3000/";
                COOKIE_DOMAIN = mkDefault "localhost";
                COOKIE_SECURE = mkDefault "false";
                DATA_DIR = "/var/lib/keybr";
                DATABASE_CLIENT = "sqlite";
                DATABASE_FILENAME = "/var/lib/keybr/database.sqlite";
              };
              environment.etc."keybr/env".source = fmt.generate "keybr-env" cfg.settings;
            };
          };
      }
    );
}
