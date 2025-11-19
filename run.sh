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

# Run in release mode with incremental compilation.
swift run -Xswiftc -Ounchecked
