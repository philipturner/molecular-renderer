import Foundation
import GIF
import HDL
import MM4
import MolecularRenderer
import QuaternionModule

// MARK: - User-Facing Options

let renderingOffline: Bool = true

// The simulation time per frame, in picoseconds. Frames are recorded and
// nominally played back at 60 FPS.
let frameSimulationTime: Double = 30.0 / 60
let frameCount: Int = 60 * 5

// Users will see a 20 FPS version with the same pacing as the 60 FPS
// version prepared for the YouTube video. The file is still encoded as
// 0.05 s per frame, regardless of the skip rate.
let gifFrameSkipRate: Int = 3

// MARK: - Compile Structure

func passivate(topology: inout Topology) {
  func createHydrogen(
    atomID: UInt32,
    orbital: SIMD3<Float>
  ) -> Atom {
    let atom = topology.atoms[Int(atomID)]
    
    var bondLength = atom.element.covalentRadius
    bondLength += Element.hydrogen.covalentRadius
    
    let position = atom.position + bondLength * orbital
    return Atom(position: position, element: .hydrogen)
  }
  
  let orbitalLists = topology.nonbondingOrbitals()
  
  var insertedAtoms: [Atom] = []
  var insertedBonds: [SIMD2<UInt32>] = []
  for atomID in topology.atoms.indices {
    let orbitalList = orbitalLists[atomID]
    for orbital in orbitalList {
      let hydrogen = createHydrogen(
        atomID: UInt32(atomID),
        orbital: orbital)
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      insertedAtoms.append(hydrogen)
      
      let bond = SIMD2(
        UInt32(atomID),
        UInt32(hydrogenID))
      insertedBonds.append(bond)
    }
  }
  topology.atoms += insertedAtoms
  topology.bonds += insertedBonds
}

func analyze(topology: Topology) {
  print()
  print("atom count:", topology.atoms.count)
  do {
    var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    for atom in topology.atoms {
      let position = atom.position
      minimum.replace(with: position, where: position .< minimum)
      maximum.replace(with: position, where: position .> maximum)
    }
    print("minimum:", minimum)
    print("maximum:", maximum)
  }
}

func createTopology() -> Topology {
  let latticeDimensions = SIMD3<Float>(24, 4, 4)
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds {
      latticeDimensions[0] * h +
      latticeDimensions[1] * h2k +
      latticeDimensions[2] * l
    }
    Material { .elemental(.carbon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .elemental(.carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  
  // Establish the three hexagonal lattice constants.
  let latticeConstantH = Constant(.hexagon) { .elemental(.carbon) }
  let latticeConstantL = Constant(.prism) { .elemental(.carbon) }
  let latticeSpacings = SIMD3<Float>(
    latticeConstantH,
    latticeConstantH * Float(3).squareRoot(),
    latticeConstantL)
  
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    
    // Shift the lattice so it's centered in all axes.
    atom.position.x -= latticeSpacings.x * latticeDimensions.x / 2
    atom.position.y -= latticeSpacings.y * latticeDimensions.y / 2
    atom.position.z -= latticeSpacings.z * latticeDimensions.z / 2
    
    topology.atoms[atomID] = atom
  }
  
  return topology
}

let topology = createTopology()
analyze(topology: topology)

// MARK: - Run Simulation

// Create a rigid body to assist in simulation setup.
func createRigidBody(
  topology: Topology
) -> (MM4Parameters, MM4RigidBody) {
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.masses = parameters.atoms.masses
  rigidBodyDesc.positions = topology.atoms.map(\.position)
  let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  
  return (parameters, rigidBody)
}

// Assign the starting position and momentum of rigid body 1.
func placeBody1(base: MM4RigidBody) -> MM4RigidBody {
  let rotation = Quaternion<Double>(
    angle: Double.pi / 180 * 90,
    axis: SIMD3(0, 1, 0))
  
  var output = base
  output.rotate(quaternion: rotation)
  output.centerOfMass += SIMD3<Double>(-3, 1.8, 0)
  
  // 100 m/s in +X direction
  output.linearMomentum = SIMD3<Double>(0.1, 0, 0) * output.mass
  return output
}

// Assign the starting position and momentum of rigid body 2.
func placeBody2(base: MM4RigidBody) -> MM4RigidBody {
  let rotation1 = Quaternion<Double>(
    angle: Double.pi / 180 * 90,
    axis: SIMD3(0, 1, 0))
  let rotation2 = Quaternion<Double>(
    angle: Double.pi / 180 * 90,
    axis: SIMD3(1, 0, 0))
  
  var output = base
  output.rotate(quaternion: rotation1)
  output.rotate(quaternion: rotation2)
  output.centerOfMass += SIMD3<Double>(3, 0, -1.8)
  
  // 100 ms in -X direction
  output.linearMomentum = SIMD3<Double>(-0.1, 0, 0) * output.mass
  return output
}

let (parameters, baseRigidBody) = createRigidBody(topology: topology)
let rigidBody1 = placeBody1(base: baseRigidBody)
let rigidBody2 = placeBody2(base: baseRigidBody)

@MainActor
func createForceField() -> MM4ForceField {
  var forceFieldParameters = MM4Parameters()
  forceFieldParameters.append(contentsOf: parameters)
  forceFieldParameters.append(contentsOf: parameters)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.integrator = .multipleTimeStep
  forceFieldDesc.parameters = forceFieldParameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  
  forceField.positions = rigidBody1.positions + rigidBody2.positions
  forceField.velocities = rigidBody1.velocities + rigidBody2.velocities
  return forceField
}
let forceField = createForceField()

var frames: [[Atom]] = []
@MainActor
func createFrame(positions: [SIMD3<Float>]) -> [Atom] {
  var output: [SIMD4<Float>] = []
  for rigidBodyID in 0..<2 {
    let baseAddress = rigidBodyID * topology.atoms.count
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position = positions[baseAddress + atomID]
      output.append(atom)
    }
  }
  return output
}

// Run a single simulation frame and report rigid body statistics.
for frameID in 1...frameCount {
  forceField.simulate(time: frameSimulationTime)
  
  var rigidBodies: [MM4RigidBody] = []
  for rigidBodyID in 0..<2 {
    var positions: [SIMD3<Float>] = []
    var velocities: [SIMD3<Float>] = []
    
    let baseAddress = rigidBodyID * topology.atoms.count
    for atomID in topology.atoms.indices {
      let position = forceField.positions[baseAddress + atomID]
      let velocity = forceField.velocities[baseAddress + atomID]
      positions.append(position)
      velocities.append(velocity)
    }
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.masses = parameters.atoms.masses
    rigidBodyDesc.positions = positions
    rigidBodyDesc.velocities = velocities
    let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    rigidBodies.append(rigidBody)
  }
  
  let time = Double(frameID) * frameSimulationTime
  print()
  print("t = \(String(format: "%.3f", time)) ps")
  
  for rigidBodyID in 0..<2 {
    let rigidBody = rigidBodies[rigidBodyID]
    print("rigid body \(rigidBodyID):")
    
    let centerOfMass = rigidBody.centerOfMass
    print("- center of mass:", SIMD3<Float>(centerOfMass), "nm")
    
    // nm/ps (km/s) -> m/s
    let linearVelocity = rigidBody.linearMomentum / rigidBody.mass
    let linearVelocityMS = linearVelocity * 1000
    print("- linear velocity:", SIMD3<Float>(linearVelocityMS), "m/s")
    
    // rad/ps -> rad/ns -> GHz
    let angularVelocity = rigidBody.angularMomentum / rigidBody.momentOfInertia
    let angularVelocityRadNs = angularVelocity * 1000
    let frequencyGHz = angularVelocityRadNs / (2 * Double.pi)
    print("- frequency:", SIMD3<Float>(frequencyGHz), "GHz")
  }
  
  let positions = forceField.positions
  let frame = createFrame(positions: positions)
  frames.append(frame)
}

// MARK: - Launch Application

// Input: time in seconds
// Output: atoms
func interpolate(
  frames: [[Atom]],
  time: Float
) -> [Atom] {
  guard frames.count >= 1 else {
    fatalError("Need at least one frame to know size of atom list.")
  }
  
  let multiple60Hz = time * 60
  var lowFrame = Int(multiple60Hz.rounded(.down))
  var highFrame = lowFrame + 1
  var lowInterpolationFactor = Float(highFrame) - multiple60Hz
  var highInterpolationFactor = multiple60Hz - Float(lowFrame)
  
  if lowFrame < -1 {
    fatalError("This should never happen.")
  }
  if lowFrame >= frames.count - 1 {
    lowFrame = frames.count - 1
    highFrame = frames.count - 1
    lowInterpolationFactor = 1
    highInterpolationFactor = 0
  }
  
  var output: [Atom] = []
  for atomID in frames[0].indices {
    let lowAtom = frames[lowFrame][atomID]
    let highAtom = frames[highFrame][atomID]
    
    var position: SIMD3<Float> = .zero
    position += lowAtom.position * lowInterpolationFactor
    position += highAtom.position * highInterpolationFactor
    
    var atom = lowAtom
    atom.position = position
    output.append(atom)
  }
  return output
}

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  if renderingOffline {
    displayDesc.frameBufferSize = SIMD2<Int>(1280, 720)
  } else {
    displayDesc.frameBufferSize = SIMD2<Int>(1440, 810)
  }
  if !renderingOffline {
    displayDesc.monitorID = device.fastestMonitorID
  }
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  if renderingOffline {
    applicationDesc.upscaleFactor = 1
  } else {
    applicationDesc.upscaleFactor = 3
  }
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 64
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

// Set the camera's unchanging position.
do {
  let rotation1 = Quaternion<Float>(
    angle: Float.pi / 180 * 45,
    axis: SIMD3(0, 1, 0))
  let rotation2 = Quaternion<Float>(
    angle: Float.pi / 180 * 20,
    axis: SIMD3(-1, 0, 1) / Float(2).squareRoot())
  
  func transform(_ input: SIMD3<Float>) -> SIMD3<Float> {
    var output = input
    output = rotation1.act(on: output)
    output = rotation2.act(on: output)
    return output
  }
  
  application.camera.basis.0 = transform(SIMD3(1, 0, 0))
  application.camera.basis.1 = transform(SIMD3(0, 1, 0))
  application.camera.basis.2 = transform(SIMD3(0, 0, 1))
  
  application.camera.position = transform(SIMD3(0, 0, 15))
  application.camera.fovAngleVertical = Float.pi / 180 * 30
}

@MainActor
func createTime() -> Float {
  if renderingOffline {
    let elapsedFrames = gifFrameSkipRate * application.frameID
    let frameRate: Int = 60
    let seconds = Float(elapsedFrames) / Float(frameRate)
    return seconds
  } else {
    let elapsedFrames = application.clock.frames
    let frameRate = application.display.frameRate
    let seconds = Float(elapsedFrames) / Float(frameRate)
    return seconds
  }
}

@MainActor
func updateApplication() {
  var time = createTime()
  
  // Give 0.5 seconds of delay before starting.
  time = max(0, time - 0.5)
  
  let atoms = interpolate(frames: frames, time: time)
  for atomID in atoms.indices {
    let atom = atoms[atomID]
    application.atoms[atomID] = atom
  }
}

// Enter the run loop.
if !renderingOffline {
  application.run {
    updateApplication()
    
    var image = application.render()
    image = application.upscale(image: image)
    application.present(image: image)
  }
} else {
  let frameBufferSize = application.display.frameBufferSize
  var gif = GIF(
    width: frameBufferSize[0],
    height: frameBufferSize[1])
  
  // Overall latency summary for offline mode:
  //
  // throughput @ 1440x1080, 60 FPS
  // macOS: 22.8 minutes / minute of content
  // Windows: 31.3 minutes / minute of content
  //
  // throughput @ 1280x720, 60 FPS
  // macOS: 13.5 minutes / minute of content
  // Windows: 18.5 minutes / minute of content
  //
  // Costs are probably agnostic to level of detail in the scene. On macOS, the
  // encoding latency was identical for an accidentally 100% black image.
  print("rendering frames")
  for _ in 0..<(frameCount / gifFrameSkipRate) {
    let loopStartCheckpoint = Date()
    updateApplication()
    
    // GPU-side bottleneck
    // throughput @ 1440x1080, 64 AO samples
    // macOS: 14-18 ms/frame
    // Windows: 50-70 ms/frame
    let image = application.render()
    
    // single-threaded bottleneck
    // throughput @ 1440x1080
    // macOS: 5 ms/frame
    // Windows: 47 ms/frame
    var bufferedImage = BufferedImage(
      width: frameBufferSize[0],
      height: frameBufferSize[1])
    for y in 0..<frameBufferSize[1] {
      for x in 0..<frameBufferSize[0] {
        let address = y * frameBufferSize[0] + x
        
        // Leaving this in the original SIMD4<Float16> causes a CPU-side
        // bottleneck on Windows.
        let pixel = SIMD4<Float>(image.pixels[address])
        
        // Don't clamp to [0, 255] range to avoid a minor CPU-side bottleneck.
        // It theoretically should never go outside this range; we just lose
        // the ability to assert this.
        let scaled = pixel * 255
        
        // On the Windows machine, '.toNearestOrEven' causes a massive
        // CPU-side bottleneck.
        let rounded = (scaled + 0.5).rounded(.down)
        
        // Avoid massive CPU-side bottleneck for unknown reason when casting
        // floating point vector to integer vector.
        let r = UInt8(rounded[0])
        let g = UInt8(rounded[1])
        let b = UInt8(rounded[2])
        
        let color = Color(
          red: r,
          green: g,
          blue: b)
        
        bufferedImage[y, x] = color
      }
    }
    
    // single-threaded bottleneck
    // throughput @ 1440x1080
    // macOS: 76 ms/frame
    // Windows: 271 ms/frame
    let quantization = OctreeQuantization(fromImage: bufferedImage)
    
    let frame = Frame(
      image: bufferedImage,
      delayTime: 5, // 20 FPS
      localQuantization: quantization)
    gif.frames.append(frame)
    
    let loopEndCheckpoint = Date()
    print(loopEndCheckpoint.timeIntervalSince(loopStartCheckpoint))
  }
  
  // multi-threaded bottleneck
  // throughput @ 1440x1080
  // macOS: 252 ms/frame
  // Windows: 174 ms/frame (abnormally fast compared to macOS)
  print("encoding GIF")
  let encodeStartCheckpoint = Date()
  let data = try! gif.encoded()
  let encodeEndCheckpoint = Date()
  
  let encodedSizeRepr = String(format: "%.1f", Float(data.count) / 1e6)
  print("encoded size:", encodedSizeRepr, "MB")
  print(encodeEndCheckpoint.timeIntervalSince(encodeStartCheckpoint))
  
  // SSD access bottleneck
  //
  // latency @ 1440x1080, 10 frames, 2.1 MB
  // macOS: 1.6 ms
  // Windows: 16.3 ms
  //
  // latency @ 1440x1080, 60 frames, 12.4 MB
  // macOS: 4.1 ms
  // Windows: 57.7 ms
  //
  // Order of magnitude, 1 minute of video is 1 GB of GIF.
  let packagePath = FileManager.default.currentDirectoryPath
  let filePath = "\(packagePath)/.build/video.gif"
  let succeeded = FileManager.default.createFile(
    atPath: filePath,
    contents: data)
  guard succeeded else {
    fatalError("Could not write to file.")
  }
}
