#!/usr/bin/env bash

run_rebuild() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(realpath "$SCRIPT_DIR/../..")"

  echo "→ Creating staging snapshot"

  rm -rf /etc/nixos/.staging
  mkdir -p /etc/nixos/.staging

  cp -r /etc/nixos/* /etc/nixos/.staging/

  echo "→ Validating build"

  nix-build '<nixpkgs/nixos>' \
    --attr config.system.build.toplevel \
    --include nixos-config=/etc/nixos/.staging/configuration.nix

  echo "→ Build successful"
  echo "→ Promoting staging to live config"

  "$ROOT_DIR/scripts/nix-rebuild-smart.sh"

  echo "→ Done"
}
