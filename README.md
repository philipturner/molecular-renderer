# Molecular Renderer

Scriptable application for running OpenMM simulations and visualizing at high framerates. Provides up to 120 Hz uninterrupted playback with RTAO. This application is optimized for simulations with 10,000-1,000,000 atoms.

TODO: Explain motivation, what I'm studying, why it's important.

TODO (performance):
- Use triple-buffering, compact the acceleration structure every 3 frames.
- Use Metal 3 fast resource loading to fetch geometry data from disk, 3 frames ahead.
- Use Metal lossless compression for double-buffered intermediate textures.
- Profile tile-based hybrid rasterization against full ray tracing, may solve divergence problems. Optimize for very complex scenes.
- Determine whether to use ray query API.
- Store previous frame's transform data to re-project the intersection position onto the screen, generating a screen-space motion vector.

TODO (user interface):
- Modular mechanism to plug in different scripts, so I can save my research in a separate repo.
- Way to move camera position using mouse.
- Display OpenMM ps/s, OpenMM ns/day, rendering ps/s, GPU load.
- Serialization format to save the simulation's starting parameters.
- Automatically halt progress at specified GB limit, estimate average and maximum size from simulation parameters, show remaining disk space.
- Way to adjust aspect ratio while maintaining 1 million pixels.
- Support replaying at integer multiples of the sample rate, exporting 24 Hz video.
- Support replaying at 1/2, 1/4, 1/8 the speed by decreasing the display refresh rate.
- Support 1 fs, 2 fs, 4 fs time step modes.

TODO (presentation):
<!--
- Appealing fade-in effect for starting replay of a simulation, hides the startup latency.
- Fade-in reveals center before edges, receding shadow matches silhouette of simulation.
-->
- Minecraft-like font presenting: simulation hours, number of atoms (rounded to small s.f.), simulation name, factor of time amplification for slow-motion (rounded to small s.f.).

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
- Need monitor with at least 1024x1024 pixels
- Only 60 Hz and 120 Hz supported
- Window aspect ratio is adjustable, but will resize to stay at 1 million pixels

## Technical Details

This application currently requires an Apple M1 chip running Metal 3. It is optimized for the author's personal machine (M1 Max), and samples the OpenMM simulation 120 times per second\*. The platform restriction makes it easier for the author to develop, but it can be ported to other devices. For example, MetalFX spatial upscaling would let it run on Intel Macs. One could also port it to Windows through Vulkan and FidelityFX.

> \*When targeting a 60 Hz display or exporting 24 Hz video, it simply renders every n-th frame.

Before serialization, geometry data packs into an efficient format - three `float` numbers per atom, with a stride of 12 B. Shaders compute velocity from positions between frame timestamps, rather than the actual atomic velocities. This is more appropriate for MetalFX temporal upscaling and removes the need to store velocities on disk. Finally, the geometry data is archived using the [LZBITMAP](https://developer.apple.com/documentation/compression/compression_lzbitmap) lossless compression algorithm. While running an OpenMM simulation, the application auto-saves each batch of 12 consecutive frames into one file. The end of the batch contains atomic velocities for resuming the simulation.

Asuming 4 fs time step @ 120 Hz, playback speed must be a multiple of 0.48 ps/s. Replaying at exactly 0.48 ps/s would cause a significant bottleneck; OpenMM would halt the GPU command stream every step. To prevent this bottleneck, try to replay at something over 10 ps/s. Also check how quickly OpenMM is simulating, to gauge how long you'll wait before visualizing. OpenMM would generate 1.2 ps/s of data when simulating 100 ns/day, something achievable with the M1 Max and ~100,000 atoms.

## References

https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474/

https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5063251/

https://pubmed.ncbi.nlm.nih.gov/17080857/
