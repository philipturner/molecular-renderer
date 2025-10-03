# Activate the Metal performance HUD on macOS.
export MTL_HUD_ENABLED=1

# Redirect the default OpenMM plugins directory.
export OPENMM_PLUGIN_DIR="/C:/Users/phili/miniconda3/Library/lib/plugins"

# Run in release mode with incremental compilation.
swift run -Xswiftc -Ounchecked
