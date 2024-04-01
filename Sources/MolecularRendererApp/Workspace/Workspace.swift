import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let lattice = Flywheel.createLattice()
  let topology = Flywheel.createTopology(lattice: lattice)
  return topology.atoms
}
