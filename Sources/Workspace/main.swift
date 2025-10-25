import Foundation
import GIF
import HDL
import MM4
import MolecularRenderer
import QuaternionModule

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
  let angleDegrees: Double = 90
  let rotation = Quaternion<Double>(
    angle: Double.pi / 180 * 90,
    axis: SIMD3(0, 1, 0))
  
  var output = base
  output.rotate(quaternion: rotation)
  output.centerOfMass += SIMD3<Double>(-1, 0, 0)
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
  output.centerOfMass += SIMD3<Double>(1, 0, 0)
  return output
}

let (parameters, baseRigidBody) = createRigidBody(topology: topology)
let rigidBody1 = placeBody1(base: baseRigidBody)
let rigidBody2 = placeBody2(base: baseRigidBody)

// MARK: - Launch Application

let renderingOffline: Bool = false

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

// Write the first rigid body.
do {
  let baseAddress: Int = 0
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    atom.position = rigidBody1.positions[atomID]
    application.atoms[baseAddress + atomID] = atom
  }
}

// Write the second rigid body.
do {
  let baseAddress: Int = topology.atoms.count
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    atom.position = rigidBody2.positions[atomID]
    application.atoms[baseAddress + atomID] = atom
  }
}

// Set the camera's unchanging position.
do {
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * 0,
    axis: SIMD3(0, 1, 0))
  application.camera.basis.0 = rotation.act(on: SIMD3(1, 0, 0))
  application.camera.basis.1 = rotation.act(on: SIMD3(0, 1, 0))
  application.camera.basis.2 = rotation.act(on: SIMD3(0, 0, 1))
  
  application.camera.position = rotation.act(on: SIMD3(0, 0, 10))
}

application.run {
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}

#if false
// Enter the run loop.
if !renderingOffline {
  application.run {
    modifyAtoms()
    modifyCamera()
    
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
  for _ in 0..<10 {
    let loopStartCheckpoint = Date()
    modifyAtoms()
    modifyCamera()
    
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
#endif
