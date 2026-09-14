#!/usr/bin/env bash
# Build and package one release of edwards.hello per the launcher plugin release contract
# (plan-launcher-plugins.md § The shared contract, Release contract).
#
# Usage: scripts/package.sh <version>
#   e.g. scripts/package.sh 0.1.0
#
# The single source of the release version is this script's argument: it is the only place
# a version string is typed for a release. src/Edwards.Hello/plugin.json is a checked-in
# template carrying every field except the actual released "version" value; this script
# overrides that one field to produce the shipped plugin.json. Nothing else in the repo
# (code, csproj) encodes a version, so there is nothing else that can drift from it.
#
# Emits exactly the three contract assets into dist/v<version>/:
#   plugin.json                         (byte-identical to the one at the zip root)
#   edwards.hello-<version>.zip         (plugin.json at the zip root + the entry DLL, nothing else)
#   edwards.hello-<version>.zip.sha256  (shasum -a 256 output)

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <version>" >&2
  exit 1
fi

VERSION="$1"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be SemVer MAJOR.MINOR.PATCH, got: $VERSION" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$REPO_ROOT/src/Edwards.Hello"
TEMPLATE_MANIFEST="$PROJECT_DIR/plugin.json"
DIST_DIR="$REPO_ROOT/dist/v$VERSION"
ID="edwards.hello"
ZIP_NAME="$ID-$VERSION.zip"

command -v dotnet >/dev/null || { echo "error: dotnet not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq not found" >&2; exit 1; }
command -v shasum >/dev/null || { echo "error: shasum not found" >&2; exit 1; }
command -v zip >/dev/null || { echo "error: zip not found" >&2; exit 1; }

echo "==> Building Release ($VERSION)"
dotnet build "$PROJECT_DIR/Edwards.Hello.csproj" -c Release -p:Version="$VERSION" -p:IncludeSourceRevisionInInformationalVersion=false

BUILD_OUT="$PROJECT_DIR/bin/Release/net10.0"
ENTRY_DLL="$BUILD_OUT/Edwards.Hello.dll"
[[ -f "$ENTRY_DLL" ]] || { echo "error: build output missing: $ENTRY_DLL" >&2; exit 1; }

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

echo "==> Writing plugin.json for $VERSION"
jq --arg version "$VERSION" '.version = $version' "$TEMPLATE_MANIFEST" > "$STAGE_DIR/plugin.json"

# Sanity: the fields the launcher install contract requires are present.
jq -e '.id == "edwards.hello"' "$STAGE_DIR/plugin.json" >/dev/null
jq -e '.apiVersion == 1' "$STAGE_DIR/plugin.json" >/dev/null
jq -e '.minHostVersion == "0.1.7"' "$STAGE_DIR/plugin.json" >/dev/null
jq -e '.kinds == ["gameplay"]' "$STAGE_DIR/plugin.json" >/dev/null
jq -e '.hosts == ["graphical", "headless"]' "$STAGE_DIR/plugin.json" >/dev/null
jq -e --arg v "$VERSION" '.version == $v' "$STAGE_DIR/plugin.json" >/dev/null

# plugin.json at dist root must be byte-identical to the one at the zip root.
cp "$STAGE_DIR/plugin.json" "$DIST_DIR/plugin.json"

cp "$ENTRY_DLL" "$STAGE_DIR/"
if [[ -f "$BUILD_OUT/Edwards.Hello.pdb" ]]; then
  cp "$BUILD_OUT/Edwards.Hello.pdb" "$STAGE_DIR/"
fi

# Extension allowlist from the release contract.
ALLOWLIST_RE='\.(dll|pdb|json|xml|txt|md|png|jpg|jpeg|ttf|otf)$'
while IFS= read -r -d '' f; do
  rel="${f#"$STAGE_DIR"/}"
  if [[ "$rel" == runtimes/* ]]; then
    echo "error: runtimes/ folder is not allowed: $rel" >&2
    exit 1
  fi
  if ! [[ "$rel" =~ $ALLOWLIST_RE ]]; then
    echo "error: file extension not on the allowlist: $rel" >&2
    exit 1
  fi
done < <(find "$STAGE_DIR" -type f -print0)

# No exec bits, no other Unix mode surprises: every staged file gets 0644 before zipping.
find "$STAGE_DIR" -type f -exec chmod 644 {} \;

echo "==> Zipping $ZIP_NAME"
rm -f "$DIST_DIR/$ZIP_NAME"
(cd "$STAGE_DIR" && zip -X -q "$DIST_DIR/$ZIP_NAME" plugin.json Edwards.Hello.dll)
if [[ -f "$STAGE_DIR/Edwards.Hello.pdb" ]]; then
  (cd "$STAGE_DIR" && zip -X -q "$DIST_DIR/$ZIP_NAME" Edwards.Hello.pdb)
fi

echo "==> Hashing"
(cd "$DIST_DIR" && shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256")

echo "==> Verifying"
# plugin.json at dist root is byte-identical to the one at the zip root.
UNZIP_STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR" "$UNZIP_STAGE"' EXIT
unzip -q "$DIST_DIR/$ZIP_NAME" -d "$UNZIP_STAGE"
cmp -s "$DIST_DIR/plugin.json" "$UNZIP_STAGE/plugin.json" \
  || { echo "error: dist plugin.json differs from zip-root plugin.json" >&2; exit 1; }
[[ -f "$UNZIP_STAGE/Edwards.Hello.dll" ]] \
  || { echo "error: entry DLL missing from zip root" >&2; exit 1; }
if [[ -n "$(find "$UNZIP_STAGE" -type f -perm -u+x)" ]]; then
  echo "error: an extracted file is executable" >&2
  exit 1
fi
(cd "$DIST_DIR" && shasum -a 256 -c "$ZIP_NAME.sha256")

echo "==> OK: $DIST_DIR"
ls -l "$DIST_DIR"
