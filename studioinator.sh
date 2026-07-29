#!/usr/bin/env sh

# studioinator.sh:
# Provides luau binaries with Roblox Studio/Playground fflag behaviour, treated as canon by the luau team.

set -e

if [[ "$1" == "--help" ]]; then
    echo "\nStudioinator - Maps live roblox fflags to luau binaries"
    echo "\nUsage: ./studioinator.sh [option?] [binary?] [binary options]"
    echo "\nAvailable options:"
    echo "--help: Shows this help page"
    echo "--verbose: Display which fflags and values were passed to the binary"
    exit 0
fi

VERBOSE=false
if [[ "$1" == "--verbose" ]]; then
    VERBOSE=true
    shift
fi

# Assigns default luau binary or provided alternative; done early to prevent fflag warnings slipping through to output
LUAU_BIN="luau"
# Accepts LUAU_BIN customisation only if valid.
if [[ "$1" == *luau* ]] && command -v "$1" >/dev/null 2>&1; then
    LUAU_BIN="$1"
    shift
fi

# Dependency check
DEPENDENCIES="mktemp grep tr jq curl $LUAU_BIN"
for arg in $DEPENDENCIES; do
    if ! command -v $arg >/dev/null 2>&1; then
        echo "Error: '$arg' not found in PATH" >&2
        exit 1
    fi
done

# Based on luau playground:
# https://github.com/luau-lang/playground/blob/b0afa61dcf78a12c18d7ab67c44d4a6482aefdec/src/lib/luau/wasm.ts#L25
FFLAG_URL="https://clientsettingscdn.roblox.com/v1/settings/application?applicationName=PCStudioApp"
FFLAG_PREFIXES='["FFlagLuau","FIntLuau","DFFlagLuau","DFIntLuau"]'
FFLAG_ARGS=$(curl -sSL "$FFLAG_URL"| jq -j --argjson prefixes "$FFLAG_PREFIXES" '
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
#       | emit(.key; .value)
        | emit((.key | sub("^(D?FFlag|D?FInt)"; "")); .value)
    end
')

# Split args into lines via ','
FFLAG_ARG_LINES=$(printf '%s\n' "$FFLAG_ARGS" | tr ',' '\n')

# Perform test to fetch luau fflag warnings
TEST='return'
TEMP_TEST=$(mktemp)
trap 'rm -f "$TEMP_TEST"' EXIT
printf '%s\n' "$TEST" >"$TEMP_TEST"
TEST_WARNINGS=$(
    "$LUAU_BIN" --fflags="false,$FFLAG_ARGS" "$TEMP_TEST" \
        2>&1 >/dev/null || true
)

# Place incompatible fflag names into list
FFLAG_INCOMPATIBLE=$(
    printf '%s\n' "$TEST_WARNINGS" |
    grep -oE '(Luau)[A-Za-z0-9_]+' |
    sort -u ||
    true
)

# Remove lines from FFLAG_ARG_LINES that match with any string from TEMP_INCOMPATIBLE
TEMP_INCOMPATIBLE=$(mktemp)
trap 'rm -f "$TEMP_INCOMPATIBLE"' EXIT
printf '%s\n' "$FFLAG_INCOMPATIBLE" > "$TEMP_INCOMPATIBLE"
FFLAG_FILTERED=$(
    printf '%s\n' "$FFLAG_ARG_LINES" |
    grep -Fv -f "$TEMP_INCOMPATIBLE" || true
)

# Displays what relevant fflags have been applied from roblox's live fflags.
if [[ "$VERBOSE" == true ]]; then
#   printf "TEST_WARNINGS lines: "
#   printf '%s\n' "$TEST_WARNINGS" | wc -l
#
#   printf "FFLAG_ARG_LINES lines: "
#   printf '%s\n' "$FFLAG_ARG_LINES" | wc -l
#
#   printf "TEMP_INCOMPATIBLE lines: "
#   wc -l < "$TEMP_INCOMPATIBLE"
#
#   printf "FFLAG_FILTERED lines: "
#   printf '%s\n' "$FFLAG_FILTERED" | wc -l
#
    echo "$FFLAG_FILTERED"
fi

# Final modification to make usable when executing the binary
FFLAG_FILTERED=$(printf '%s\n' "$FFLAG_FILTERED" | tr '\n' ',')

# Run luau binary, disable all unspecified fflags, apply FFLAG_FILTERED
exec "$(command -v $LUAU_BIN)" --fflags="false,$FFLAG_FILTERED" "$@"
