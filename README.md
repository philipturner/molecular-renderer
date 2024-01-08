
![image](https://github.com/philipturner/molecular-renderer/assets/71743241/d5585c84-7e4e-4507-841a-452fb68615d3)

# Molecular Renderer

Molecular Renderer is a ray tracer for molecular nanotechnology. It originally encapsulated several other projects, which branched off into distinct libraries.

Projects:
- [Hardware Catalog](./Sources/HardwareCatalog/README.md) - catalog of mini-libraries and archived experiments
- [HDL](https://github.com/philipturner/HDL) - domain-specific language and crystolecule compiler
- [MM4](https://github.com/philipturner/MM4) - hydrocarbon and hydrosilicon simulator
- [Simulation Import](./Sources/SimulationImport) - decoder for the [MRSimulation](./Documentation/MRSimulation.md) plain-text format

## Overview

Until 2024, NanoEngineer was the most capable platform for designing molecular nanotechnology. It had an interactive UI, but also simulators that ran slowly at >5000 atoms. This restricted the design to colorful strained shell structures [in order to minimize atom count](http://www.imm.org/research/parts/controller/). Several projects sought to improve on this aspect - the difficulty performing iterative design on nanomachines.

The most well-funded projects (Atomic Machines, CBN Nano Technologies) are closed-source. As a result, aspiring engineers had to rely on the 15-year old NanoEngineer. The successor needed to follow a more modern [approach](https://github.com/atomCAD/atomCAD/wiki) than close-sourcing:

> ...for a molecular nanotechnology industry to exist, there must be such a society of engineers that transcends any single company, and a public body of knowledge capturing best practices for nano-mechanical engineering design. Other companies are training engineers on in-house tools where they create designs never to be seen by the outside world. We believe strongly that needs to change...

Out of all the ongoing efforts to succeed NanoEngineer, Molecular Renderer was the first to breach million-atom scale. It was built from scratch to enable engineering of massive systems, and achieved exactly that. The scale that unlocks general-purpose compute, self-replication, and cytonavigation.

## Installation

Dependencies:
- macOS 14
- OpenMM 8.1.0
- OpenMM [Metal plugin](https://github.com/philipturner/openmm-metal)
- Xcode

Recommended hardware:
- Apple silicon chip (base M1 chip works with 60 Hz)
- ProMotion laptop display or 144 Hz monitor

## Cross-Platform Support

The simulators and compilers (GUI-less CAD libraries) run on all platforms. Large chunks of code were migrated from the vendor-specific `MolecularRendererApp` module to the `HardwareCatalog` archive.

Maintenance effort to port the app to Linux and Windows:
- Work with native Linux and Windows APIs for key bindings, windowing
- Translate the Metal GPU shaders to HLSL, which compiles into SPIR-V
- AMD FidelityFX integration for upscaling ray traced images

Current solution for Linux and Windows: 
- Transcode the simulation to `mrsim-txt` and save to the disk.
- Decode in a script controlling an alternative renderer (VMD, Blender, etc.).
- This may require a different language than Swift. `Sources/SimulationImport` contains a decently fast Rust decoder, which is highly recommended on Windows (Swift is slow there for an unknown reason).
