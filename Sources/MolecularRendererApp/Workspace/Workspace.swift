import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  let surface = Surface()
  return surface.topology.atoms
}

// A partially-hydrogenated partially-chlorinated silicon surface, facing
// towards positive Z.
struct Surface {
  var topology: Topology
  
  init() {
    let lattice = Self.createLattice()
    topology = Self.createTopology(lattice: lattice)
    
    let rigidBody = Self.createRigidBody(topology: topology)
    let axesFP64 = rigidBody.principalAxes
    let axesFP32 = (SIMD3<Float>(axesFP64.0),
                    SIMD3<Float>(axesFP64.1),
                    SIMD3<Float>(axesFP64.2))
    let center = SIMD3<Float>(rigidBody.centerOfMass)
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      position -= center
      position = SIMD3(
        (axesFP32.1 * position).sum(),
        (axesFP32.2 * position).sum(),
        (axesFP32.0 * position).sum())
      atom.position = position
      topology.atoms[atomID] = atom
    }
    
    passivate()
  }
  
  mutating func passivate() {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      guard atom.atomicNumber == 1,
            atom.position.z > 1.900 else {
        continue
      }
      if Bool.random() {
        atom.atomicNumber = 17
      }
      
      let currentDistance = 
      Element.silicon.covalentRadius +
      Element.hydrogen.covalentRadius
      var newDistance: Float
      if atom.atomicNumber == 1 {
        newDistance = 1.483 / 10
      } else {
        newDistance = 2.029 / 10
      }
      
      let shift = newDistance - currentDistance
      atom.position.z += shift
      topology.atoms[atomID] = atom
    }
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 100 * (h + k + l) }
      Material { .elemental(.silicon) }
      
      Volume {
        Origin { 50 * (h + k + l) }
        Convex {
          Origin { 2 * (h + k + l) }
          Plane { h + k + l }
        }
        Convex {
          Origin { -2 * (h + k + l) }
          Plane { -(h + k + l) }
        }
        Replace { .empty }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.silicon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
    reconstruction.topology.sort()
    return reconstruction.topology
  }
  
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    paramsDesc.forces = [.nonbonded]
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}
