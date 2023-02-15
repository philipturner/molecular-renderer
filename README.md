# Molecular Renderer

Scriptable Mac application for running OpenMM simulations and visualizing them at 120 Hz.

TODO:
- Query GPU cores via OpenCL and calibrate compute power to reference machine, display TFLOPS in advanced debug overlay.
- Are massive-LOD spheres or virtualized ray-traced geometry faster?
- Gather data at sub-frame resolution and incorporate motion blur (only for smaller simulations).
- Use MetalFX temporal upscaling to reduce GPU load? (Spatial on AMD)
- Separate Swift files for ported forcefields (oxDNA, AIREBO, etc.), unless they need separate plugins.
- Modular mechanism to plug in different scripts, so I can save my research in a separate repo.
- Video exporting tool, demo video of a rod-logic mechanical computer.
- Limited interactivity with the visualization.
- Serialization format to save an in-progress simulation.
- Interactive mechanism to adjust aspect ratio while maintaining 1 million pixels.

## Requirements

Assumes you have the following ratio of compute power:
- 7 M1 GPU cores per 60 Hz of display refresh rate
- 14 M1 GPU cores per 120 Hz of display refresh rate
- AMD GPUs have built-in support, but are not tested
- On devices with more GPU compute ratio, this application may add more keyframes to motion blur.

Display:
- Monitor with at least 1024x1024 pixels - this application minimizes the image size to maximize framerate. The window size is adjustable, but the application is optimized for 1024x1024.
- This is a tentative metric; I will need to see how real-world performance actually fares.
- The bottleneck should be vertex stage not fragment stage, so window size shouldn't be an issue. Or maybe it will be problematic with motion blur.

Simulation size:
- Unknown at the moment
- No motion blur: aiming for 1 million atoms
- Motion blur: aiming for 100,000 atoms

OpenMM version:
- 8.0 with the [Metal plugin](https://github.com/philipturner/openmm-metal) installed, or:
- 8.1 pre-release with optimized OpenCL backend

## References

https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474/
