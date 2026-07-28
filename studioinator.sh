#!/usr/bin/env sh

# studioinator.sh:
# Provides luau binaries with Roblox Studio/Playground fflag behaviour, treated as canon by the luau team.

set -e

LUAU_BIN="luau"
FFLAG_URL="https://clientsettingscdn.roblox.com/v1/settings/application?applicationName=PCStudioApp"
FFLAG_PREFIXES='["FFlagLuau","FIntLuau","DFFlagLuau","DFIntLuau"]'

# Accepts LUAU_BIN customisation only if valid.
if [[ "$1" == *luau* ]] && command -v "$1" >/dev/null 2>&1; then
    LUAU_BIN="$1"
    shift
fi

DEPENDENCIES="jq curl $LUAU_BIN"

# Dependency check
for arg in $DEPENDENCIES; do
    if ! command -v $arg >/dev/null 2>&1; then
        echo "Error: '$arg' not found in PATH" >&2
        exit 1
    fi
done

# Based on luau playground:
# https://github.com/luau-lang/playground/blob/b0afa61dcf78a12c18d7ab67c44d4a6482aefdec/src/lib/luau/wasm.ts#L25
input=$(curl -sSL "$FFLAG_URL"| jq -j --argjson prefixes "$FFLAG_PREFIXES" '
    def emit($key; $val):
        # If val is a string, keep it unquoted (e.g., abc)
        # If val is non-string (number/bool/null/object/array), stringify with jq
        "\($key)=\( if ($val|type)=="string" then $val else ($val|tostring) end),";

    .applicationSettings as $app
    | if ($app|type) != "object" then empty else
        $app
        | to_entries[]
        | select(.key as $k
            | any($prefixes[]; . as $prefix | $k | startswith($prefix))
        )
        | emit(.key; .value)
    end
')

# Run luau binary, disable all unspecified fflags, apply filtered fflags from FFLAG_URL
exec "$(command -v $LUAU_BIN)" --fflags="false,$input" "$@"
