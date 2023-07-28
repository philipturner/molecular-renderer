# Molecular Renderer

CAD framework for simulating nanotechnology, with ray-traced 120 Hz visualization. Designed to handle millions of atoms in real-time.

## Usage

Molecular Renderer is a platform for the author to conduct [computational nanotechnology](https://www.zyvex.com/nanotech/compNano.html) research (the [original nanotechnology](https://en.wikipedia.org/wiki/Molecular_nanotechnology), not to be confused with nanomaterials science). Instead of a traditional UI, the CAD functionality is achieved entirely through scripting. It natively supports Swift and Metal Shading Language. Some core functionality has C bindings, bringing indirect support for C++, Rust, etc.

### MolecularRenderer Library

A C-compatible Swift package that extracts the core functionality of MolecularRenderer. This is designed to be as simple and lightweight as possible, while providing enough control to be integrated into traditional CAD applications.

### MolecularRenderer App

At `Sources/OpenMM/include/module.modulemap` within the source tree, there is a file with the following contents. Replace `philipturner` with your username to compile the app.

```
module OpenMM {
  header "/Users/philipturner/miniforge3/include/OpenMMCWrapper.h"
  export *
}
```

### OpenMM Swift Bindings

An ergonomic wrapper around the C API, for using OpenMM in Swift code.

### MRSimulation Codec

A high-performance 3D video codec for recording and replaying molecular simulations. This scales well into the thousand-atom range, becoming resource-intensive at the million-atom range.

## Requirements

Dependencies:
- macOS Sonoma, Apple silicon chip
- Xcode 15 installed
- OpenMM 8.0 with the [Metal plugin](https://github.com/philipturner/openmm-metal) installed

Display:
- 640x640 -> 1920x1920 upscaled with MetalFX temporal upscaling
- Monitor needs at least 1920x1920 pixels for the default resolution
- 60 Hz and 120 Hz supported

## Technical Details

This application currently requires an Apple M1 chip running Metal 3. It is optimized for the author's personal machine (M1 Max), and samples the OpenMM simulation 120 times per second. The platform restriction makes it easier for the author to develop, but it can be ported to other devices. For example, one could port it to Windows through Vulkan and FidelityFX.

The simulator processes geometry using 32-bit floating point numbers (FP32), which are compatible with GPUs. Typically, most molecular dynamics simulations occur on CPUs, where FP32 is not much faster than FP64. It also makes energy measurements less precise. In solution-phase matter, differences of 10 kT (~10 kJ/mol) drastically alter reaction transition rates. Therefore, server GPUs often do a mixture of FP32 and FP64 calculations. This is not an issue for machine-phase matter, designed to resist small changes to energy and force. The energy drift from numerical error is dwarfed by the energy gradients (a.k.a. forces) of stiff nanomachines.

## CI

Acceleration structures:

| Type | Atom Reference Size | Passing Tests |
| ---- | ------------------- | ------------- |
| Dense Uniform Grid | 16-bit | ❌ |
| Dense Uniform Grid | 32-bit | ✅ |
| Sparse Uniform Grid | 16-bit | n/a |
| Sparse Uniform Grid | 32-bit | n/a |

State of MetalFX bugs:

| macOS Version | Motion Vector X | Motion Vector Y |
| ------------- | --------------- | --------------- |
| Ventura (13)  | Not Flipped     | Flipped         |
| Sonoma (14)   | Flipped         | Flipped         |

## References

Discussion of MetalFX upscaling quality: https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474/

Explanation of RTAO: https://thegamedev.guru/unity-ray-tracing/ambient-occlusion-rtao/

Working example of RTAO with source code: https://github.com/nvpro-samples/gl_vk_raytrace_interop

Thesis on ambient occlusion and shadows, specifically for molecules: https://core.ac.uk/download/pdf/20053956.pdf

Thesis about RTAO quality and performance, including accel rebuilds: http://www.diva-portal.org/smash/record.jsf?pid=diva2%3A1574351&dswid=2559

Thesis on bidirectional path tracing: https://graphics.stanford.edu/papers/veach_thesis/thesis.pdf

Uniform grid ray tracing algorithm: https://www.dca.fee.unicamp.br/~leopini/DISCIPLINAS/IA725/ia725-12010/Fujimoto1986-4056861.pdf
