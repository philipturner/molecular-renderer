# Molecular Renderer

Flexible application for running and visualizing nanotech simulations, with RTAO and up to 120 Hz uninterrupted playback. This application is designed to work with up to 1,000,000 atoms in real-time.

This is a platform for the author to conduct [computational nanotechnology](https://www.zyvex.com/nanotech/compNano.html) research (the [original nanotechnology](https://en.wikipedia.org/wiki/Molecular_nanotechnology), not to be confused with nanomaterials science). It processes geometry using 32-bit floating point numbers (FP32), which are compatible with GPUs. Typically, most molecular dynamics simulations occur on CPUs, where FP32 is not much faster than FP64. It also makes energy measurements less precise. In solution-phase matter, differences of 10 kT (~10 kJ/mol) drastically alter reaction transition rates. Therefore, server GPUs often do a mixture of FP32 and FP64 calculations. This is not an issue for machine-phase matter, designed to resist small changes in energy and force. The energy drift from numerical error is dwarfed by the energy gradients (a.k.a. forces) of stiff nanomachines.

## Usage

You can set a custom aspect ratio, instead of 1536x1536. Just make it divisible by 2 and stay under ~2 million pixels. Below are some   common video resolutions.

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

let baseFOV = 90 // degrees
let baseSlope = tan(baseFOV / 2)
let fovX = 2 * arctan(scaleX * baseSlope)
let fovY = 2 * arctan(scaleY * baseSlope)
```

TODO (performance):
- Add optional MetalFX temporal antialiasing.
- Use a RTAO-based renderer.
- Use OpenMM CPU backend with the real-time simulation mode, port Drexler-MM2 forcefield.
- Use OpenMM C++ bindings, extract atom tiles from GPU backend.
- Use Metal 3 fast resource loading to stream geometry data from disk, several frames ahead.
- Multiple tiers of ray tracing algorithms, tradeoffs between O(n) accel building cost and O(1) rendering cost.

TODO (user interface):
- Minecraft-like sprinting for flying around at different speeds.
- HUD when crosshair is active: OpenMM ps/s, OpenMM ns/day, rendering ps/s, using Monocraft font + SwiftUI.
- Scripting API to reproduce any simulation.
- Automatically halt progress at specified GB limit, estimate average and maximum size from simulation parameters, show remaining disk space.
- Enable replaying at integer multiples of the sample rate, exporting 24 Hz H.264 video (with motion blur?).

## Requirements

Dependencies:
- macOS Ventura, Apple silicon chip
- Xcode 14 installed
- OpenMM 8.0 with the [Metal plugin](https://github.com/philipturner/openmm-metal) installed

Memory/Disk:
- At least 8 GB of RAM
- Solid-state drive or high-bandwidth HDD, several GB of free disk space
- Before compression: 156 MB per second of playback per 100,000 atoms
- Before compression: 9 MB per second of playback when under 6,000 atoms

Display:
- 768x768 -> 1536x1536 upscaled with MetalFX temporal upscaling
- Monitor needs at least 1536x1536 pixels for the default resolution
- 30 Hz, 60 Hz, and 120 Hz supported

## Technical Details

This application currently requires an Apple M1 chip running Metal 3. It is optimized for the author's personal machine (M1 Max), and samples the OpenMM simulation 120 times per second\*. The platform restriction makes it easier for the author to develop, but it can be ported to other devices. For example, MetalFX spatial upscaling would let it run on Intel Macs. One could also port it to Windows through Vulkan and FidelityFX.

> \*When targeting a 60 Hz display or exporting 24 Hz video, it simply renders every n-th frame.

Before serialization, geometry data packs into an efficient format - three `float` numbers per atom, with a stride of 12 B. Shaders compute velocity from positions between frame timestamps, rather than the actual atomic velocities. This is more appropriate for MetalFX temporal upscaling and removes the need to store velocities on disk. Finally, the geometry data is archived using the [LZBITMAP](https://developer.apple.com/documentation/compression/compression_lzbitmap) lossless compression algorithm. While running an OpenMM simulation, the application auto-saves each batch of 12 consecutive frames into one file. The end of the batch contains atomic velocities for resuming the simulation.

Asuming 4 fs time step @ 120 Hz, playback speed must be a multiple of 0.48 ps/s. Replaying at exactly 0.48 ps/s would cause a significant bottleneck; OpenMM would halt the GPU command stream every step. To prevent this bottleneck, try to replay at something over 10 ps/s. Also check how quickly OpenMM is simulating, to gauge how long you'll wait before visualizing. OpenMM would generate 1.2 ps/s of data when simulating 100 ns/day, something achievable with the M1 Max and ~100,000 atoms.

## References

Discussion of MetalFX upscaling quality: https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474/

Visualizing molecules in stereoscopic AR/VR: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5063251/

Impostors algorithm for approximate AO: https://pubmed.ncbi.nlm.nih.gov/17080857/

Thesis on ambient occlusion and shadows, specifically for molecules: https://core.ac.uk/download/pdf/20053956.pdf

Nanite algorithm for vastly complex geometry: https://advances.realtimerendering.com/s2021/Karis_Nanite_SIGGRAPH_Advances_2021_final.pdf
