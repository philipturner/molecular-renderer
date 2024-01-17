// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
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
  
  let latticeJig = Lattice<Cubic> { h, k, l in
    Bounds { 13 * h + 13 * k + 13 * l }
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
  
  var jig = createRigidBody(latticeJig, anchor: true)
  
  let latticeSpecimen = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 10 * k + 10 * l }
    Material { material }
  }
  
  var specimen = createRigidBody(latticeSpecimen, anchor: false)
  specimen.centerOfMass += SIMD3(repeating: 1)
  
  var parameters = jig.parameters
  parameters.append(contentsOf: specimen.parameters)
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = jig.positions + specimen.positions
  forceField.minimize()
  
  var cursor = 0
  func update(_ rigidBody: inout MM4RigidBody) {
    var descriptor = MM4RigidBodyDescriptor()
    descriptor.parameters = rigidBody.parameters
    descriptor.positions = []
    for _ in rigidBody.parameters.atoms.indices {
      descriptor.positions!.append(forceField.positions[cursor])
      cursor += 1
    }
    rigidBody = try! MM4RigidBody(descriptor: descriptor)
  }
  update(&jig)
  update(&specimen)
  
  var output: [[Entity]] = []
  for trialID in 0..<3 {
    var minimumPotentialEnergy: Double = .greatestFiniteMagnitude
    specimen.linearMomentum = .zero
    specimen.angularMomentum = .zero
    
    for frameID in 0..<240 {
      let potentialEnergy = forceField.energy.potential
      let timeStep: Double = 0.040
      if frameID % 10 == 0 {
        print("frame=\(frameID), time=\(String(format: "%.3f", timeStep * Double(frameID))), potential=\(String(format: "%.3f", Double(potentialEnergy)))")
      }
      
      if potentialEnergy >= minimumPotentialEnergy {
        print("exit_frame=\(frameID)")
        
        // Account for the deformations from surface-surface interactions, which
        // were not modeled by rigid body mechanics.
        if trialID == 2 {
          print("exit_potential=\(forceField.energy.potential)")
          forceField.minimize()
          print("exit_potential=\(forceField.energy.potential)")
        }
      } else {
        // Perform the last trial with MD to maximize accuracy.
        if trialID == 2 {
          forceField.simulate(time: timeStep)
        } else {
          let forces = forceField.forces
          let range = jig.positions.count..<parameters.atoms.count
          specimen.forces = Array(forces[range])
          specimen.linearMomentum += timeStep * specimen.netForce!
          specimen.angularMomentum += timeStep * specimen.netTorque!
          
          let velocity = specimen.linearMomentum / specimen.mass
          let angularVelocity = specimen.angularMomentum / specimen.momentOfInertia
          let angularSpeed = (angularVelocity * angularVelocity).sum().squareRoot()
          specimen.centerOfMass += timeStep * velocity
          specimen.rotate(angle: timeStep * angularSpeed)
          
          forceField.positions = jig.positions + specimen.positions
        }
      }
      
      var frame: [Entity] = []
      for i in parameters.atoms.indices {
        let position = forceField.positions[i]
        let atomicNumber = parameters.atoms.atomicNumbers[i]
        let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
        frame.append(entity)
      }
      output.append(frame)
      
      if potentialEnergy >= minimumPotentialEnergy {
        break
      }
      minimumPotentialEnergy = potentialEnergy
    }
  }
  
  // Compute the minimum-energy position on-the-fly with rigid body mechanics.
  // Cache the minimum-energy CoM for diamond. When you simulate other
  // materials, you'll need to generate their ideal specimen CoM on the fly.
  //
  // TODO: Serialize the system position to base64 as a build product.
  return output
}
