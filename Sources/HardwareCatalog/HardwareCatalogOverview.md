# Hardware Catalog

Overview:
- Each file contains some carbon-center stage geometry, which relies on "HDL".
  - Precursor: finish implementing the `Lattice` type, so it conforms to the documented API. Add support for hexagonal diamond.
- Each file contains some code for testing the part, which relies on "MM4" (module not built yet) and the `Passivate` keyword (not implemented).
  - The test case may be arbitrarily defined, just something you can run to prove the part works.
  - Should provide a way to extract the atom trajectory from the simulation, serialize to MRSimulation, they replay somewhere else.
    - Precursor: cross-platform MRSimulation encoder.
    - Precursor: decide on the best API for returning atom trajectories.
- Each file contains a Markdown file, located in the same directory as the source folder.

Near-term:
- Host the source code for the `Lattice` and the documentation in the catalog.
- Keep appending files to the "MolecularRendererApp/Scenes/References" directory, which is already quite exhausted.
- Once the necessary modules are complete, stop appending to the `MolecularRendererApp` directory and write test code inside the respective `HardwareCatalog` file.
  - Rewrite the code from "MolecularRendererApp/Scenes/References" for the parts created before the switch.

Index of Parts:
- TODO
