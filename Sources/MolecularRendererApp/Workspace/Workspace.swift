import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[MM4RigidBody]] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 9 * k + 25 * l }
    Material { .elemental(.carbon) }
    
    for indexX in 0..<4 {
      Volume {
        Concave {
          Origin { Float(indexX) * 5.75 * l }
          Origin { 1.5 * k + 1.5 * l }
          
          // Create a groove for the rod.
          Concave {
            Plane { k }
            Plane { l }
            Origin { 6.25 * k + 4 * l }
            Plane { -k }
            Plane { -l }
          }
          
          // Create a 45-degree inclined plane.
          Concave {
            Origin { 2 * h }
            Plane { h - k }
          }
        }
        
        Replace { .empty }
      }
    }
  }
  
  var reconstruction = SurfaceReconstruction()
  reconstruction.material = .elemental(.carbon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  let topology = reconstruction.topology
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let rigidBodyParameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.parameters = rigidBodyParameters
  rigidBodyDesc.positions = topology.atoms.map(\.position)
  var rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = rigidBody.parameters
  var forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = rigidBody.positions
  forceField.minimize()
  
  rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.parameters = rigidBody.parameters
  rigidBodyDesc.positions = forceField.positions
  rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  
  var rigidBody2 = rigidBody
  rigidBody2.centerOfMass.x += 10
  rigidBody2.rotate(angle: .pi, axis: [0, 1, 0])
  rigidBody2.rotate(angle: .pi / 3, axis: [1, 0, 0])
  rigidBody2.centerOfMass.z -= 2
  rigidBody2.linearMomentum = rigidBody2.mass * SIMD3(-1, 0, 0)
  
  var rigidBody3 = rigidBody
  rigidBody3.centerOfMass.x -= 8
  rigidBody3.angularMomentum = rigidBody3.momentOfInertia * SIMD3(0, 0.25, 0)
  
  // Simulate a collision between the two objects, then commit to GitHub and
  // erase the code here.
  var forceFieldParameters = rigidBody.parameters
  forceFieldParameters.append(contentsOf: rigidBody2.parameters)
  forceFieldParameters.append(contentsOf: rigidBody3.parameters)
  
  forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = forceFieldParameters
  forceFieldDesc.integrator = .multipleTimeStep
  forceFieldDesc.cutoffDistance = 1
  forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = rigidBody.positions + rigidBody2.positions + rigidBody3.positions
  forceField.velocities = rigidBody.velocities + rigidBody2.velocities + rigidBody3.velocities
  
  var frames: [[MM4RigidBody]] = []
  frames.append([rigidBody, rigidBody2, rigidBody3])
  print("frame: 0")
  for frameID in 0..<720 {
    forceField.simulate(time: 0.040)
    print("frame:", frameID + 1)
    
    var cursor: Int = .zero
    func updateRigidBody(_ rigidBody: inout MM4RigidBody) {
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = Array(forceField.positions[
        cursor..<(cursor + rigidBody.parameters.atoms.count)])
      rigidBodyDesc.velocities = Array(forceField.velocities[
        cursor..<(cursor + rigidBody.parameters.atoms.count)])
      cursor += rigidBody.parameters.atoms.count
      
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    
    updateRigidBody(&rigidBody)
    updateRigidBody(&rigidBody2)
    updateRigidBody(&rigidBody3)
    frames.append([rigidBody, rigidBody2, rigidBody3])
  }
  
  return frames
}
