// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// WARNING: The renderer could be in 'MRSceneSize.extreme'. If so, it will not
// render any animations.
func createGeometry() -> [Entity] {
  // TODO: Save the code for this experiment in a GitHub commit, but delete the
  // code instead of archiving it.
  
  // Create the housing.
  let testHousing = TestHousing()
  
  // Instantiate the circuit, then select to part to examine.
  let circuit = Circuit()
  let rod = circuit.propagate.broadcast[SIMD2(0, 1)]!
  let testRod = TestRod(rod: rod)
  
  // Return a static view of the structure.
  var output: [Entity] = []
  output += createAtoms(rigidBody: testHousing.rigidBody)
  output += createAtoms(rigidBody: testRod.rigidBody)
  return output
}

func createAtoms(rigidBody: MM4RigidBody) -> [Entity] {
  var output: [Entity] = []
  for atomID in rigidBody.parameters.atoms.indices {
    let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
    let position = rigidBody.positions[atomID]
    let storage = SIMD4(position, Float(atomicNumber))
    output.append(Entity(storage: storage))
  }
  return output
}

// MARK: - Compiled Structures

struct TestRod {
  var rigidBody: MM4RigidBody
  
  init(rod: Rod) {
    // Create the MM4 parameters.
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = rod.topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = rod.topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    // Create the rigid body and center it.
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = rod.topology.atoms.map(\.position)
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    rigidBody.centerOfMass = .zero
  }
}

struct TestHousing {
  var topology = Topology()
  var rigidBody: MM4RigidBody!
  
  init() {
    createLattice()
    passivate()
    createRigidBody()
  }
  
  // Compiles the lattice of carbon centers.
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 9 * h + 9 * k + 40 * l }
      Material { .elemental(.carbon) }
      
      func fillInCorner(majorAxis: SIMD3<Float>, minorAxis: SIMD3<Float>) {
        Convex {
          Origin { 0.25 * majorAxis + 0.25 * minorAxis }
          Plane { majorAxis + minorAxis }
        }
        Convex {
          Origin { 0.25 * majorAxis + 4.00 * minorAxis }
          Plane { majorAxis - minorAxis }
        }
        Convex {
          Origin { 3.75 * majorAxis + 0.25 * minorAxis }
          Plane { -majorAxis + minorAxis }
        }
        Convex {
          Origin { 3.75 * majorAxis + 4.00 * minorAxis }
          Plane { -majorAxis - minorAxis }
        }
      }
      
      func createHoleZ(offset: SIMD3<Float>) {
        Concave {
          Origin { offset[0] * h + offset[1] * k + offset[2] * l }
          Origin { 1.5 * h + 1.5 * k }
          
          // Create a groove for the rod.
          Concave {
            Plane { h }
            Plane { k }
            Origin { 4 * h + 4.25 * k }
            Plane { -h }
            Plane { -k }
          }
          
          // Fill in some places where the bonding topology is ambiguous.
          fillInCorner(majorAxis: h, minorAxis: k)
        }
      }
      
      Volume {
        createHoleZ(offset: SIMD3(1, 1, 0))
        
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  // Add hydrogens and sort the atoms for efficient simulation.
  mutating func passivate() {
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
  
  // Creates the rigid body and centers it at the origin.
  mutating func createRigidBody() {
    // Create the MM4 parameters.
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    // Create the rigid body and center it.
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    rigidBody.centerOfMass = .zero
  }
}
