#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash common-updater-scripts coreutils curl gnutar jq nix
# shellcheck shell=bash
set -euo pipefail

script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nixpkgs_root="$(realpath "$script_dir/../../../..")"
package_file="$script_dir/package.nix"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cd -- "$nixpkgs_root"

if (( $# != 0 )); then
  echo "Usage: $0" >&2
  exit 1
fi

export NIXPKGS_ALLOW_UNFREE=1

attr_path="${UPDATE_NIX_ATTR_PATH:-antigravity-cli}"
manifest_base_url="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"

declare -A manifest_platforms=(
  ["x86_64-linux"]="linux_amd64"
  ["aarch64-linux"]="linux_arm64"
  ["aarch64-darwin"]="darwin_arm64"
  ["x86_64-darwin"]="darwin_amd64"
)
declare -A urls=()
declare -A changed=()

package_systems() {
  nix-instantiate --eval --raw \
    --argstr attrPath "$attr_path" \
    -E '{ attrPath }: let pkgs = import ./. { }; lib = pkgs.lib; pkg = lib.attrByPath (lib.splitString "." attrPath) (throw "Missing package ${attrPath}") pkgs; in builtins.concatStringsSep "\n" (builtins.attrNames pkg.sources)'
}

current_package_version() {
  nix-instantiate --eval --strict --raw \
    --argstr attrPath "$attr_path" \
    -E '{ attrPath }: let pkgs = import ./. { }; lib = pkgs.lib; pkg = lib.attrByPath (lib.splitString "." attrPath) (throw "Missing package ${attrPath}") pkgs; in pkg.version'
}

current_url_for_system() {
  local system="$1"

  nix-instantiate --eval --strict --raw \
    --argstr attrPath "$attr_path" \
    --argstr system "$system" \
    -E '{ attrPath, system }: let pkgs = import ./. { }; lib = pkgs.lib; pkg = lib.attrByPath (lib.splitString "." attrPath) (throw "Missing package ${attrPath}") pkgs; source = builtins.getAttr system pkg.sources; in builtins.elemAt (source.drvAttrs.urls or [ source.url ]) 0'
}

readarray -t systems < <(package_systems)

latest_version=""
for system in "${systems[@]}"; do
  if [[ -z "${manifest_platforms[$system]:-}" ]]; then
    echo "No Antigravity CLI manifest platform mapping for $system" >&2
    exit 1
  fi

  manifest_platform="${manifest_platforms[$system]}"
  manifest="$tmpdir/$manifest_platform.json"
  curl -fsSL "$manifest_base_url/manifests/$manifest_platform.json" -o "$manifest"

  version="$(jq -r '.version // empty' "$manifest")"
  url="$(jq -r '.url // empty' "$manifest")"

  if [[ -z "$version" || -z "$url" ]]; then
    echo "Manifest for $system is missing version or URL" >&2
    exit 1
  fi

  if [[ "$url" != *"/antigravity-cli/$version-"* ]]; then
    echo "URL for $system does not match manifest version $version: $url" >&2
    exit 1
  fi

  if [[ -n "$latest_version" && "$latest_version" != "$version" ]]; then
    echo "Version mismatch: $latest_version != $version for $system" >&2
    exit 1
  fi

  latest_version="$version"
  urls[$system]="$url"
done

current_version="${UPDATE_NIX_OLD_VERSION:-$(current_package_version)}"
has_changes=0
for system in "${systems[@]}"; do
  current_url="$(current_url_for_system "$system")"
  if [[ "$current_version" != "$latest_version" || "$current_url" != "${urls[$system]}" ]]; then
    changed[$system]=1
    has_changes=1
  else
    changed[$system]=0
  fi
done

if (( has_changes == 0 )); then
  echo "antigravity-cli is already at version $current_version with current manifest URLs"
  exit 0
fi

hash_url() {
  local system="$1"
  local url="$2"
  local archive="$tmpdir/$system.tar.gz"
  local unpack_dir="$tmpdir/$system-unpack"

  mkdir -p "$unpack_dir"
  curl -fsSL "$url" -o "$archive" || return
  tar -xzf "$archive" -C "$unpack_dir" || return

  if [[ ! -x "$unpack_dir/antigravity" ]]; then
    echo "Expected executable 'antigravity' in $url" >&2
    exit 1
  fi

  nix hash path --type sha256 "$unpack_dir"
}

for system in "${systems[@]}"; do
  if (( changed[$system] == 0 )); then
    continue
  fi

  url="${urls[$system]}"
  echo "Hashing $system from $url"
  hash="$(hash_url "$system" "$url")"
  update-source-version "$attr_path" "$latest_version" "$hash" "$url" \
    --file="$package_file" \
    --ignore-same-hash \
    --ignore-same-version \
    --source-key="sources.$system" \
    --system="$system"
done
