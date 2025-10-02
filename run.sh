# Activate the Metal performance HUD on macOS.
export MTL_HUD_ENABLED=1

export OPENMM_LIBRARY_PATH="$(pwd)"

# Run in release mode with incremental compilation.
swift run -Xswiftc -Ounchecked
