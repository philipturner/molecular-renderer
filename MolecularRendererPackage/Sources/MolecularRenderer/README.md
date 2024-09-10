# Molecular Renderer

This Swift module is the heart of the Molecular Renderer application. It is a ray tracer built from scratch on low-level graphics APIs. The module `MolecularRendererApp` imports this library and drives it through UI controls.

Recommended hardware:
- Apple silicon chip (base M1 chip works with 60 Hz)
- ProMotion laptop display or 144 Hz monitor

Maintenance needed to port this module to Linux and Windows:
- Work with native Linux and Windows APIs for key bindings, windowing
- Translate the Metal GPU shaders to HLSL, which compiles into SPIR-V
- AMD FidelityFX integration for upscaling ray traced images

## References

Discussion of MetalFX upscaling quality: https://forums.macrumors.com/threads/observations-discussion-on-apple-silicon-graphics-performance-with-metalfx-upscaling.2368474

Explanation of RTAO: https://thegamedev.guru/unity-ray-tracing/ambient-occlusion-rtao

Working example of RTAO with source code: https://github.com/nvpro-samples/gl_vk_raytrace_interop

Thesis on ambient occlusion and shadows, specifically for molecules: https://core.ac.uk/download/pdf/20053956.pdf

Thesis about RTAO quality and performance, including accel rebuilds: http://www.diva-portal.org/smash/record.jsf?pid=diva2%3A1574351&dswid=2559

Thesis on bidirectional path tracing: https://graphics.stanford.edu/papers/veach_thesis/thesis.pdf

Uniform grid ray tracing algorithm: https://www.dca.fee.unicamp.br/~leopini/DISCIPLINAS/IA725/ia725-12010/Fujimoto1986-4056861.pdf
