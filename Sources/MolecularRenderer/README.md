# Molecular Renderer

This Swift module is the heart of the Molecular Renderer application. It is a ray tracer built from scratch on low-level graphics APIs. The module `MolecularRendererApp` imports this library and drives it through UI controls.

Recommended hardware:
- Apple silicon chip (base M1 chip works with 60 Hz)
- ProMotion laptop display or 144 Hz monitor

Maintenance needed to port this module to Linux and Windows:
- Work with native Linux and Windows APIs for key bindings, windowing
- Translate the Metal GPU shaders to HLSL, which compiles into SPIR-V
- AMD FidelityFX integration for upscaling ray traced images
