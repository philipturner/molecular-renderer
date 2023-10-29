
![image](https://github.com/philipturner/molecular-renderer/assets/71743241/d5585c84-7e4e-4507-841a-452fb68615d3)

# Molecular Renderer

Author: Philip Turner

What began as a ray traced renderer, is now a cross-platform library used to design molecular nanotechnology. Similar to OpenSCAD, but with GPU-accelerated molecular simulation. Working toward software capable of synthesizing million-atom productive nanosystems.

Documentation
- [Hardware Catalog](./Sources/HardwareCatalog/README.md)
- [Modeling Language](./Documentation/HDL.md)
- [Modules](./Documentation/Modules.md)
- [MRSimulation Codec](./Documentation/MRSimulation.md)
- [References](./Documentation/References.md)

## Overview

NanoEngineer is currently the most capable platform for designing molecular nanotechnology. It has an interactive UI, but also simulators that run slowly at >5000 atoms. This restricts the design to colorful strained shell structures [in order to minimize atom count](http://www.imm.org/research/parts/controller/). Several projects seek to improve on this aspect - the difficulty performing iterative design on non-strained crystolecules.

For about a year, this project was an independent effort that began with optimizing OpenMM. From May to October 2023, it was slated to join forces with atomCAD. After extensive discussions, we realized our approaches were too different. Molecular Renderer grew rapidly and let people _from all major operating systems_ do exploratory engineering, with existing MD simulation methods. atomCAD evolved more slowly, due to a carefully planned internal representation that can scale to 100x more atoms. Developers from both projects have exchanged ideas and engaged in constructive feedback.

Most projects (Atomic Machines, CBN Nano Technologies) are closed-source. Until recently, the only OSS that aspiring engineers could rely on was NanoEngineer, which went unmaintained in 2008. This code base is following a modern [vision](https://github.com/atomCAD/atomCAD/wiki) that:

> ...for a molecular nanotechnology industry to exist, there must be such a society of engineers that transcends any single company, and a public body of knowledge capturing best practices for nano-mechanical engineering design. Other companies are training engineers on in-house tools where they create designs never to be seen by the outside world. We believe strongly that needs to change...

## State of Cross-Platform Support

The simulation and GUI-less CAD libraries are being rewritten from scratch. The end product will run on all platforms. In addition, the vast majority of `Sources/MolecularRendererApp` has been ported to cross-platform Swift toolchains. However, it is not in a "production-ready" state. 

Need to port the ray traced trajectory viewer to Linux and Windows:
- Work with native Linux and Windows APIs for key bindings, windowing
- Translate the Metal GPU shaders to HLSL, which compiles into SPIR-V
- AMD FidelityFX integration for upscaling ray traced images

Prioritizing Linux for compute, exporting trajectories to macOS for rendering. Current solution for other platforms: 
- Transcode the simulation to `mrsim-txt` and save to the disk.
- Decode in a script controlling an alternative renderer (VMD, atomCAD, Blender, etc.).
- This may require a different language than Swift. There is a decently fast Rust decoder, which is most recommended on Windows (Swift is slow there for an unknown reason).

## Roadmap

Short-Term (next few weeks)
- Port core functionality to Linux and Windows - **in progress**
- Modularize the source code, allow the simulator to be used with external renderers
  - Find a high-efficiency way to serialize and share MD simulation trajectories, which is easy to parse using Python ✅
- Create a domain-specific language and geometry compiler for crystolecule design ✅
- Upgrade MM4 to include more elements and external forces - **in progress**
- Integrate the official [xTB](https://github.com/grimme-lab/xtb) CPU simulator

Long-Term (next few months)
- Experiments with scaling up CAD software
  - Engineering knowledge base (catalog) for nanomechanical parts and geometric primitives
  - Implement the [Kaehler bracket](https://legacy.foresight.org/Updates/Update10/Update10.3.html) indexing algorithm outlined in _Nanosystems 9.5.5_
  - Search for other tools that can automate large systems-level CAD workflows
- Optimize for multi-GPU desktop machines
  - Resolve $O(n^2)$ scaling issues with non-carbon elements ✅
  - Quick prototyping of assemblies with ~100,000 atoms
  - Overnight simulation of systems with ~1,000,000 atoms

Non-Goals
- Use simulators with working CUDA-only GPU acceleration
- Write new simulator implementations that aren't $O(n)$ (GFN-FF), outside of [maximally efficient DFT](https://github.com/philipturner/molecular-renderer/blob/main/Documentation/DFT.md)
- Use simulators that aren't derived from the laws of physics (IM-UFF, ReaxFF)
- Create a graphical user interface beyond the minimal MD trajectory viewer
