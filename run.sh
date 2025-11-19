# Activate the Metal performance HUD on macOS.
export MTL_HUD_ENABLED=1

# Redirect the default OpenMM plugins directory.
export OPENMM_PLUGIN_DIR="$(pwd)"

# Fix a problem that would otherwise create a dependency to Conda on macOS.
if [[ "$OSTYPE" == "darwin"* ]]; then
  export OCL_ICD_VENDORS="$(pwd)/.build/vendors"
fi

# Prevent crashes with large systems.
export OMP_STACKSIZE="2G"

# Only use the performance cores on macOS.
if [[ "$OSTYPE" == "darwin"* ]]; then
  export OMP_NUM_THREADS=$(sysctl -n hw.perflevel0.physicalcpu)
fi

# Doesn't fix any bugs, and cannot test whether it has
# any effect. But hopefully is at least good practice
# on RDNA.
export GPU_ENABLE_WAVE32_MODE=1

# Run in release mode with incremental compilation.
swift run -Xswiftc -Ounchecked
