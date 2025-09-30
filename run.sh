# Activate the Metal performance HUD on macOS.
export MTL_HUD_ENABLED=1
export MTL_DEBUG_LAYER=0

# Run in release mode with incremental compilation.
swift run -Xswiftc -Ounchecked
