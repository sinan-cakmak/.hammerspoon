#!/bin/zsh

set -euo pipefail

repo_dir="${0:A:h:h}"
module="$repo_dir/modules/spotify_space.lua"
helper="$repo_dir/bin/move-window-to-space"

luajit -e "assert(loadfile('$module'))"

if RIPGREP_CONFIG_PATH=/dev/null rg -q 'spaces\.moveWindowToSpace' "$module"; then
    print -u2 "Spotify module regressed to Hammerspoon's broken macOS 15+ move API"
    exit 1
fi

if [[ ! -x "$helper" ]]; then
    print -u2 "compiled Spotify Space helper is missing: $helper"
    exit 1
fi

"$helper" --probe >/dev/null

if (( $# == 2 )); then
    window_id="$1"
    target_space="$2"
    "$helper" "$window_id" "$target_space"
    memberships="$($helper --spaces "$window_id")"
    if [[ "$memberships" != *"$target_space"* ]]; then
        print -u2 "window $window_id is not on target Space $target_space"
        exit 1
    fi
fi

print "Spotify Space helper checks passed"
