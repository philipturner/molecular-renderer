
![image](https://github.com/philipturner/molecular-renderer/assets/71743241/d5585c84-7e4e-4507-841a-452fb68615d3)

# Molecular Renderer

What began as a ray traced renderer, is now a cross-platform library used to design molecular nanotechnology. Similar to OpenSCAD, but with GPU-accelerated molecular simulation. Working toward the design of the first self-replicating factory.

Documentation
- [Goals](./Documentation/Goals.md)
- [Project Overview](./Documentation/Overview.md)
- [Modeling Language](./Documentation/HDL.md)
- [Modules](./Documentation/Modules.md)
  - TODO: Online DocC documentation of Swift modules.
- [MRSimulation](./Documentation/MRSimulation.md)
- [References](./Documentation/References.md)

## Usage

Molecular Renderer started as a platform for the author to conduct [computational nanotechnology](https://www.zyvex.com/nanotech/compNano.html) research (the [original nanotechnology](https://en.wikipedia.org/wiki/Molecular_nanotechnology), not to be confused with nanomaterials science). Instead of a traditional UI, the CAD functionality is achieved entirely through scripting. It natively supports Swift and Metal Shading Language. Some core functionality will eventually have C bindings, bringing indirect support for C++, Rust, etc.

### MolecularRenderer Library

C-compatible Swift package that extracts the core functionality of MolecularRenderer. This is designed to be as simple and lightweight as possible, while providing enough control to be integrated into traditional CAD applications.
- Known issues: [link](./Documentation/KnownIssues.md)

### OpenMM Swift Bindings

Ergonomic wrapper around the OpenMM C API, for using OpenMM in Swift code.

### MRSimulation Codec

High-performance 3D video codec for recording and replaying molecular simulations. This scales well into the thousand-atom range, becoming resource-intensive at the million-atom range.

## Requirements for Renderer

Dependencies:
- macOS Sonoma, Apple silicon chip
- Xcode 15 installed
- OpenMM 8.0 with the [Metal plugin](https://github.com/philipturner/openmm-metal) installed

Display:
- 640x640 -> 1920x1920 upscaled with MetalFX temporal upscaling
- Monitor needs at least 1920x1920 pixels for the default resolution
- 60 Hz and 120 Hz supported

## Requirements for Simulators

Dependencies:
- [Swift toolchain](https://swift.org/download)
- [OpenMM 8.0](https://openmm.org) from conda

Hardware:
- macOS, Linux, Windows
  - OpenMM not yet ported to Android or iOS
- Discrete GPU or recent smartphone model recommended
- Apple AMX accelerator or Intel i7/i9 recommended

## Technical Details

MolecularRendererApp currently requires an Apple M1 chip running Metal 3. It is optimized for the author's personal machine (M1 Max), and samples the OpenMM simulation 120 times per second. The platform restriction makes it easier for the author to develop, but it can be ported to other devices. For example, one could port it to Windows through Vulkan and FidelityFX.

The simulators process geometry using 32-bit floating point numbers (FP32), which are compatible with GPUs. Typically, most molecular dynamics simulations occur on CPUs, where FP32 is not much faster than FP64. It also makes energy measurements less precise. In solution-phase matter, differences of 10 kT (~10 kJ/mol) drastically alter reaction transition rates. Therefore, server GPUs often do a mixture of FP32 and FP64 calculations. This is not an issue for machine-phase matter, designed to resist small changes to energy and force. The energy drift from numerical error is dwarfed by the energy gradients (a.k.a. forces) of stiff nanomachines.


