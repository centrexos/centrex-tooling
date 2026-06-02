# centrex-tooling

Build automation, release management, CI helpers, and package metadata tooling for CentrexOS.

---

## Structure

```
tooling/
├── scripts/
│   ├── release.sh         Version bump, build, test, package, git tag
│   ├── gen-package.sh     Interactive new-package metadata generator
│   └── ci-check.sh        Local pre-push CI check (fmt, clippy, tests, JSON, shellcheck)
└── ci/
    └── build.yml          GitHub Actions workflow for all components
```

---

## Scripts

### `scripts/release.sh <version>`

Creates an official CentrexOS release.

```sh
./scripts/release.sh 0.2.0
```

Steps:
1. Validates semver format
2. Runs the full test suite
3. Bumps all `Cargo.toml` versions to the specified version
4. Builds release binaries (core, cxpkg, installer)
5. Creates `releases/<version>/` with binaries and `SHA256SUMS`
6. Creates a `.tar.gz` archive at `releases/centrexos-<version>-x86_64.tar.gz`
7. Creates an annotated git tag `v<version>`

Run as a maintainer only. Push the tag manually after verification: `git push --tags`.

---

### `scripts/gen-package.sh [category]`

Interactive generator for new package metadata entries.

```sh
./scripts/gen-package.sh dev
```

Prompts for logical name, APT name, DNF name, Flatpak ID, description, category, and aliases. Writes the result into `metadata/packages/<category>.json` using `jq` for clean formatting.

Requires `jq` to be installed.

---

### `scripts/ci-check.sh`

Local pre-push check. Mirrors the GitHub Actions CI jobs exactly.

```sh
./scripts/ci-check.sh
```

Checks:
- `cargo fmt -- --check` for all Rust crates
- `cargo clippy -- -D warnings` for all Rust crates
- `cargo test` for core and cxpkg
- `jq .` validity for all JSON files in `metadata/`
- `shellcheck` for all `.sh` files (if shellcheck is installed)

Exits 0 on full pass, 1 on any failure. Prints a pass/fail summary at the end.

**Run this before every pull request.**

---

## CI Pipeline (`ci/build.yml`)

GitHub Actions workflow with the following jobs:

| Job | What it checks |
|---|---|
| `build-core` | fmt, clippy, build (release), test |
| `build-cxpkg` | fmt, clippy, build (release), test |
| `build-installer` | build (release) |
| `validate-metadata` | `jq .` on every `metadata/**/*.json` file |
| `shellcheck` | All `.sh` files in the repository |

Cargo registry and `target/` directories are cached per `Cargo.lock` hash to keep build times short.

---

## Adding a New Script

1. Create `scripts/<name>.sh` with `#!/usr/bin/env bash` and `set -euo pipefail`
2. Make it executable: `chmod +x scripts/<name>.sh`
3. Ensure `shellcheck scripts/<name>.sh` passes with no warnings
4. Add it to the `shellcheck` step in `ci/build.yml`
5. Document it in this README
