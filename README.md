# Molecular Renderer

Scriptable application for running OpenMM simulations and visualizing at high framerates. Provides up to 120 Hz uninterrupted playback and motion blur to amplify the perceived framerate.

TODO (performance):
- Query GPU cores via OpenCL and calibrate compute power to reference machine, display TFLOPS in advanced debug overlay.
- Are massive-LOD spheres or virtualized ray-traced geometry faster?
- Gather data at sub-frame resolution and incorporate motion blur (only for smaller simulations).
- Use MetalFX temporal upscaling to reduce GPU load? (Spatial on AMD)
- Buffer up frames to perform an acceleration structure compact pass, gauge overhead, usefulness of the operation to query compacted size (or make custom metric).
- Perform rendering for this frame, upscaling for the previous, and refitting for the next frame concurrently.

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
- At least 8 GB of RAM
- SSD with at least 350 MB/s bandwidth

JIT simulation:
- No bounds on simulation length, does not store frame data for replaying later
- Best for very small simulations (<10,000 atoms, <10 ps/s playback)
- Expect a short but noticeable lag between interaction and it affecting the visualization
- May use OpenMM CPU instead of GPU backend

JIT rendering:
- Stores a simulation's geometry data, renders dynamically at runtime
- Best suited for small simulations - <210,000 atoms (no motion blur), <70,000 atoms (motion blur)
- Best suited for interactive visualization
- 7 M1 GPU cores per 60 Hz of display refresh rate
- 14 M1 GPU cores per 120 Hz of display refresh rate
- AMD GPUs have built-in support, but are not tested
- Expect 140 MB (no motion blur), 420 MB (motion blur) per 100,000 atoms per second of playback

AOT rendering:
- Deletes a simulation's geometry data and instead stores compressed 512x512 frames
- Best suited for large simulations, motion blur, or Intel iGPUs
- Camera position is static or has scripted trajectory
- Expect 300 MB per second of playback, but pages longer visualizations to the SSD (also pages for JIT rendering)

Display:
- Monitor with at least 1024x1024 pixels - this application minimizes the image size to maximize framerate. The window size is adjustable, but the application is optimized for 1 million pixels.
- This is a tentative metric; I will need to see how real-world performance actually fares.
- The bottleneck should be vertex stage not fragment stage, so window size shouldn't be an issue. Or maybe it will be problematic with motion blur.

Simulation size:
- Requirements for real-time visualization currently unknown
- JIT, no motion blur: aiming for 1 million atoms
- JIT, motion blur: aiming for 100,000 atoms
- Up to 256 atom types, set to periodic table by default

## Future Steps

This currently runs on macOS with Metal 3. However, it would be possible to port to Windows with Vulkan and FidelityFX.

This application currently supports only space-filling spheres. It could be extended to visualize cylindrical covalent bonds, or coarse-grained DNA nanotechnology.

## References

https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474/
