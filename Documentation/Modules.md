# Modules

## Modeling

- HardwareCatalog[^1]
  - API for instantiating parameterized nano-parts and assemblies (contributions welcome)
  - Markdown documentation for each part, similar to [ML model cards](https://modelcards.withgoogle.com/about)
  - Image of each nano-part and assembly rendered using MolecularRendererApp
- HDL[^1]
  - Hardware description language for crystolecules and mechanical part assemblies
- Shapes[^1]
  - Collection primitive geometric shapes, which build on the hardware description language
  - Unions of infinite planes for extruding slanted and curved surfaces

## Rendering

- MolecularRenderer[^2]
  - Power-efficient ray tracing on Apple platforms
  - Source code for MRSimulation codec (which is designed to be cross-platform)
- MolecularRendererApp[^2]
  - Not a Swift module, but source files for the MolecularRenderer app
  - Contains a large amount of procedural geometry code, currently being extracted into other modules
- MolecularRendererGPU[^2]
  - Metal shader files for MolecularRenderer
  - May include OpenCL files in the future

## Simulation

- DFT[^1]
  - Density functional theory library
  - Used for simulating bond-breaking mechanosynthesis reactions
- MM4[^1]
  - MM4 molecular dynamics forcefield
  - Algorithms for traversing the bond topology and assigning force parameters
- OpenMM, COpenMM
  - Swift bindings for OpenMM

[^1]: Unfinished, not in a production-ready state
[^2]: Only compiles on Apple platforms

