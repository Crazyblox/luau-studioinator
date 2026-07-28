#!/usr/bin/env sh

# studioinator.sh:
# Mimics luau playground execution behaviour by parsing out all relevant fflags.
# This allows the luau binary to behave as aligned with what is treated as canon by luau staff members.

set -e
LUAU_BIN="luau"

# Matches luau playground prefixes
prefixes='["FFlagLuau","FIntLuau","DFFlagLuau","DFIntLuau"]'

# Directly pulls the same live fflags from playground & parses it out as arguments for luau CLI
# Source: https://github.com/luau-lang/playground/blob/b0afa61dcf78a12c18d7ab67c44d4a6482aefdec/src/lib/luau/wasm.ts#L25
input=$(curl -sSL "https://clientsettingscdn.roblox.com/v1/settings/application?applicationName=PCStudioApp"| jq -j --argjson prefixes "$prefixes" '
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

if [[ "$1" == *luau* ]] && command -v "$1" >/dev/null 2>&1; then
    LUAU_BIN="$1"
    shift
fi

# Drops user into specified or default luau binary, disabling all unspecified fflags, and passing all other arguments to luau.
exec "$LUAU_BIN" --fflags="false,$input" "$@"
