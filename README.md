# Molecular Renderer

Scriptable application for running OpenMM simulations and visualizing at high framerates. Provides up to 120 Hz uninterrupted playback with RTAO. This application is optimized for simulations with 10,000-1,000,000 atoms. The rendering quality and feature-completeness may initially underperform PyMOL, but the gap should close over time.

> Note: [MSEP](https://astera.org/molecular-systems/) is planning to accomplish a similar task. However, molecular-renderer serves as a simpler environment to help the author learn computational chemistry. In addition to atomistic rendering, it should incorporate electronic structure visualization with wave functions that vary in real-time. Both interactive and pre-recorded data may be used.

This should also become a future platform for the author to conduct computational nanotechnology research (the real nanotechnology, not nanomaterials science). For example, it could host code for GPU-accelerated first-principles quantum chemistry. It should not try to compete with MSEP; it offers a unique approach of _accessible (meaning FP32)\*_ GPU acceleration. MSEP presumably uses CPU for everything, including rendering.

> \* ...that runs on consumer GPUs and, furthermore, not just exclusively Nvidia consumer GPUs. Long-term, there is no need for this library to remain restricted to Apple silicon either.

<img width="515" alt="Screenshot 2023-03-24 at 9 26 46 PM" src="https://user-images.githubusercontent.com/71743241/227678193-efe03cda-6f49-4c5e-b92b-c953da32b926.png">

<!--

> A lot of these goals are also being addressed by the [MSEP](https://astera.org/molecular-systems/), which is currently in development (February 2023). Consider waiting until it's released, then merging a compression algorithm into the MSEP code base. It could also be a plugin for exporting simulations in a format replayable outside the editor. I have very limited free time and unique skills that may be better spent enhancing other projects.
>
> However, it is likely that MSEP will [use PyMOL exclusively](https://youtu.be/HjgjtAk-lws?t=1083) for graphics. The library uses [multicore CPU exclusively](https://www.mail-archive.com/pymol-users@lists.sourceforge.net/msg15181.html) for ray tracing (as of 2018) and uses the GPU only for lower-quality graphics. I will have to see whether Drexler's team attempts using Godot for the higher-quality graphics. v4.0 uses [signed distance fields](https://godotengine.org/article/godot-4-0-sets-sail/#highly-improved-lighting--shadows). He said there were "issues with shaders and various things", meaning Godot's SDFGI probably won't be used. MSEP would have to create a ray tracer from scratch if they wanted ray tracing, which seems unlikely. In short, this repository will likely be salvaged, maybe as an MSEP plugin, but I must wait for the platform's release to know for sure.
>
> I may end up creating multiple plugins for MSEP. I don't want to be doing something, then have another person make a plugin with the exact same capabilities. That would make my work redundant. I would rather collaborate with multiple researchers to standardize, enhance, and maintain these plugins. This may mean proposing a centralized effort soon after MSEP is released.
> - Molecular Renderer, which records and replays simulations with maximum rendering performance.
> - Plugin to optimize quantum chemistry simulations for the Apple AMX.
> - OpenMM plugin, which runs time-evolution simulations 10x faster than LAMMPS. Likely FP32 only unless I find enough time to finish FP64 emulation. So far, I've only found a need for double precision in the following use cases. Drexler himself said that MD is relatively insensitive to small changes in energy - a green light for single precision.
>   - Measuring thermodynamic efficiency
>   - Measuring drag in rotating bearings (TODO: this was probably possible with FP32)
>   - Measuring material stiffness
>   - Quantum chemistry
>   - All can be accomplished by measuring a single component, not the entire system. The use cases have a common theme: measuring material properties, not testing complex system dynamics. In such cases, the precision of such measurement would be prioritized. GPU mixed FP32/FP64 is >1 order of magnitude less precise than CPU FP64. Even if implemented, GPU FP64 emulation would probably not be used much anyway. Scientists would use CPU FP64 regardless.
> - Porting various forcefields to OpenMM, such as oxDNA, Tersoff, and AIREBO. This will be both a plugin for OpenMM and included with the OpenMM plugin for MSEP. It will use OpenCL exclusively - no CUDA!

-->

## Usage

After clicking the "start" button for rendering, do not switch the window to a different display. Doing so will break the rendering code.

You can set a custom aspect ratio, instead of 1024x1024. Just remember to make it divisible by 2, and stay under ~2 million pixels. Below are common video resolutions.

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
let characteristicLength = sqrt(width * height)
let scaleX = width / characteristicLength
let scaleY = height / characteristicLength

let baseFOV = 90 // degrees
let baseSlope = tan(baseFOV / 2)
let fovX = 2 * arctan(scaleX * baseSlope)
let fovY = 2 * arctan(scaleY * baseSlope)
```

TODO (performance):
- Use triple-buffering, compact the acceleration structure every 3 frames.
- Test 1024x1024 rendering first without MetalFX temporal upscaling, consider upscaling 1024x1024 -> 2048x2048.
- Use Metal 3 fast resource loading to fetch geometry data from disk, 3 frames ahead.
- Use Metal lossless compression for double-buffered intermediate textures.
- Determine whether to use ray query API.
- Store previous frame's transform data to re-project the intersection position onto the screen, generating a screen-space motion vector.

<!--
- Profile tile-based hybrid rasterization against full ray tracing, may solve divergence problems. Optimize for very complex scenes.
- Ray tracing is simpler in general. Less time invested in a possibly incorrect approach to rendering imposter rectangles.
-->

TODO (user interface):
- Modular mechanism to plug in different scripts, so I can save my research in a separate repo.
- Way to move camera position using mouse.
- Display OpenMM ps/s, OpenMM ns/day, rendering ps/s in the command line.
- Test out Metal HUD, document how to enable it.
- Serialization format to save the simulation's starting parameters.
- Automatically halt progress at specified GB limit, estimate average and maximum size from simulation parameters, show remaining disk space.
- API for replaying at integer multiples of the sample rate, exporting 24 Hz H.264 video (with motion blur?).
- API for replaying at 1/2, 1/4, 1/8 the speed by decreasing the display refresh rate.
- API for 1 fs, 2 fs, 4 fs time step modes.

TODO (miscellaneous):
- [Minecraft-like font](https://github.com/IdreesInc/Monocraft) presenting: simulation hours, number of atoms (rounded to small s.f.), simulation name, factor of time amplification for slow-motion (rounded to small s.f.).
- If extracting data through the OpenMM Python layer becomes a bottleneck, make OpenMM Clang module for C bindings (part of Xcode project).

## Requirements

Dependencies:
- macOS Ventura, Apple M1 chip
- Xcode 14 installed
- OpenMM 8.0 with the [Metal plugin](https://github.com/philipturner/openmm-metal) installed

Memory/Disk:
- At least 8 GB of RAM
- Solid-state drive or high-bandwidth HDD, several GB of free disk space
- Before compression: 156 MB per second of playback per 100,000 atoms
- Before compression: 9 MB per second of playback when under 6,000 atoms

Display:
- 512x512 -> 1024x1024 upscaled with MetalFX temporal upscaling
- Monitor needs at least 1024x1024 pixels for the default resolution
- 30 Hz, 60 Hz, and 120 Hz supported

## Technical Details

This application currently requires an Apple M1 chip running Metal 3. It is optimized for the author's personal machine (M1 Max), and samples the OpenMM simulation 120 times per second\*. The platform restriction makes it easier for the author to develop, but it can be ported to other devices. For example, MetalFX spatial upscaling would let it run on Intel Macs. One could also port it to Windows through Vulkan and FidelityFX.

> \*When targeting a 60 Hz display or exporting 24 Hz video, it simply renders every n-th frame.

Before serialization, geometry data packs into an efficient format - three `float` numbers per atom, with a stride of 12 B. Shaders compute velocity from positions between frame timestamps, rather than the actual atomic velocities. This is more appropriate for MetalFX temporal upscaling and removes the need to store velocities on disk. Finally, the geometry data is archived using the [LZBITMAP](https://developer.apple.com/documentation/compression/compression_lzbitmap) lossless compression algorithm. While running an OpenMM simulation, the application auto-saves each batch of 12 consecutive frames into one file. The end of the batch contains atomic velocities for resuming the simulation.

Asuming 4 fs time step @ 120 Hz, playback speed must be a multiple of 0.48 ps/s. Replaying at exactly 0.48 ps/s would cause a significant bottleneck; OpenMM would halt the GPU command stream every step. To prevent this bottleneck, try to replay at something over 10 ps/s. Also check how quickly OpenMM is simulating, to gauge how long you'll wait before visualizing. OpenMM would generate 1.2 ps/s of data when simulating 100 ns/day, something achievable with the M1 Max and ~100,000 atoms.

## References

https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474/

https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5063251/

https://pubmed.ncbi.nlm.nih.gov/17080857/

http://litherum.blogspot.com/2021/05/understanding-cvdisplaylink.html
