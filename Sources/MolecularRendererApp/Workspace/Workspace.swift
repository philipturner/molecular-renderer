import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Task:
// - Design a revised system using polygonal bearings. Etch out a circular mask
//   using the compiler. Cap the knobs to prevent part separation at 2 GHz.
// - Use hexagonal diamond, which doesn't have as many warping issues. The
//   bearing surfaces will also be more predictable and easier to control.
//   - Try both cubic and hexagonal, see which one is more workable for the
//     design of a single rotary bearing. Measure the friction and whether it
//     can last for 3 cycles at 2-4 GHz.

func createGeometry() -> [MM4RigidBody] {
  let cylinder = Cylinder()
  return [cylinder.rigidBody]
}

struct Cylinder {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
    rigidBody.centerOfMass.x = .zero
    rigidBody.centerOfMass.y = .zero
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 10 * k + 10 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 5 * h + 5 * k }
        
        for thetaDegrees in 0..<180 {
          let angle = Float(2 * thetaDegrees) * .pi / 180
          let direction = SIMD3(Float.cos(angle), Float.sin(angle), 0)
          
          Convex {
            Origin { 5 * direction }
            Plane { direction }
          }
        }
        
        Replace { .empty }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
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
    forceField.minimize()
    
    for atomID in topology.atoms.indices {
      let position = forceField.positions[atomID]
      topology.atoms[atomID].position = position
    }
    return topology
  }
  
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}
