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

#if true

// Simulated one half of a revolution:
//
// 10 GHz - 250 frames @ 0.400 ps/frame, 250 seconds compile time on AMD machine
// 3.2 GHz - 250 frames @ 1.25 ps/frame, 560 seconds compile time on AMD machine
//
// Raw experimental data (to be archived in the corresponding Git commits):
//
// 10 GHz - fails to function correctly, connecting rod detaches in +Z direction
// 3.2 GHz (attempt 1)
// - 'almost' flew off, but fully extended the piston. The flywheel lost
//    over half of its angular momentum. Will be giving the connecting
//    rod an initial momentum and retrying.
//    - moment(s) of inertia deviated from the initial values by only ~1%,
//      throughout the simulation: 12099700, 6287238, 6212110 in nm-yg-ps system
//    - frame 0:   -240,000 yg-nm^2/ps along first principal axis
//                      500 yg-nm^2/ps along second principal axis
//                    4,000 yg-nm^2/ps along third principal axis
//    - frame 50:  -134,000 yg-nm^2/ps along first principal axis
//                  -12,000 yg-nm^2/ps along second principal axis
//                   18,000 yg-nm^2/ps along third principal axis
//    - frame 100:  -87,000 yg-nm^2/ps along first principal axis
//                  -54,000 yg-nm^2/ps along second principal axis
//                   30,000 yg-nm^2/ps along third principal axis
//    - frame 150: -108,000 yg-nm^2/ps along first principal axis
//                  -48,000 yg-nm^2/ps along second principal axis
//                      600 yg-nm^2/ps along third principal axis
//    - frame 200:  -14,000 yg-nm^2/ps along first principal axis
//                    3,000 yg-nm^2/ps along second principal axis
//                   17,000 yg-nm^2/ps along third principal axis
//    - frame 232:  -14,000 yg-nm^2/ps along first principal axis
//                   -7,000 yg-nm^2/ps along second principal axis
//                   31,000 yg-nm^2/ps along third principal axis
//    - frame 250:  -56,000 yg-nm^2/ps along first principal axis
//                    3,000 yg-nm^2/ps along second principal axis
//                   15,000 yg-nm^2/ps along third principal axis
func createGeometry() -> [[Entity]] {
  let frames = deserialize(
    path: "/Users/philipturner/Desktop/Simulation.data")
  return frames
}

#else

func createGeometry() -> [[Entity]] {
  // Run a 298-Kelvin molecular dynamics simulation of the drive system.
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
  
  for frameID in 0..<20 {
    print("frame:", frameID)
    
    forceField.simulate(time: 0.040)
    
    updateRigidBodies()
    
    print(driveSystem.flywheel.rigidBody.angularMomentum, driveSystem.flywheel.rigidBody.momentOfInertia, driveSystem.flywheel.rigidBody.angularMomentum / driveSystem.flywheel.rigidBody.momentOfInertia)
    
    frames.append(createFrame())
  }
  
  serialize(frames: frames, path: "/Users/philipturner/Desktop/Simulation.data")
  return frames
}

#endif

func serialize(frames: [[Entity]], path: String) {
  let frameCount = frames.count
  let atomCount = frames[0].count
  for frame in frames {
    if frame.count != atomCount {
      fatalError("Frames do not have the same atom count.")
    }
  }
  
  let rawDataPointer: UnsafeMutablePointer<SIMD4<Float>> =
    .allocate(capacity: 1 + frameCount * atomCount)
  
  // Encode the header.
  rawDataPointer[0] = SIMD4(Float(frameCount), Float(atomCount), 0, 0)
  
  // Encode the frames.
  var cursor: Int = 1
  for frame in frames {
    for atom in frame {
      let storage = atom.storage
      rawDataPointer[cursor] = storage
      cursor += 1
    }
  }
  
  let data = Data(
    bytes: rawDataPointer, count: 16 * (1 + frameCount * atomCount))
  rawDataPointer.deallocate()
  
  let url = URL(filePath: path)
  try! data.write(to: url, options: .atomic)
}

func deserialize(path: String) -> [[Entity]] {
  let url = URL(filePath: path)
  let data = try! Data(contentsOf: url)
  guard data.count % 16 == 0 else {
    fatalError("Data is not aligned properly.")
  }
  
  let rawDataPointer: UnsafeMutableBufferPointer<SIMD4<Float>> =
    .allocate(capacity: data.count / 16)
  let copiedByteCount = data.copyBytes(to: rawDataPointer)
  guard copiedByteCount == data.count else {
    fatalError("Did not copy all of the bytes.")
  }
  
  // Decode the header.
  let frameCount = Int(rawDataPointer[0].x)
  let atomCount = Int(rawDataPointer[0].y)
  
  // Decode the frames.
  var cursor: Int = 1
  var frames: [[Entity]] = []
  for frameID in 0..<frameCount {
    var frame: [Entity] = []
    for atomID in 0..<atomCount {
      let storage = rawDataPointer[cursor]
      let atom = Entity(storage: storage)
      frame.append(atom)
      cursor += 1
    }
    frames.append(frame)
  }
  rawDataPointer.deallocate()
  
  return frames
}
