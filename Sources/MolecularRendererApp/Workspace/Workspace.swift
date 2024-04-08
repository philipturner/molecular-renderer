import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Test that the drive system actually works with MD before doing anything
// else. It doesn't have to be serialized to the disk yet. You might gain some
// insights from serializing the minimized structures for other things in the
// scene.

// TODO: Fire up the old AFM probe embedded into the hardware catalog and/or
// the HDL unit tests. Design a good tooltip and set up a scripting environment
// for tripod build sequences.
// - Silicon probe, but (H3C)3-Ge* tooltip.
// - Create a build sequence compiler using the known set of reactions, after
//   this environment is set up. Pretend the germanium atoms are actually C.
// - 8885 atoms, estimated 50,000 tripods

func createGeometry() -> [[Entity]] {
  // Run a zero-Kelvin molecular dynamics simulation of the drive system.
  var driveSystem = DriveSystem()
  driveSystem.connectingRod.minimize()
  driveSystem.flywheel.minimize()
  
  var forceFieldParameters = driveSystem.connectingRod.rigidBody.parameters
  forceFieldParameters.append(
    contentsOf: driveSystem.flywheel.rigidBody.parameters)
  forceFieldParameters.append(
    contentsOf: driveSystem.housing.rigidBody.parameters)
  forceFieldParameters.append(
    contentsOf: driveSystem.piston.rigidBody.parameters)
  
  
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.integrator = .multipleTimeStep
  forceFieldDesc.parameters = forceFieldParameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  
  func updateRigidBodies() {
    var atomCursor: Int = .zero
    func update(rigidBody: inout MM4RigidBody) {
      let nextAtomCursor = atomCursor + rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      atomCursor = nextAtomCursor
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = Array(forceField.positions[atomRange])
      rigidBodyDesc.velocities = Array(forceField.velocities[atomRange])
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    update(rigidBody: &driveSystem.connectingRod.rigidBody)
    update(rigidBody: &driveSystem.flywheel.rigidBody)
    update(rigidBody: &driveSystem.housing.rigidBody)
    update(rigidBody: &driveSystem.piston.rigidBody)
  }
  
  func createFrame() -> [Entity] {
    var frame: [Entity] = []
    for atomID in forceFieldParameters.atoms.indices {
      let atomicNumber = forceFieldParameters.atoms.atomicNumbers[atomID]
      let position = forceField.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let entity = Entity(storage: storage)
      frame.append(entity)
    }
    return frame
  }
  
  func createForceFieldPositions() -> [SIMD3<Float>] {
    var forceFieldPositions = driveSystem.connectingRod.rigidBody.positions
    forceFieldPositions += driveSystem.flywheel.rigidBody.positions
    forceFieldPositions += driveSystem.housing.rigidBody.positions
    forceFieldPositions += driveSystem.piston.rigidBody.positions
    return forceFieldPositions
  }
  
  func createForceFieldVelocities() -> [SIMD3<Float>] {
    var forceFieldVelocities = driveSystem.connectingRod.rigidBody.velocities
    forceFieldVelocities += driveSystem.flywheel.rigidBody.velocities
    forceFieldVelocities += driveSystem.housing.rigidBody.velocities
    forceFieldVelocities += driveSystem.piston.rigidBody.velocities
    return forceFieldVelocities
  }
  
  // MARK: - Scripting
  
  print("started minimizing")
  
  // Minimize the positions.
  forceField.positions = createForceFieldPositions()
  forceField.minimize(tolerance: 10)
  updateRigidBodies()
  
  print("finished minimizing")
  
  // Set the velocities to thermal velocities at 298 K.
  driveSystem.setVelocitiesToTemperature(2 * 298)
  
  // Set the angular momentum of the flywheel.
  do {
    var rigidBody = driveSystem.flywheel.rigidBody
    
    // 0.001 * (2π) rad/ps
    // 2π rad/ns, 1 revolution/ns
    let gigahertz: Double = 0.001 * (2 * .pi)
    
    // 10 GHz
    let angularVelocity: Double = 10 * gigahertz
    let angularMomentum = angularVelocity * rigidBody.momentOfInertia[0]
    
    // clockwise direction
    guard rigidBody.principalAxes.0.z > 0 else {
      fatalError("Angular momentum will not be clockwise.")
    }
    rigidBody.angularMomentum = SIMD3(-angularMomentum, 0, 0)
    
    driveSystem.flywheel.rigidBody = rigidBody
  }
  
  // Finalize the velocities.
  forceField.velocities = createForceFieldVelocities()
  
  // Start creating frames.
  var frames = [createFrame()]
  
  for frameID in 0..<240 {
    print("frame:", frameID)
    
    forceField.simulate(time: 0.040)
    
    updateRigidBodies()
    
    print(driveSystem.flywheel.rigidBody.angularMomentum, driveSystem.flywheel.rigidBody.momentOfInertia, driveSystem.flywheel.rigidBody.angularMomentum / driveSystem.flywheel.rigidBody.momentOfInertia)
    
    frames.append(createFrame())
  }
  
  return frames
}
