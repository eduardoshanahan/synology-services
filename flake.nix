{
  description = "synology-services dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          gitleaks
          zstd
          deadnix
          markdownlint-cli
          markdownlint-cli2
          shellcheck
          shfmt
          prek
        ];

        shellHook = ''
          echo "Entering synology-services dev shell"
          echo "Architecture: ${system}"

          if [ -z "''${SKIP_PREK:-}" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1 && command -v prek >/dev/null 2>&1; then
            repo_root="$(git rev-parse --show-toplevel)"

            if [ -f "$repo_root/.pre-commit-config.yaml" ]; then
              if [ -z "''${SYNOLOGY_SERVICES_PREK_DONE:-}" ]; then
                export SYNOLOGY_SERVICES_PREK_DONE=1

                echo "prek: installing git hooks"
                (cd "$repo_root" && prek install --install-hooks 2>/dev/null) || (cd "$repo_root" && prek install) || true

                if [ -z "''${SKIP_PREK_RUN:-}" ]; then
                  echo "prek: running hooks (all files)"
                  (cd "$repo_root" && prek run --all-files) || true
                fi
              fi
            fi
          fi
        '';
      };
    });
}
