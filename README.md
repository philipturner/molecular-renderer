
![image](https://github.com/philipturner/molecular-renderer/assets/71743241/d5585c84-7e4e-4507-841a-452fb68615d3)

# Molecular Renderer

Author: Philip Turner

What began as a ray traced renderer, is now a cross-platform library used to design molecular nanotechnology. Similar to OpenSCAD, but with GPU-accelerated molecular simulation. Working on a large engineering knowledge base with machine specification in atomic detail.

Documentation
- [Hardware Catalog](./Sources/HardwareCatalog/README.md)
- [Modeling Language](./Documentation/HDL.md)
- [Modules](./Documentation/Modules.md)
- [MRSimulation Codec](./Documentation/MRSimulation.md)
- [References](./Documentation/References.md)

## Overview

NanoEngineer is currently the most capable platform for designing molecular nanotechnology. It has an interactive UI, but also simulators that run slowly at >5000 atoms. This motivates the design of colorful strained shell structures (which cannot be built) [in order to minimize atom count](http://www.imm.org/research/parts/controller/). Several projects seek to improve on this aspect, and on the difficulty performing iterative design on crystolecules.

Since ~May 2023, this repository was slated to join forces with atomCAD. After some time, we realized the best way to collaborate was trying different approaches. Molecular Renderer grew rapidly and lets people _from all desktop operating systems_ do exploratory engineering _today_. atomCAD evolved more slowly, due to a carefully planned internal representation that will scale larger and support more platforms. Developers from both projects have exchanged ideas and engaged in constructive feedback.

It is a measure of collaboration that source code is being shared. Most projects (Atomic Machines, CBN Nano Technologies) are closed-source. Until recently, the only OSS that aspiring engineers could rely on was NanoEngineer, which went unmaintained in 2008. This code base contributes toward the [vision](https://github.com/atomCAD/atomCAD/wiki) that:

> ...for a molecular nanotechnology industry to exist, there must be such a society of engineers that transcends any single company, and a public body of knowledge capturing best practices for nano-mechanical engineering design. Other companies are training engineers on in-house tools where they create designs never to be seen by the outside world. We believe strongly that needs to change...

## Roadmap

Short-Term (next few weeks)
- Port core functionality to Linux and Windows - **in progress**
- Modularize the source code, allow the simulator to be used with external renderers
  - Find a high-efficiency way to serialize and share MD simulation trajectories, which is easy to parse using Python ✅
- Create a domain-specific language and geometry compiler for crystolecule design ✅
- Upgrade MM4 to include more elements and external forces - **in progress**

Medium-Term (next few months)
- Establish a first-generation engineering knowledge base (database) for nanomechanical parts, written in the Swift DSL
- Optimize for multi-GPU desktop machines
  - Resolve $O(n^2)$ scaling issues with non-carbon elements
  - Quick prototyping of assemblies with ~100,000 atoms
  - Overnight simulation of systems with ~1,000,000 atoms

Long-Term (next few years)
- Create tutorials to onboard new nanomechanical engineers (Jupyter notebooks, online DocC tutorials, etc.)
- Create a simulator for mechanosynthesis reactions, and novel rendering algorithms to interpret simulation results
  - Ab initio and semiempirical methods such as DFT, [GFN-xTB, GFN-FF](https://github.com/grimme-lab/xtb)
- Plugins for atomCAD and/or MSEP, which utilize their GUI, but add new design or simulation functionality

Non-Goals
- Create a SAMSON plugin
- Use simulators that aren't GPU-accelerated, or require CUDA
- Use simulators that aren't derived from the laws of physics (IM-UFF, ReaxFF)
- Rewrite the Swift code in Python

<!--

Milestones
- [x] Repository created _(2/14/2023)_
- [x] First molecule rendered _(4/14/2023)_
- [x] Finished ray tracer _(7/19/2023)_
- [x] First MM4 simulator _(7/30/2023)_
- [x] Production renderer _(8/7/2023)_
- [x] First source file compiling on non-Apple platforms _(8/30/2023)_
- [x] MRSimulation-Text codec _(9/7/2023)_
- [x] First shape compiled with DSL _(9/16/2023)_
- [ ] H, C, Si working under new simulator _(projected: October 2023)_
- [ ] Finished new geometry compiler _(projected: October 2023)_
- [ ] Hardware catalog reaches 20 entries _(projected: November 2023)_

-->
