#!/bin/bash

set -xe

MOD_VERSION="$( git describe --tags --abbrev=0 --match='v*' 2>/dev/null | sed s/^v// )"
MOD_VERSION="${MOD_VERSION:-dev}"

BASE='./build'
ARTIFACT_DIR="./artifact"

CET_TARGET="./$BASE/bin/x64/plugins/cyber_engine_tweaks/mods/CyberVisionRPC"
REDSCRIPT_TARGET="./$BASE/r6/scripts/CyberVisionRPC"
RED4EXT_TARGET="./$BASE/red4ext/plugins/CyberVisionRPC"

mkdir -p "$ARTIFACT_DIR"
mkdir -p "$CET_TARGET"
mkdir -p "$REDSCRIPT_TARGET"
mkdir -p "$RED4EXT_TARGET"

# Package CET mod

cp './src/cet/init.lua'         "$CET_TARGET"
cp './src/cet/BetterUI.lua'     "$CET_TARGET"
cp './src/cet/GameUtils.lua'    "$CET_TARGET"
cp './src/cet/Handlers.lua'     "$CET_TARGET"
cp './src/cet/Localization.lua' "$CET_TARGET"
cp -R './src/cet/locales'       "$CET_TARGET"
cp './README.md'  "$CET_TARGET"
cp './LICENSE.md' "$CET_TARGET"

mkdir -p "$CET_TARGET/libs/cp2077-cet-kit"
cp './src/cet/libs/cp2077-cet-kit/GameUI.lua' "$CET_TARGET/libs/cp2077-cet-kit"
cp './src/cet/libs/cp2077-cet-kit/LICENSE'    "$CET_TARGET/libs/cp2077-cet-kit"

mkdir -p "$CET_TARGET/data"
echo 'Thank you.' > "$CET_TARGET/data/PLEASE_VORTEX_DONT_IGNORE_THIS_FOLDER"

# Package REDscript mod

cp './src/redscript/CyberVisionRPC.reds' "$REDSCRIPT_TARGET"

# Package RED4ext mod

cp './src/red4ext/build/Release/cybervisionrpc.dll'                            "$RED4EXT_TARGET"
cp './src/red4ext/libs/discord_game_sdk/lib/x86_64/discord_game_sdk.dll' "$RED4EXT_TARGET"

# Create zips: French and English editions

7z a -mx9 -r -- "$ARTIFACT_DIR/CyberVisionRPC-FR-$MOD_VERSION.zip" \
    "./$BASE/bin" \
    "./$BASE/r6"  \
    "./$BASE/red4ext"

sed -i 's/Localization:SetLocale("fr")/Localization:SetLocale("en")/' "$CET_TARGET/init.lua"

7z a -mx9 -r -- "$ARTIFACT_DIR/CyberVisionRPC-EN-$MOD_VERSION.zip" \
    "./$BASE/bin" \
    "./$BASE/r6"  \
    "./$BASE/red4ext"
