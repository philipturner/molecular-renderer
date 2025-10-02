# Activate the Metal performance HUD on macOS.
export MTL_HUD_ENABLED=1

# Redirect the default OpenMM plugins directory.
export OPENMM_PLUGIN_DIR="$(pwd)"

# Run in release mode with incremental compilation.
swift run -Xswiftc -Ounchecked

export WORKSPACE_PATH="$(pwd)/.build/arm64-apple-macosx/debug/Workspace"
install_name_tool -change "@rpath/libOpenMM.dylib" "$(pwd)/libOpenMM.dylib" "$WORKSPACE_PATH"
codesign -fs - "$WORKSPACE_PATH"
$WORKSPACE_PATH
