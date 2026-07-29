#!/bin/sh

# studioinator.sh:
# Provides luau binaries with Roblox Studio/Playground fflag behaviour, treated as canon by the luau team.

set -eu

# Perform studioinator options
VERBOSE=false
while [ $# -gt 0 ]; do
    case "${1:-}" in
        --help)
            printf '\n%s\n' 'Studioinator - Maps live roblox fflags to luau binaries'
            printf '\n%s\n' 'Usage: studioinator [studioinator options] [binary] [binary options]'
            printf '\n%s\n' 'Available options:'
            printf '%s\t%s\n' '--help:   ' 'Shows this help page'
            printf '%s\t%s\n' '--verbose:' 'Display which fflags and values were passed to the binary'
            exit 0
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Accepts provided binary, with fallback to default
LUAU_PATH=''
if LUAU_PATH=$(command -v "${1:-}" 2>/dev/null); then
    shift
elif ! LUAU_PATH=$(command -v luau 2>/dev/null); then
    printf '%s\n' 'Error: Couldnt resolve binary path' >&2
    exit 1
fi

# Binary dependencies
for arg in mktemp grep tr jq curl sort; do
    if ! command -v "$arg" >/dev/null 2>&1; then
        printf 'Error: "%s" not found\n' "$arg" >&2
        exit 1
    fi
done

# Based on luau playground:
# https://github.com/luau-lang/playground/blob/b0afa61dcf78a12c18d7ab67c44d4a6482aefdec/src/lib/luau/wasm.ts#L25
FFLAG_URL='https://clientsettingscdn.roblox.com/v1/settings/application?applicationName=PCStudioApp'
FFLAG_PREFIXES='["FFlagLuau","FIntLuau","DFFlagLuau","DFIntLuau"]'
FFLAG_ARGS=$(curl -fsSL "$FFLAG_URL"| jq -j --argjson prefixes "$FFLAG_PREFIXES" '
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
printf '%s\n' "$TEST" >"$TEMP_TEST"
TEST_WARNINGS=$(
    "$LUAU_PATH" --fflags="false,$FFLAG_ARGS" "$TEMP_TEST" \
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
printf '%s\n' "$FFLAG_INCOMPATIBLE" > "$TEMP_INCOMPATIBLE"
cleanup()
{
    rm -f "$TEMP_TEST" "$TEMP_INCOMPATIBLE"
}
trap cleanup 0
FFLAG_FILTERED=$(
    printf '%s\n' "$FFLAG_ARG_LINES" |
    grep -Fv -f "$TEMP_INCOMPATIBLE" || true
)

# Displays what relevant fflags have been applied from roblox's live fflags.
if [ "$VERBOSE" = true ]; then
    printf '%s\n\n' 'Running with --verbose'
    printf '%s\n\n' "$FFLAG_FILTERED"
    printf 'Total Luau FFlags: \t%s\n' "$(printf '%s\n' "$FFLAG_ARG_LINES" | wc -l)"
    printf 'Compatible FFlags: \t%s\n' "$(printf '%s\n' "$FFLAG_FILTERED" | wc -l)"
    printf '\nRunning %s...\n' "$LUAU_PATH"
fi

# Final modification to make usable when executing the binary
FFLAG_FILTERED=$(printf '%s\n' "$FFLAG_FILTERED" | tr '\n' ',')

# Run luau binary, disable all unspecified fflags, apply FFLAG_FILTERED
exec "$LUAU_PATH" --fflags="false,$FFLAG_FILTERED" "$@"
