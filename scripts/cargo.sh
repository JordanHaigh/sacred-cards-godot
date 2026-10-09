#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
if command -v cargo >/dev/null 2>&1; then
    exec cargo "$@"
fi
if [ -x "$project_dir/.rust-toolchain/cargo/bin/cargo" ]; then
    export CARGO_HOME="$project_dir/.rust-toolchain/cargo"
    export RUSTUP_HOME="$project_dir/.rust-toolchain/rustup"
elif [ -x /private/tmp/sacred-cargo/bin/cargo ]; then
    export CARGO_HOME=/private/tmp/sacred-cargo
    export RUSTUP_HOME=/private/tmp/sacred-rustup
else
    echo "Rust is required. Install it from https://rustup.rs, then run this command again." >&2
    exit 1
fi
export PATH="$CARGO_HOME/bin:$PATH"
exec "$CARGO_HOME/bin/cargo" "$@"
