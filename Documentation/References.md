# References

## External Collaborators

atomCAD: https://github.com/atomCAD/atomCAD

MSEP: https://astera.org/molecular-systems/ (now supported by someone other than Astera)

## MolecularRenderer Module

Discussion of MetalFX upscaling quality: https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474/

Explanation of RTAO: https://thegamedev.guru/unity-ray-tracing/ambient-occlusion-rtao/

Working example of RTAO with source code: https://github.com/nvpro-samples/gl_vk_raytrace_interop

Thesis on ambient occlusion and shadows, specifically for molecules: https://core.ac.uk/download/pdf/20053956.pdf

Thesis about RTAO quality and performance, including accel rebuilds: http://www.diva-portal.org/smash/record.jsf?pid=diva2%3A1574351&dswid=2559

Thesis on bidirectional path tracing: https://graphics.stanford.edu/papers/veach_thesis/thesis.pdf

Uniform grid ray tracing algorithm: https://www.dca.fee.unicamp.br/~leopini/DISCIPLINAS/IA725/ia725-12010/Fujimoto1986-4056861.pdf

<!--

TODO: Relocate this old documentation somewhere else.

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

-->
