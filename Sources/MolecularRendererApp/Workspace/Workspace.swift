import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Modify the shape of the drive wall. It must move the rods by 1 nm over the
  // clock cycle, while keeping them positionally constrained.
  let lattice = DriveWall.createLattice()
  return lattice.atoms
  
//  driveWall.rigidBody.centerOfMass.x -= 5.0
//
//  // Render the scene.
//  var output: [MM4RigidBody] = []
//  output.append(driveWall.rigidBody)
//  for indexX in 0..<3 {
//    for indexY in 0..<3 {
//      var rigidBody = rod.rigidBody
//      rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
//      
//      let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
//      rigidBody.centerOfMass.z += Double(indexX) * 5.75 * latticeConstant
//      rigidBody.centerOfMass.y += Double(indexY) * 6 * latticeConstant
//      output.append(rigidBody)
//    }
//  }
//  return output
}

// MARK: - Parts

struct Rod {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
  }
  
  // Compiles the carbon centers.
  static func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 30 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Concave {
          Origin { 1 * h2k }
          Plane { h2k }
          
          Origin { 1 * h }
          Plane { k - h }
        }
        Replace { .empty }
      }
    }
  }
  
  // Transforms the lattice into a sorted, passivated topology.
  static func createTopology(lattice: Lattice<Hexagonal>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
    reconstruction.topology.sort()
    return reconstruction.topology
  }
  
  // Creates a rigid body, with all atoms having nonzero mass, and with
  // parameters for bonded forces.
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc =  MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}

struct DriveWall {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
  }
  
  // Compiles the carbon centers.
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 19 * k + 18 * l }
      Material { .elemental(.carbon) }
    }
  }
  
  // Transforms the lattice into a sorted, passivated topology.
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
    reconstruction.topology.sort()
    return reconstruction.topology
  }
  
  // Creates a rigid body, with all atoms having nonzero mass, and with
  // parameters for bonded forces.
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc =  MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}
