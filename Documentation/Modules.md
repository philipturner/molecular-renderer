# Modules

## Modeling

- HardwareCatalog
  - API for instantiating parameterized nano-parts and assemblies (contributions welcome)
  - Markdown documentation for each part, similar to [ML model cards](https://modelcards.withgoogle.com/about)
  - Image of each nano-part and assembly rendered using MolecularRendererApp
  - Collection of primitive geometric shapes, which build on the hardware description language
- HDL
  - Hardware description language for crystolecules and mechanical part assemblies
  - Geometry compiler for generating atoms and modifying crystal surfaces
  - RigidBody wrapper for stiff diamond mechanical parts

## Rendering

- MolecularRenderer[^1]
  - Power-efficient ray tracing on Apple platforms
  - Source code for MRSimulation codec (which is designed to be cross-platform)
- MolecularRendererApp[^1]
  - Not a Swift module, but source files for the MolecularRenderer app
  - Contains a large amount of procedural geometry code, currently being extracted into other modules
- MolecularRendererGPU[^1]
  - Metal shader files for MolecularRenderer

## Simulation

> These libraries were formerly in the molecular-renderer source tree, but have been factored into standalone repositories.

- MM4
  - MM4 molecular dynamics forcefield
  - Algorithms for traversing the bond topology and assigning force parameters
  - [new repository](https://github.com/philipturner/MM4)
- OpenMM, COpenMM
  - Swift bindings for OpenMM
  - [new repository](https://github.com/philipturner/swift-openmm)

[^1]: Only compiles on Apple platforms

