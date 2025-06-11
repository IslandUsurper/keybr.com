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
            src = fetchFromGitHub {
              owner = "IslandUsurper";
              repo = "keybr.com";
              rev = "46e347ac62db8cd06a80b54d8fdc01ac02c409f4";
              hash = "sha256-R9mlBa5Iow+WoATNi7mRJAnOsf5x/dH5FZSWtk5XyzA=";
              leaveDotGit = true;
            };

            nativeBuildInputs = [ git sqlite ];

            npmDeps = importNpmLock {
              npmRoot = ./.;
            };

            npmBuildScript = "build";

            npmConfigHook = importNpmLock.npmConfigHook;

            #npmWorkspace = "root";

            postInstall = ''
              out_keybr=$out/lib/node_modules/keybr.com

              cp -r root/lib $out_keybr/root/lib
              cp -r root/public/assets $out_keybr/root/public/assets

              mkdir $out/bin
              cat <<EOF > $out/bin/keybr
              #!${runtimeShell}
              exec env NODE_ENV=production ${nodejs}/bin/node --enable-source-maps $out_keybr/root/index.js
              EOF
              chmod +x $out/bin/keybr
            '';
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
              users.users.keybr = {
                description = "keybr user";
                group = "keybr";
                isSystemUser = true;

                # NPM insists on creating ~/.npm
                home = "/var/cache/keybr";
              };
              users.groups.keybr = { };
              systemd.services.keybr = {
                description = pkgs.keybr.meta.description;
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" ];
                serviceConfig = {
                  ExecStart = "${pkgs.keybr}/bin/keybr";
                  User = config.users.users.keybr.name;
                  Group = config.users.users.keybr.group;
                  CacheDirectory = "keybr";
                  RuntimeDirectory = "keybr";
                  StateDirectory = "keybr";
                };
                environment = {
                  NODE_ENV = "production";
                };
              };
            };
          };
      }
    );
}
