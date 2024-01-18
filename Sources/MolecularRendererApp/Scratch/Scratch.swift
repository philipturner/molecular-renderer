// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let logicHousing = LogicHousing()
  return logicHousing.topology.atoms
}

// A tileable piece of housing for a logic array.
// - Spans 2x2 cells
// - Connects to other pieces with vdW forces
// - Option to remove geometry for connecting to other pieces.
struct LogicHousing {
  var topology = Topology()
  
  init() {
    createLattice()
    passivateSurfaces()
  }
  
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 6 * h + 3 * k + 6 * l }
      Material { .elemental(.carbon) }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func passivateSurfaces() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
}
