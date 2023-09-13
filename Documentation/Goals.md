# Goals

NanoEngineer is currently the best platform for designing molecular nanotech. It has an interactive UI, but also very slow simulators that can't handle >5000 atoms. This forces users to design colorful strained shell structures (which cannot be built) [just to minimize atom count](http://www.imm.org/research/parts/controller/). atomCAD and collaborating OSS projects seek to improve on NanoEngineer's weaknesses, especially the difficulty performing iterative design on crystolecules.

Since ~May 2023, this repository was slated to join forces with atomCAD. After months of discussion, we realized the best way to collaborate was specializing in separate niches. Molecular Renderer will grow rapidly and allow people _from all desktop operating systems_ to do exploratory engineering _very soon_. atomCAD evolves more slowly, due to a carefully planned internal representation that will scale better and support more platforms (mobile, WASM). Developers from both projects are actively exchanging ideas and engaging in constructive feedback, using the atomCAD discord and other means.

It is a measure of collaboration that we are sharing source code. Most projects (Atomic Machines, CBN Nano Technologies) are closed-source. The only OSS that aspiring engineers can rely on is NanoEngineer, which went unmaintained in 2008. We both share the vision (verbatim from atomCAD's wiki):

> ...for a molecular nanotechnology industry to exist, there must be such a society of engineers that transcends any single company, and a public body of knowledge capturing best practices for nano-mechanical engineering design. Other companies [are training engineers] on in-house tools where they create designs never to be seen by the outside world. We believe strongly that needs to change...

Short-Term (next few weeks)
- Port some functionality to Linux and Windows
- Modularize the source code, allow the simulator to be used with external renderers
  - Find a high-efficiency way to serialize and share MD simulation trajectories, which is easy to parse using Python ✅
- Create a domain-specific language and geometry compiler for crystolecule design
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
