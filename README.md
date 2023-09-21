
![image](https://github.com/philipturner/molecular-renderer/assets/71743241/d5585c84-7e4e-4507-841a-452fb68615d3)

# Molecular Renderer

What began as a ray traced renderer, is now a cross-platform library used to design molecular nanotechnology. Similar to OpenSCAD, but with GPU-accelerated molecular simulation. Working on a large engineering knowledge base with machine specification in atomic detail.

Documentation
- Getting Started (TODO)
- [Modeling Language](./Documentation/HDL.md)
- [Modules](./Documentation/Modules.md)
- [MRSimulation Codec](./Documentation/MRSimulation.md)
- [References](./Documentation/References.md)

## Overview

NanoEngineer is currently the most capable platform for designing molecular nanotechnology. It has an interactive UI, but also simulators that run slowly at >5000 atoms. This motivates the design of colorful strained shell structures (which cannot be built) [in order to minimize atom count](http://www.imm.org/research/parts/controller/). Several projects seek to improve on this aspect, and on the difficulty performing iterative design on crystolecules.

Since ~May 2023, this repository was slated to join forces with atomCAD. After months of discussion, we realized the best way to collaborate was specializing in separate niches. Molecular Renderer grew rapidly and lets people _from all desktop operating systems_ do exploratory engineering _today_. atomCAD evolved more slowly, due to a carefully planned internal representation that will scale better and support more platforms. Developers from both projects are actively exchanging ideas and engaging in constructive feedback, using Discord and other means.

It is a measure of collaboration that we are sharing source code. Most projects (Atomic Machines, CBN Nano Technologies) are closed-source. Until recently, the only OSS that aspiring engineers could rely on was NanoEngineer, which went unmaintained in 2008. We all share the [vision](https://github.com/atomCAD/atomCAD/wiki) that:

> ...for a molecular nanotechnology industry to exist, there must be such a society of engineers that transcends any single company, and a public body of knowledge capturing best practices for nano-mechanical engineering design. Other companies are training engineers on in-house tools where they create designs never to be seen by the outside world. We believe strongly that needs to change...

Short-Term (next few weeks)
- Port core functionality to Linux and Windows
- Modularize the source code, allow the simulator to be used with external renderers
  - Find a high-efficiency way to serialize and share MD simulation trajectories, which is easy to parse using Python ✅
- Create a domain-specific language and geometry compiler for crystolecule design ✅
- Upgrade MM4 to include more elements and external forces

Medium-Term (next few months)
- Establish a first-generation engineering knowledge base (database) for nanomechanical parts, written in the Swift DSL
- Combine the bounded continuum model (introduced in _Nanosystems_) with an $O(n)$ finite element method (for bulk deformations) to accelerate MD simulations
  - Enable quick prototyping of assemblies with over 100,000 atoms
- Create tutorials to onboard new nanomechanical engineers (Jupyter notebooks, online DocC tutorials, etc.)
- Exploratory engineering work on [kinematic self-replicating machines](http://www.molecularassembler.com/KSRM.htm) and/or mechanical computers

Long-Term (next few years)
- Create a simulator for mechanosynthesis reactions, and novel rendering algorithms to interpret simulation results
  - Ab initio and semiempirical methods such as DFT, [GFN-xTB, GFN-FF](https://github.com/grimme-lab/xtb)
- Plugin for Eric Drexler's MSEP program, which utilizes their GUI, but adds new CAD or simulation functionality

Non-Goals
- Create a SAMSON plugin
- Use simulators that aren't GPU-accelerated, or require CUDA
- Use simulators that aren't derived from the laws of physics (IM-UFF, ReaxFF)
- Rewrite the Swift code in Python

