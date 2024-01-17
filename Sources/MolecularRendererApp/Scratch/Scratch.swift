// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // In the middle of rewriting this code from scratch. We have some snippets of
  // the previous code left over, for reference.
  
  let material: MaterialType = .elemental(.carbon)
  
  func createRigidBody(_ lattice: Lattice<Cubic>, anchor: Bool) -> MM4RigidBody {
    var topology = Topology()
    topology.insert(atoms: lattice.atoms)
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = material
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
    
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    if anchor {
      for i in parameters.atoms.indices {
        if parameters.atoms.centerTypes[i] == .quaternary {
          parameters.atoms.masses[i] = 0
        }
      }
    }
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
  
  let latticeSize: Int = 10
  let latticeJig = Lattice<Cubic> { h, k, l in
    Bounds { Float(latticeSize + 3) * (h + k + l) }
    Material { material }
    
    Volume {
      Origin { 1 * (h + k + l) }
      Concave {
        Plane { h }
        Plane { k }
        Plane { l }
        Origin { 0.25 * (h + k + l) }
        Plane { h + k }
        Plane { h + l }
        Plane { k + l }
      }
      Replace { .empty }
    }
  }
  
  let jig = createRigidBody(latticeJig, anchor: true)
  
  let latticeSpecimen = Lattice<Cubic> { h, k, l in
    Bounds { Float(latticeSize) * (h + k + l) }
    Material { material }
  }
  
  var specimen = createRigidBody(latticeSpecimen, anchor: false)
  let latticeConstant = Constant(.square) { material }
  specimen.centerOfMass += SIMD3<Double>(
    2.5 * latticeConstant * SIMD3(repeating: 1))
  
  let positions = jig.positions + specimen.positions
  let atomicNumbers =
  jig.parameters.atoms.atomicNumbers +
  specimen.parameters.atoms.atomicNumbers
  
  var output: [Entity] = []
  for (position, atomicNumber) in zip(positions, atomicNumbers) {
    output.append(Entity(storage: SIMD4(position, Float(atomicNumber))))
  }
  return output
}
