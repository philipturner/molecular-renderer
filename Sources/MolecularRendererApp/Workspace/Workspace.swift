import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * h + 10 * h2k + 5 * l }
    Material { .checkerboard(.silicon, .carbon) }
  }
  
  // MARK: - Compile and minimize a lattice.
  
  var reconstruction = Reconstruction()
  reconstruction.material = .checkerboard(.silicon, .carbon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  var topology = reconstruction.topology
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  
  // Before the change:
  //
  // -550953.9609375
  // -550953.953125
  // -550953.9453125
  // -550953.9453125
  // -550953.9609375
  // -550953.96875
  // -550953.96875
  // -550953.953125
  // -550953.9453125
  // -550953.953125
  print(forceField.energy.potential)
  
  forceField.minimize()
  
  // Before the change:
  //
  // -559768.0703125
  // -559768.078125
  // -559768.3828125
  // -559768.375
  // -559768.3828125
  // -559768.3671875
  // -559768.375
  // -559768.3671875
  // -559768.390625
  // -559768.3828125
  print(forceField.energy.potential)
  
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    let position = forceField.positions[atomID]
    atom.position = position
    topology.atoms[atomID] = atom
  }
  
  return topology.atoms
}
