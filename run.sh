# Activate the Metal performance HUD on macOS.
export MTL_HUD_ENABLED=1

# Redirect the default OpenMM plugins directory.
export OPENMM_PLUGIN_DIR="/Users/philipturner/miniforge3/lib"

# Run in release mode with incremental compilation.
swift run -Xswiftc -Ounchecked

export WORKSPACE_PATH="$(pwd)/.build/arm64-apple-macosx/debug/Workspace"
install_name_tool -change "@rpath/libOpenMM.dylib" "$OPENMM_PLUGIN_DIR/libOpenMM.dylib" "$WORKSPACE_PATH"
install_name_tool -change "@rpath/libc++.1.dylib" "$OPENMM_PLUGIN_DIR/libc++.1.dylib" "$WORKSPACE_PATH"
codesign -fs - "$WORKSPACE_PATH"
$WORKSPACE_PATH
