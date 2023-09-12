# Overview

Current Features:
- Written in Swift, with no C symbols exported
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
  - Room for improvement: integration with Blender, or interfacing with other code bases for direct MP4 conversion
- PDB and MMP parser
- `MRSimulation` codec for efficiently serializing molecular dynamics trajectories
- `Diamondoid` API that automatically forms sp3 bonds from a group of carbon nucleus positions
  - Performs rotations and assigns bulk velocities to rigid bodies
  - API will be replaced with `HDL` geometry compiler

Planned Features:
- Written in Swift, but exporting C symbols. These can be used in other languages, such as by the Python `ctypes` library
  - All software uses C symbols under the hood, even C++ and Rust. These are what make up dynamic libraries (`.dylib` or `.dll`).
- Rewritten molecular dynamics simulator
  - <s>Combines MM3, MM4, MMFF parameters</s>
  - <s>C-H, C-C, C-Si, Si-Si, C-Ge, Ge-Ge, C-N, N-N, C-Cl bonds</s> most of the P-block of the periodic table
  - <s>Not yet figured out a way to support sp2 bonds, but that is being considered</s>
  - Allows atoms to be held in place or external forces to act on them
- Surface reconstruction/modification through energy minimization
  - Allows atoms not perfecty aligned to the diamond or lonsdaleite lattice
  - Process also used for Si- and N-termination
  - Used to design and index Kaehler brackets
- Highly efficient density functional theory code for simulating mechanosynthesis (ab initio MD)
  - More accurate than ReaxFF
  - More detailed explanation: https://github.com/philipturner/density-functional-theory
  - Eventually, GFN-xTB or GFN-FF for timesteps where a reaction does not occur
- Electron probability density renderer, looking like [this](https://en.wikipedia.org/wiki/Atomic_orbital#/media/File:Atomic-orbital-clouds_spdf_m0.png).
  - Very likely this can be written in OpenCL for non-Apple platforms with little effort, unlike the ray tracer
- Domain-specific language for designing crystolecules. 
  - Concept: carving out planes from a diamond or lonsdaleite lattice, constructive solid geometry
  - Similar to Nanocut, but allows irregular, sophisticated geometric shapes. The design process is similar to editing blocks in Minecraft, except the blocks are crystal unit cells.
  - My codebase doesn’t include UI-based editing, but connecting it with atomCAD may change that.

About Swift:
  - Swift was built by Apple, and the most popular Swift APIs are Apple-specific
  - That does not mean Swift cannot run on other platforms (Linux was a first, then Windows and Android, now WASM)
  - MolecularRenderer can become one of the Swift APIs that are cross-platform.
  - A similar argument could be made that C# is Windows-only, except some C# frameworks (Unity Engine) are cross-platform.
