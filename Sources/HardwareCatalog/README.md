# Hardware Catalog

Table of Contents
- [Overview and Roadmap](#overview-and-roadmap)
- [Rules](#rules)
- [Index](#index)

## Overview and Roadmap

Overview:
- Each file contains some carbon-center stage geometry, which relies on "HDL".
  - Precursor: finish implementing the `Lattice` type, so it conforms to the documented API. Add support for hexagonal diamond.
  - Sometimes, a part may be revised to improve performance, often due to new atom types added to the force field. To avoid breaking existing assemblies that use this part, create a new part. It has the same name as the previous one, but with `_V2` appended to it.
      - If used very often, this scheme may be refactored into an API accepting version strings. Prepare for this change by making subsequent versions have the same properties/members as the original.
- Each file contains some code for testing the part, which relies on the new "MM4" (module not built yet). The old MM4 accepts all the data needed by the new MM4.
  - The test case may be arbitrarily defined, just something you can run to prove the part works.
  - Should provide a way to extract the atom trajectory from the simulation, serialize to MRSimulation, then replay somewhere else.
    - Precursor: cross-platform MRSimulation encoder.
    - Precursor: decide on the best API for returning atom trajectories.

Near-term:
- Host the source code for the `Lattice` and the documentation in the catalog.
- Keep appending files to the "MolecularRendererApp/Scenes/References" directory, which is already quite exhausted.
- Once the necessary modules are complete, stop appending to the `MolecularRendererApp` directory and write test code inside the respective `HardwareCatalog` file.
- Rewrite the code from "MolecularRendererApp/Scenes/References" for the parts created before the switch.

## Rules

Documentation Rules:
- Each file contains a Markdown file, located in the same directory as the source folder.
- The author of the part must be stated at the very top. If there are multiple others, state them in the order of greatest contribution. If two authors have equal contribution, state them alphabetically.
- At least one clear image of the part must be present afterward. If not created with the MolecularRenderer ray tracer, the repo maintainer will eventually replace the image.
- Each parameter for instantiating the Swift data structure must be labeled on the documentation page.

API Rules:
- Each part or assembly is a Swift data structure. Code must adhere to mutable value semantics and Swift [API design guidelines](https://www.swift.org/documentation/api-design-guidelines).
- There are no rules as to what properties, members, or initializers a part must contain. Good practices may be discovered after designing several parts, then enforced by revising old non-conforming parts.
- If possible, each indexed item should be parametric. The constructor should accept multiple parameters that change the part's geometry. You must test the part under a large range of reasonable parameter combinations.
- If any parameter combination will produce a non-functional part, you must throw a Swift error. These initializers would be throwing initializers (append the `throws` keyword to the initializer declaration). Such initializers will typically be called with `try!`, but sometimes the user may wish to handle it more gracefully.
- Parameter types:
  - Integer parameters should use the Swift `Int` type (a 64-bit integer) unless there is good reason to use a different integral type.
  - Floating-point parameters should use the Swift `Float` type (a 32-bit real number) unless there is significant need for using double precision.
  - Distances are always measured in nanometers.

## Index

Index:
- [Diamond Rope](./DiamondRope)
- [Rhombic Dodecahedron](./RhombicDodecahedron)
- [Ring](./Ring)
- [vdW Oscillator](./VdwOscillator)

Ideas of parts to add:
- [Octahedral Spring](./OctahedralSpring)
- Pseudogear Rack Differential
