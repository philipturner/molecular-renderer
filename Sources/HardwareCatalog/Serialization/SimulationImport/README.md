# Support external simulations format import

Author: Alexey Novikov

## Molecular Renderer (MRSIM-TXT)

Project GitHub: https://github.com/philipturner/molecular-renderer

Vendor specification: 
- original link: https://github.com/philipturner/molecular-renderer/blob/main/Documentation/MRSimulation.md
- updated link: [../MRSimulation/README.md](../MRSimulation/README.md)

File extensions: `mrsim-txt, mrsimulation-txt`

Simulation results are provided in YAML format of a following shape. See a real example in test asset [tests/assets/StrainedShellBearing-15ps.mrsim-txt](tests/assets/StrainedShellBearing-15ps.mrsim-txt)

---

- **Specification**: URL link.
- **Header**: 
  - `frame_time`: Time between frames (femtoseconds).
  - `spatial_resolution`: Resolution (approx. picometers).
  - `checkpoints`: Boolean.
  - `frame_count`: Total number of frames.
  - `frame_cluster_size`: Frames per cluster.
- **Metadata**: List; may contain:
  - `sp3 bonds`: Atom index pairs.
- **Frame Clusters** (Multiple):
  - `frame_start`: Start frame number.
  - `frame_end`: End frame number.
  - `metadata`: List; variable data (e.g., energy).
  - **Atoms**: 
    - `x`, `y`, `z` coordinates: List with atom index and positions.
    - `elements`: Atomic numbers.
    - `flags`: Integer values.
---

### Crate `mrsim_txt`

This Rust library provides a parser for MRSIM-TXT structure detailing molecular simulations. The parsed data offers easy access methods to retrieve specific parts of the dataset.

Usage example provided in the benchmarking utility [src/bin/mrsim_txt_benchmark.rs](src/bin/mrsim_txt_benchmark.rs)

Parsed results are available via abstraction layer of `ParsedData` struct. Upon successful parsing the `data` member contains the original structured content from the simulation YAML file. Benchmark results are captured in `diagnostics` member. To obtain absolute atoms positions a `calculate_positions()` method can be called, and the results are available through the `data` member. Originally parsed results can be discarded to free the memory via `discard_original_clusters()` method.

### Benchmark utility

See [src/bin/README.md](src/bin/README.md) benchmark utility for the code examples.

### TODO
- Improve testing suite to validate calculated absolute positions vs original data
