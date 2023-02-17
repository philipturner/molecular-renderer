# Molecular Renderer

Scriptable application for running OpenMM simulations and visualizing at high framerates. Provides up to 120 Hz uninterrupted playback and motion blur to amplify the perceived framerate.

TODO (performance):
- Query GPU cores via OpenCL and calibrate compute power to reference machine, display TFLOPS in advanced debug overlay.
- Are massive-LOD spheres or virtualized ray-traced geometry faster?
- How well does MetalFX spatial or temporal upscaling mesh with motion blur?
- Buffer up frames to perform an acceleration structure compact pass, gauge overhead, usefulness of the operation to query compacted size (or make custom metric).
- Perform rendering, upscaling, and refitting for different frames concurrently.

TODO (user interface):
- Modular mechanism to plug in different scripts, so I can save my research in a separate repo.
- Video exporting tool, demo video of a rod-logic mechanical computer.
- Basic interactivity with the visualization.
- Serialization format to save an in-progress simulation.
- Interactive mechanism to adjust aspect ratio while maintaining 1 million pixels.

## Requirements

Dependencies:
- macOS Ventura
- Xcode 14 installed
- OpenMM 8.0 with the [Metal plugin](https://github.com/philipturner/openmm-metal) installed, or:
- OpenMM 8.1 pre-release with optimized OpenCL backend

Memory:
- At least 8 GB of RAM - this application will cache 4 GB of compressed data in memory
- Hard drive with at least 250 MB/s bandwidth

<!--
JIT simulation:
- No bounds on simulation length, does not store frame data for replaying later
- Best suited for very small simulations (<10,000 atoms, <10 ps/s playback)
- Expect a noticeable lag between interaction and it affecting the visualization
- May use OpenMM CPU instead of GPU backend
-->

JIT rendering:
- Stores a simulation's geometry data, renders dynamically at runtime
- Most memory-efficient for small simulations - <180,000 atoms (no motion blur), <70,000 atoms (motion blur)
- Best suited for interactive visualization
- 7 M1 GPU cores per 60 Hz of display refresh rate
- 14 M1 GPU cores per 120 Hz of display refresh rate
- AMD GPUs have built-in support, but are not tested
- Before compression: 140 MB (no motion blur), 350 MB (motion blur) per 100,000 atoms per second of playback

AOT rendering:
- Deletes a simulation's geometry data and instead stores compressed 512x512 frames
- Best suited for large simulations, motion blur, or Intel iGPUs
- Camera position is static or has scripted trajectory
- Before compression: 240 MB per second of playback

Display:
- Monitor with at least 1024x1024 pixels
- The window size and aspect ratio are adjustable, but the application is optimized for 1 million pixels.
- 512x512 -> 1024x1024 upscaled - requires MetalFX temporal upscaling, only M1
- 768x768 -> 1024x1024 upscaled - requires MetalFX spatial upscaling, supported on x86
- Spatial upscaling requires less metadata, so no change to memory costs

Simulation size:
- Requirements for real-time visualization currently unknown
- JIT, no motion blur: aiming for 1 million atoms
- JIT, motion blur: aiming for 100,000 atoms
- Up to 256 atom types, colors and radii match periodic table by default

## Technical Details

All geometry data and pre-rendered frames use the [LZBITMAP](https://developer.apple.com/documentation/compression/compression_lzbitmap) compression algorithm. Before serialization, data are also compacted into an efficient format. The velocity is computed using positions between frame timestamps, rather than the actual atomic velocity. This is more appropriate for MetalFX temporal upscaling.

```
JIT: per atom (no motion blur)
3 x (4 B = coordinate position)
- 12 B

JIT: per atom (motion blur)
3 x (4 B = coordinate minimum, 2 B = distance to maximum, 1+1+1+1 B = quantized keyframes)
- 30 B

AOT: per pixel (MetalFX temporal)
10 bits, 10 bits, 10 bits = color
14 bits = normalized depth, inverted to make dynamic range suited for quantization
10 bits, 10 bits = velocity in pixels/frame, FP16 with lower 6 bits truncated
- 8 B

AOT: per pixel (MetalFX spatial)
10 bits, 10 bits, 10 bits = color
- 4 B
```

Playback speeds: assuming 4 fs time step, 120 Hz, 4x temporal supersampling for motion blur, playback must be a multiple of 1.92 ps/s. The minimum multiple would cause a significant bottleneck; OpenMM would halt the GPU command stream every step. Aim for a large multiple of this number, in the range of 100 ps/s - 1 ns/s. For reference, the simulation would generate 1.2 ps of data each second when simulating 100 ns/day.

## Future Steps

This currently runs on macOS with Metal 3. However, it can be ported to Windows with Vulkan and FidelityFX.

This application currently renders only space-filling spheres. It could be extended to visualize cylindrical covalent bonds, or coarse-grained DNA nanotechnology.

## References

https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474/
