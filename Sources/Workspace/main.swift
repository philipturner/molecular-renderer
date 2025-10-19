import Foundation
import HDL
import MolecularRenderer
import QuaternionModule

// Remaining tasks of this PR:
// - Implement the change to memory organization and validate that the
//   benchmarks for the "original algorithm" haven't changed.
// - Implement 8 nm scoped primary ray intersector from main-branch-backup.
//   - Start off with 2 nm scoped. Ensure correctness and gather perf data.
//   - Then, implement the 8 nm skipping optimization.
//   - Try 32 nm skipping by writing to a simple buffer during RebuildProcess1
//     of the current implementation.
// - Implement the "critical pixel count" heuristic to optimize AO cost.
// - Implement 32 nm scoping to further optimize the per-dense-voxel cost.

#if false

// MARK: - Compile Structure

// Use these parameters to guarantee correct functioning of the 2 nm scoped
// primary ray intersector.
let latticeSizeXY: Float = 64
let latticeSizeZ: Float = 2
let screenDimension: Int = 1440
let worldDimension: Float = 64
do {
  let latticeConstant = Constant(.square) {
    .elemental(.silicon)
  }
  
  // The lattice is not rotating; the camera is. No need to increase this
  // by a factor of sqrt(2).
  let latticeSpan = latticeSizeXY * latticeConstant
  guard latticeSpan < 0.9 * worldDimension else {
    fatalError("Lattice was too large for the world.")
  }
}

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

func createTopology() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds {
      latticeSizeXY * h +
      latticeSizeXY * k +
      latticeSizeZ * l
    }
    Material { .elemental(.silicon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .elemental(.silicon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  
  // Shift the lattice so it's centered in XY and flush with Z = 0.
  let latticeConstant = Constant(.square) {
    .elemental(.silicon)
  }
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    atom.position.x -= (latticeSizeXY / 2) * latticeConstant
    atom.position.y -= (latticeSizeXY / 2) * latticeConstant
    atom.position.z -= latticeSizeZ * latticeConstant
    topology.atoms[atomID] = atom
  }
  
  return topology
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

let topology = createTopology()
analyze(topology: topology)

// MARK: - Test for bugs from mishandling different axes

enum Direction {
  case positiveX
  case positiveY
  case positiveZ
  case negativeX
  case negativeY
  case negativeZ
  
  // This one will also reverse the polarity of X and Y axes.
  case negativeZInverse
  
  // Transform that moves positive Z to the desired direction.
  var rotation: Quaternion<Float> {
    switch self {
    case .positiveX:
      return Quaternion<Float>(
        angle: Float.pi / 2,
        axis: SIMD3(0, 1, 0))
    case .positiveY:
      return Quaternion<Float>(
        angle: -Float.pi / 2,
        axis: SIMD3(1, 0, 0))
    case .positiveZ:
      return Quaternion<Float>(
        angle: 0,
        axis: SIMD3(0, 1, 0))
    case .negativeX:
      return Quaternion<Float>(
        angle: -Float.pi / 2,
        axis: SIMD3(0, 1, 0))
    case .negativeY:
      return Quaternion<Float>(
        angle: Float.pi / 2,
        axis: SIMD3(1, 0, 0))
    case .negativeZ:
      return Quaternion<Float>(
        angle: Float.pi,
        axis: SIMD3(0, 1, 0))
    case .negativeZInverse:
      return Quaternion<Float>(
        angle: Float.pi,
        axis: SIMD3(1, 0, 0))
    }
  }
}
let direction: Direction = .positiveZ

// MARK: - Launch Application

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  displayDesc.frameBufferSize = SIMD2<Int>(repeating: screenDimension)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 3
  
  // Large test: on GTX 970, massive slowdown for BVH construction on GPU side.
  // ~50 ms latency, O(1), probably from running out of memory and paging to
  // something slower. Surprisingly does not show up as abnormally bad
  // performance in rendering latency.
  //
  // Confirmed that in the Windows 10 Task Manager, "Dedicated GPU memory usage"
  // is going very close to 4 GB at the point where it breaks down. In one case,
  // it broke down at addressSpaceSize = 6_000_000 and voxelAllocationSize =
  // 2_350_000_000 to 2_400_000_000. However, a variety of factors could shift
  // the breaking point for voxel allocation size.
  if latticeSizeXY <= 384 {
    applicationDesc.addressSpaceSize = 4_000_000
    applicationDesc.voxelAllocationSize = 1_500_000_000
  } else {
    applicationDesc.addressSpaceSize = 6_000_000
    applicationDesc.voxelAllocationSize = 2_500_000_000
  }
  applicationDesc.worldDimension = worldDimension
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

@MainActor
func createTime() -> Float {
  let elapsedFrames = application.clock.frames
  let frameRate = application.display.frameRate
  let seconds = Float(elapsedFrames) / Float(frameRate)
  return seconds
}

@MainActor
func modifyCamera() {
  let latticeConstant = Constant(.square) {
    .elemental(.silicon)
  }
  
  func createPosition() -> SIMD3<Float> {
    // WARNING: Restore the correct expression here.
    //
    // latticeSizeXY / 2 for debugging correctness
    // latticeSizeXY / 3 for benchmark
    var output = SIMD3<Float>(
    0.001,
    0.002,
    (latticeSizeXY / 3) * latticeConstant)
    output = direction.rotation.act(on: output)
    return output
  }
  application.camera.position = createPosition()
  if application.frameID == 0 {
    print(application.camera.position)
  }
  
  let time = createTime()
  let angleDegrees = 0.1 * time * 360
  let animationRotation = Quaternion<Float>(
    angle: Float.pi / 180 * -angleDegrees,
    axis: SIMD3(0, 0, 1))
  
  func transform(_ axis: SIMD3<Float>) -> SIMD3<Float> {
    var output = axis
    output = animationRotation.act(on: output)
    output = direction.rotation.act(on: output)
    return output
  }
  application.camera.basis.0 = transform(SIMD3(1, 0, 0))
  application.camera.basis.1 = transform(SIMD3(0, 1, 0))
  application.camera.basis.2 = transform(SIMD3(0, 0, 1))
  
  application.camera.fovAngleVertical = Float.pi / 180 * 90
  application.camera.secondaryRayCount = nil
}

@MainActor
func modifyAtoms() {
  let start = Date()
  
  var startIndex = application.frameID * 300_000
  var endIndex = startIndex + 300_000
  startIndex = min(startIndex, topology.atoms.count)
  endIndex = min(endIndex, topology.atoms.count)
  guard endIndex <= application.atoms.addressSpaceSize else {
    fatalError("Exceeded address space size.")
  }
  
  let rotation = direction.rotation
  let basis0 = rotation.act(on: SIMD3(1, 0, 0))
  let basis1 = rotation.act(on: SIMD3(0, 1, 0))
  let basis2 = rotation.act(on: SIMD3(0, 0, 1))
  
  for atomID in startIndex..<endIndex {
    var atom = topology.atoms[atomID]
    
    var position: SIMD3<Float> = .zero
    position += basis0 * atom.position[0]
    position += basis1 * atom.position[1]
    position += basis2 * atom.position[2]
    
    atom.position = position
    application.atoms[atomID] = atom
  }
  
  let end = Date()
  
  // Check for no catastrophic CPU-side bottlenecks. Should not be above
  // 10 ns/atom on any platform.
  if startIndex < endIndex {
    let latency = end.timeIntervalSince(start)
    let atomCount = endIndex - startIndex
    let nsPerAtom = Double(1e9) * latency / Double(atomCount)
    let nsPerAtomRepr = String(format: "%.3f", nsPerAtom)
    print(nsPerAtomRepr)
  }
}

application.run {
  #if true
  modifyCamera()
  modifyAtoms()
  #endif
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}

#endif



// Double checking correct execution of the code.

#if true

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

func createTopology() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * (h + k + l) }
    Material { .checkerboard(.carbon, .silicon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  return topology
}
let topology = createTopology()

func createRotationCenter() -> SIMD3<Float> {
  let latticeConstant = Constant(.square) {
    .checkerboard(.silicon, .carbon)
  }
  let halfSize = latticeConstant * 5
  return SIMD3<Float>(repeating: halfSize)
}

// MARK: - Launch Application

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  displayDesc.frameBufferSize = SIMD2<Int>(1080, 1080)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 3
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 32
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

@MainActor
func createTime() -> Float {
  let elapsedFrames = application.clock.frames
  let frameRate = application.display.frameRate
  let seconds = Float(elapsedFrames) / Float(frameRate)
  return seconds
}

@MainActor
func modifyAtoms() {
  // 0.2 Hz rotation rate
  let time = createTime()
  let angleDegrees = 0.2 * time * 360
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * angleDegrees,
    axis: SIMD3(0, 1, 0))
  
  // Circumvent a massive CPU-side bottleneck from 'rotation.act()'.
  let basis0 = rotation.act(on: SIMD3<Float>(1, 0, 0))
  let basis1 = rotation.act(on: SIMD3<Float>(0, 1, 0))
  let basis2 = rotation.act(on: SIMD3<Float>(0, 0, 1))
  
  let rotationCenter = createRotationCenter()
  
  // Circumvent a massive CPU-side bottleneck from @MainActor referencing to
  // things from the global scope.
  let topologyCopy = topology
  let applicationCopy = application
  
  for atomID in topology.atoms.indices {
    var atom = topologyCopy.atoms[atomID]
    let originalDelta = atom.position - rotationCenter
    
    var rotatedDelta: SIMD3<Float> = .zero
    rotatedDelta += basis0 * originalDelta[0]
    rotatedDelta += basis1 * originalDelta[1]
    rotatedDelta += basis2 * originalDelta[2]
    
    atom.position = rotationCenter + rotatedDelta
    applicationCopy.atoms[atomID] = atom
  }
}

@MainActor
func modifyCamera() {
  // 0.04 Hz rotation rate
  let time = createTime()
  let angleDegrees = 0.04 * time * 360
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * angleDegrees,
    axis: SIMD3(-1, 0, 0))
  
  application.camera.basis.0 = rotation.act(on: SIMD3(1, 0, 0))
  application.camera.basis.1 = rotation.act(on: SIMD3(0, 1, 0))
  application.camera.basis.2 = rotation.act(on: SIMD3(0, 0, 1))
  application.camera.fovAngleVertical = Float.pi / 180 * 60
  
  let latticeConstant = Constant(.square) {
    .checkerboard(.silicon, .carbon)
  }
  let halfSize = latticeConstant * 5
  
  // Test both 3 * halfSize and 10 * halfSize.
  var cameraDelta = SIMD3<Float>(0, 0, 3 * halfSize)
  cameraDelta = rotation.act(on: cameraDelta)
  
  let rotationCenter = createRotationCenter()
  application.camera.position = rotationCenter + cameraDelta
}

application.run {
  modifyAtoms()
  modifyCamera()
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}

#endif
