# Molecular Renderer

Flexible application for running and visualizing nanotech simulations, with ray tracing and 120 Hz uninterrupted playback. This application is designed to simulate 1,000 atoms or render 100,000,000 atoms in real-time.

This is a platform for the author to conduct [computational nanotechnology](https://www.zyvex.com/nanotech/compNano.html) research (the [original nanotechnology](https://en.wikipedia.org/wiki/Molecular_nanotechnology), not to be confused with nanomaterials science). It processes geometry using 32-bit floating point numbers (FP32), which are compatible with GPUs. Typically, most molecular dynamics simulations occur on CPUs, where FP32 is not much faster than FP64. It also makes energy measurements less precise. In solution-phase matter, differences of 10 kT (~10 kJ/mol) drastically alter reaction transition rates. Therefore, server GPUs often do a mixture of FP32 and FP64 calculations. This is not an issue for machine-phase matter, designed to resist small changes to energy and force. The energy drift from numerical error is dwarfed by the energy gradients (a.k.a. forces) of stiff nanomachines.

## Usage

### OpenMM Swift Bindings

An ergonomic wrapper around the C API, for using OpenMM in Swift code.

### MolecularRenderer Library

A C-compatible Swift package that extracts the core functionality of MolecularRenderer. This is designed to be as simple and lightweight as possible, while providing enough control to be integrated into other CAD applications.

### MolecularRenderer App

At `Sources/OpenMM/include/module.modulemap` within the source tree, there is a file with the following contents. Replace `philipturner` with your username to compile the app.

```
module OpenMM {
  header "/Users/philipturner/miniforge3/include/OpenMMCWrapper.h"
  export *
}
```

<!--

> TODO: Update this documentation with more modern information.

You can set a custom aspect ratio, instead of 1280x1280. Just make it divisible by 2 and stay under ~2 million pixels. Below are some common video resolutions.

```
1:1
- 720x720: 0.518M pixels
- 1080x1080: 1.166M pixels
- 1440x1440: 2.074M pixels

4:3
- 800x600: 0.480M pixels
- 1280x960: 1.229M pixels
- 1600x1200: 1.920M pixels

16:9
- 960x540: 0.518M pixels
- 1280x720: 0.922M pixels
- 1920x1080: 2.074M pixels
```

The FOV adapts to the aspect ratio according to the heuristic below. The base FOV is 90 degrees by default, but you can customize it.

```swift
let geometricMeanLength = sqrt(width * height)
let scaleX = width / geometricMeanLength
let scaleY = height / geometricMeanLength

let baseFOV = degreesToRadians(90)
let baseSlope = tan(baseFOV / 2)
let fovX = 2 * arctan(scaleX * baseSlope)
let fovY = 2 * arctan(scaleY * baseSlope)
```

-->

TODO (simulation modes):
- 4 fs (NVT): QSHAKE, mass repartitoning, improved velocity rescaling thermostat, entirely FP32
- 1 fs (NVE): first mode to be implemented, sums groups of 4 nonbonded forces in FP32 and switches to eFP64 for larger sums
- 0.25 fs (NVE): identical to 1 fs, except the smaller timestep permits measuring energies smaller than the Landauer limit

## Requirements

Dependencies:
- macOS Sonoma, Apple silicon chip
- Xcode 15 installed
- OpenMM 8.0 with the [Metal plugin](https://github.com/philipturner/openmm-metal) installed

<!--Memory/Disk:-->
<!--- At least 8 GB of RAM-->
<!--- Solid-state drive or high-bandwidth HDD, several GB of free disk space-->
<!--- Before compression: 156 MB per second of playback per 100,000 atoms-->
<!--- Before compression: 9 MB per second of playback when under 6,000 atoms-->

Display:
- 640x640 -> 1280x1280 upscaled with MetalFX temporal upscaling
- Monitor needs at least 1280x1280 pixels for the default resolution
- 60 Hz and 120 Hz supported

## Technical Details

This application currently requires an Apple M1 chip running Metal 3. It is optimized for the author's personal machine (M1 Max), and samples the OpenMM simulation 120 times per second\*. The platform restriction makes it easier for the author to develop, but it can be ported to other devices. For example, one could port it to Windows through Vulkan and FidelityFX.

<!-- \*When targeting a 60 Hz display or exporting 24 Hz video, it simply renders every n-th frame.-->
<!---->
<!--Before serialization, geometry data packs into an efficient format - three `float` numbers per atom, with a stride of 12 B. Shaders compute velocity from positions between frame timestamps, rather than the actual atomic velocities. This is more appropriate for MetalFX temporal upscaling and removes the need to store velocities on disk. Finally, the geometry data is archived using the [LZBITMAP](https://developer.apple.com/documentation/compression/compression_lzbitmap) lossless compression algorithm. While running an OpenMM simulation, the application auto-saves each batch of 12 consecutive frames into one file. The end of the batch contains atomic velocities for resuming the simulation.-->
<!---->
<!--Asuming 4 fs time step @ 120 Hz, playback speed must be a multiple of 0.48 ps/s. Replaying at exactly 0.48 ps/s would cause a significant bottleneck; OpenMM would halt the GPU command stream every step. To prevent this bottleneck, try to replay at something over 10 ps/s. Also check how quickly OpenMM is simulating, to gauge how long you'll wait before visualizing. OpenMM would generate 1.2 ps/s of data when simulating 100 ns/day, something achievable with the M1 Max and ~100,000 atoms.-->

## References

Discussion of MetalFX upscaling quality: https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474/

Explanation of RTAO: https://thegamedev.guru/unity-ray-tracing/ambient-occlusion-rtao/

Working example of RTAO with source code: https://github.com/nvpro-samples/gl_vk_raytrace_interop

Thesis on ambient occlusion and shadows, specifically for molecules: https://core.ac.uk/download/pdf/20053956.pdf

Thesis about RTAO quality and performance, including accel rebuilds: http://www.diva-portal.org/smash/record.jsf?pid=diva2%3A1574351&dswid=2559

Thesis on bidirectional path tracing: https://graphics.stanford.edu/papers/veach_thesis/thesis.pdf

Uniform grid ray tracing algorithm: https://www.dca.fee.unicamp.br/~leopini/DISCIPLINAS/IA725/ia725-12010/Fujimoto1986-4056861.pdf
