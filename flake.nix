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
      pkgs = import nixpkgs { inherit system; };
      sessionPreflight = pkgs.writeShellApplication {
        name = "session-preflight";
        runtimeInputs = [ pkgs.ripgrep ];
        text = ''
          set -euo pipefail

          repo_root="$PWD"
          kb_root="''${HHLAB_WIKI_DIR:-$repo_root/../hhlab-wiki}"

          required_repo_docs=(
            "$repo_root/README.md"
            "$repo_root/hhnas4/README.md"
            "$repo_root/hhnas4/docs/DOCUMENTATION_INDEX.md"
          )

          required_kb_docs=(
            "$kb_root/README.md"
            "$kb_root/indexes/by-repo.md"
            "$kb_root/indexes/by-topic.md"
            "$kb_root/indexes/by-date.md"
          )

          echo "synology-services session pre-flight"
          echo "repo_root=$repo_root"
          echo "kb_root=$kb_root"
          echo

          missing=0
          for file in "''${required_repo_docs[@]}"; do
            if [ -f "$file" ]; then
              echo "OK   $file"
            else
              echo "MISS $file" >&2
              missing=1
            fi
          done

          for file in "''${required_kb_docs[@]}"; do
            if [ -f "$file" ]; then
              echo "OK   $file"
            else
              echo "MISS $file" >&2
              missing=1
            fi
          done

          if [ "$missing" -ne 0 ]; then
            cat >&2 <<'EOF'

Pre-flight failed: required docs are missing.
Set HHLAB_WIKI_DIR if your private wiki lives outside ../hhlab-wiki.
EOF
            exit 1
          fi

          echo
          echo "Relevant KB entries for synology-services:"
          rg -n "synology-services|synology-services-private" "$kb_root/indexes/by-repo.md" || true

          echo
          cat <<'EOF'
Next required steps:
1. Read the linked KB records.
2. Summarize grounded assumptions and open uncertainties.
3. Validate plan against decisions and anti-patterns before implementation.
EOF
        '';
      };
    in {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          gitleaks
          markdownlint-cli2
          shellcheck
          shfmt
          prek
          sops
        ];
      };

      packages.session-preflight = sessionPreflight;

      apps.session-preflight = {
        type = "app";
        program = "${sessionPreflight}/bin/session-preflight";
      };
    });
}
