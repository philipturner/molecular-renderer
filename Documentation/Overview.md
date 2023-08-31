# Overview

Current Features:
- Low-power ray traced renderer built on Apple’s Metal API
- GPU-accelerated molecular dynamics with OpenMM
  - Only C-H and C-C bonds
  - No thermostat
  - Does not support external forces
  - Instead, facilitates motion by setting two objects on a high-velocity collision course
- CAD functionality achieved through scripting and procedural geometry
- Minecraft-based UI for moving around in an interactive simulation
  - Built heavily on Apple-specific APIs
- Exporting animations to GIF for conversion to MP4 in [Shotcut](https://shotcut.org/)
  - Room for improvement: integration with Blender, or exporting to other code bases for proper animation
- PDB and MMP parser
- MRSimulation codec for efficiently serializing molecular dynamics trajectories
- ‘Diamondoid’ API that automatically forms sp3 bonds from a group of carbon nucleus positions
  - Performs rotations and assigns bulk velocities to rigid bodies
  - API will be replaced with 'HDL' geometry compiler

Planned Features:
- Written in Swift, but exporting C symbols. These can be used for other languages, such as by the Python ‘ctypes’ library
- Rewritten molecular dynamics simulator
  - Combines MM3, MM4, MMFF parameters
  - C-H, C-C, C-Si, Si-Si, C-Ge, Ge-Ge, C-N, N-N, C-Cl bonds
  - Not yet figured out a way to support sp2 bonds, but that is being considered
  - Allows atoms to be held in place or external forces to act on them
- Surface reconstruction/modification through energy minimization
  - Process also used for Si and N-termination
- Highly efficient density functional theory code for simulating mechanosynthesis (ab initio MD)
  - More accurate than ReaxFF
  - More detailed explanation: https://github.com/philipturner/density-functional-theory
- Electron probability density renderer, looking like [this](https://en.wikipedia.org/wiki/Atomic_orbital#/media/File:Atomic-orbital-clouds_spdf_m0.png).
  - Very likely this can be written in OpenCL for non-Apple platforms with little effort, unlike the ray tracer
- Domain-specific language for designing crystolecules. 
  - Concept: carving out planes from a diamond or lonsdaleite lattice, constructive solid geometry
  - Similar to Nanocut, but allows irregular, sophisticated geometric shapes. The design process is similar to editing blocks in Minecraft, except the blocks are crystal unit cells.
  - My codebase doesn’t include UI-based editing, but connecting it with atomCAD may change that.
