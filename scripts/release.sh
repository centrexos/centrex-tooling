#!/usr/bin/env bash
# CentrexOS release manager
# Usage: ./release.sh <version>  e.g. ./release.sh 0.2.0
set -euo pipefail

VERSION="${1:-}"
[[ -n "$VERSION" ]] || { echo "Usage: $0 <version>"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_DIR="$ROOT_DIR/releases/$VERSION"

info()  { echo -e "\033[1;34m[release]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[release]\033[0m $*"; }
error() { echo -e "\033[1;31m[release]\033[0m $*" >&2; exit 1; }

validate_version() {
    [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]] || \
        error "Version must match semver: X.Y.Z or X.Y.Z-tag"
}

bump_cargo_versions() {
    info "Bumping Cargo.toml versions to $VERSION..."
    for toml in "$ROOT_DIR/core/Cargo.toml" "$ROOT_DIR/cxpkg/Cargo.toml" "$ROOT_DIR/installer/Cargo.toml"; do
        [[ -f "$toml" ]] || continue
        sed -i "s/^version = \".*\"/version = \"$VERSION\"/" "$toml"
        info "  Updated: $toml"
    done
}

build_release() {
    info "Building release binaries..."
    cargo build --manifest-path "$ROOT_DIR/core/Cargo.toml" --release
    cargo build --manifest-path "$ROOT_DIR/cxpkg/Cargo.toml" --release
    cargo build --manifest-path "$ROOT_DIR/installer/Cargo.toml" --release
    ok "Binaries built."
}

run_tests() {
    info "Running test suite..."
    cargo test --manifest-path "$ROOT_DIR/core/Cargo.toml"
    cargo test --manifest-path "$ROOT_DIR/cxpkg/Cargo.toml"
    ok "All tests passed."
}

package_release() {
    info "Packaging release $VERSION..."
    mkdir -p "$RELEASE_DIR"

    # Copy binaries
    for bin in centrex-core cxpkg centrex-installer; do
        for dir in core cxpkg installer; do
            src="$ROOT_DIR/$dir/target/release/$bin"
            [[ -f "$src" ]] && install -m 755 "$src" "$RELEASE_DIR/$bin" && break
        done
    done

    # Copy config and metadata
    cp -r "$ROOT_DIR/metadata" "$RELEASE_DIR/metadata"
    cp "$ROOT_DIR/README.md"   "$RELEASE_DIR/"

    # Create checksums
    (cd "$RELEASE_DIR" && sha256sum ./* > SHA256SUMS)

    # Create tarball
    tar -czf "$ROOT_DIR/releases/centrexos-${VERSION}-x86_64.tar.gz" \
        -C "$ROOT_DIR/releases" "$VERSION"

    ok "Release package: releases/centrexos-${VERSION}-x86_64.tar.gz"
}

tag_release() {
    info "Tagging git release v$VERSION..."
    git -C "$ROOT_DIR" tag -a "v$VERSION" -m "CentrexOS v$VERSION"
    ok "Tagged: v$VERSION"
    info "Run 'git push --tags' to push the tag."
}

validate_version
run_tests
bump_cargo_versions
build_release
package_release
tag_release
ok "Release $VERSION complete."
