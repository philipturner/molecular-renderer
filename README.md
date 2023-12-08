
![image](https://github.com/philipturner/molecular-renderer/assets/71743241/d5585c84-7e4e-4507-841a-452fb68615d3)

# Molecular Renderer

This repository is a ray tracer for molecular nanotechnology. It originally encapsulated several other projects, most of which have moved into separate repositories.

Projects
- [Hardware Catalog](./Sources/HardwareCatalog/README.md) - attempt at a catalog of reusable parts, currently unsuccessful
- [Hardware Description Language](https://github.com/philipturner/hardware-description-language) - domain-specific language for crystolecule design
- [MM4](https://github.com/philipturner/MM4) - hydrocarbon/hydrosilicon simulator
- [MRSimulation Codec](./Documentation/MRSimulation.md)

## Overview

NanoEngineer is currently the most capable platform for designing molecular nanotechnology. It has an interactive UI, but also simulators that run slowly at >5000 atoms. This restricts the design to colorful strained shell structures [in order to minimize atom count](http://www.imm.org/research/parts/controller/). Several projects seek to improve on this aspect - the difficulty performing iterative design on non-strained crystolecules.

Most projects (Atomic Machines, CBN Nano Technologies) are closed-source. Until recently, the only OSS that aspiring engineers could rely on was NanoEngineer, which went unmaintained in 2008. This code base follows a more modern [approach](https://github.com/atomCAD/atomCAD/wiki) than close-sourcing:

> ...for a molecular nanotechnology industry to exist, there must be such a society of engineers that transcends any single company, and a public body of knowledge capturing best practices for nano-mechanical engineering design. Other companies are training engineers on in-house tools where they create designs never to be seen by the outside world. We believe strongly that needs to change...

## State of Cross-Platform Support

The simulation and GUI-less CAD libraries are being rewritten from scratch. The end product will run on all platforms. In addition, the vast majority of `Sources/MolecularRendererApp` has been ported to cross-platform Swift toolchains. However, it is not in a "production-ready" state. 

Maintenance effort to port the ray tracer to Linux and Windows:
- Work with native Linux and Windows APIs for key bindings, windowing
- Translate the Metal GPU shaders to HLSL, which compiles into SPIR-V
- AMD FidelityFX integration for upscaling ray traced images

Prioritizing macOS for all development. Current solution for other platforms: 
- Transcode the simulation to `mrsim-txt` and save to the disk.
- Decode in a script controlling an alternative renderer (VMD, Blender, etc.).
- This may require a different language than Swift. There is a decently fast Rust decoder, which is most recommended on Windows (Swift is slow there for an unknown reason).
