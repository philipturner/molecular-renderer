import Dispatch
import func Foundation.pow
import struct Foundation.Date
import HDL
import MolecularRenderer
import QuaternionModule

// MARK: - User-Facing Options

let isDenselyPacked: Bool = false
let desiredAtomCount: Int = 141_000_000
let voxelAllocationSize: Int = 20_500_000_000

// Loading speed in parts/frame (107k atoms/part).
//
// Multithreading may have eliminated the CPU-side bottleneck. We are getting
// 2.4 ns/atom for combined 'rotate animation' and 'API usage'. That reduces
// the CPU-side bottleneck from 17.47 ns/atom -> 9.65 nm/atom on the Windows
// machine. Still not enough to make the GPU-side bottleneck dominate.
//
// CPU: 9.55 ns/atom -> 9.55 ms @ 1M atoms
// GPU: 7.33 ns/atom -> 7.33 ms @ 1M atoms
let loadingSpeed: Int = 10
let loadingUsesMultithreading: Bool = true

// Check whether console output for sorted positions falls inside
// [-worldDimension / 2, worldDimension / 2].
let worldDimension: Float = 384

//  60° - good for avoiding moiré patterns
// 110° - good for actually seeing what's going on
//
// Moiré patterns are a little bit less severe on macOS, probably due to the
// use of MetalFX instead of FidelityFX.
let fovAngleDegrees: Float = 60
let screenDimension: Int = 1440

// MARK: - Compile Structure

let latticeSize: Float = 23

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
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { latticeSize * (h + k + l) }
    
    // Invert the atom ordering from previous tests in this repo. Now the
    // silicon atoms are shown on the surface. It's more ugly, but expands the
    // test coverage.
    Material { .checkerboard(.silicon, .carbon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  
  // Shift the structure so it's centered at the origin.
  let latticeConstant = Constant(.square) {
    .checkerboard(.silicon, .carbon)
  }
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    
    let deltaMagnitude = latticeSize * latticeConstant / 2
    atom.position -= SIMD3(repeating: deltaMagnitude)
    
    topology.atoms[atomID] = atom
  }
  
  return topology
}

let topology = createTopology()
analyze(topology: topology)

// MARK: - Scene Construction

// Since the lattice is already centered, we don't have to perform a reduction
// over all the atoms beforehand, just to establish the min/max/center point.
func getRadialExtent(topology: Topology) -> Float {
  var radialExtent: Float = .zero
  for atom in topology.atoms {
    let position = atom.position
    let distance = (position * position).sum().squareRoot()
    radialExtent = max(radialExtent, distance)
  }
  return radialExtent
}
func getCartesianExtent(topology: Topology) -> Float {
  var cartesianExtent: Float = .zero
  for atom in topology.atoms {
    let position = atom.position
    let distance = position[0].magnitude
    cartesianExtent = max(cartesianExtent, distance)
  }
  return cartesianExtent
}

// Add 0.5 nm of padding on both sides of the object, to create the spacing
// between objects.
func getSafeSpacing(
  topology: Topology,
  isDenselyPacked: Bool
) -> Float {
  var extent: Float
  if isDenselyPacked {
    extent = getCartesianExtent(topology: topology)
  } else {
    extent = getRadialExtent(topology: topology)
  }
  extent += 0.5
  
  return 2 * extent
}

// Utility function for creating a random rotational basis, without relying on
// quaternions.
//
// Named 'RotationBasis' to avoid a name conflict with 'Basis' from the HDL
// library and not worry about potential issues.
typealias RotationBasis = (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
func createRandomRotation() -> RotationBasis {
  func createRandomDirection() -> SIMD3<Float> {
    for _ in 0..<100 {
      var output = SIMD3<Float>.random(in: -1...1)
      let length = (output * output).sum().squareRoot()
      if length > 1 || length < 0.001 {
        continue
      }
      
      output /= length
      return output
    }
    fatalError("Algorithm failed to converge.")
  }
  
  func cross(
    _ lhs: SIMD3<Float>,
    _ rhs: SIMD3<Float>
  ) -> SIMD3<Float> {
    let yzx = SIMD3<Int>(1, 2, 0)
    let zxy = SIMD3<Int>(2, 0, 1)
    return (lhs[yzx] * rhs[zxy]) - (lhs[zxy] * rhs[yzx])
  }
  
  let random1 = createRandomDirection()
  let random2 = createRandomDirection()
  
  var cross12 = cross(random1, random2)
  let cross12Length = (cross12 * cross12).sum().squareRoot()
  if cross12Length < 0.001 || cross12Length > 1 {
    fatalError("Could not take cross product.")
  }
  cross12 /= cross12Length
  
  let xAxis = random1
  let yAxis = cross12
  let zAxis = cross(xAxis, yAxis)
  
  return (xAxis, yAxis, zAxis)
}

func rotate(topology: inout Topology, basis: RotationBasis) {
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    
    var rotatedPosition: SIMD3<Float> = .zero
    rotatedPosition += basis.0 * atom.position[0]
    rotatedPosition += basis.1 * atom.position[1]
    rotatedPosition += basis.2 * atom.position[2]
    atom.position = rotatedPosition
    
    topology.atoms[atomID] = atom
  }
}

func createPartPositions(
  spacing: Float,
  partCount: Int
) -> [SIMD3<Float>] {
  // Takes an approximate square root, biasing all calculations to round down.
  func cubeRoot(_ x: Int) -> Int {
    var output = Float(x)
    output = pow(output, Float(1) / 3)
    output = output.rounded(.down)
    
    // We want an even number for a symmetric arrangement about the origin.
    var outputInt = Int(output)
    outputInt = (outputInt / 2) * 2
    return outputInt
  }
  
  // One invocation takes ~30 μs @ 1000 parts.
  func candidateOutput(approximatePartCount: Int) -> [SIMD3<Float>] {
    let cubeSize = cubeRoot(approximatePartCount)
    let lowerCoordBound = -cubeSize / 2
    let upperCoordBound = cubeSize / 2
    
    var output: [SIMD3<Float>] = []
    for z in lowerCoordBound..<upperCoordBound {
      for y in lowerCoordBound..<upperCoordBound {
        for x in lowerCoordBound..<upperCoordBound {
          var coordinates = SIMD3<Float>(
            Float(x),
            Float(y),
            Float(z))
          coordinates += 0.5
          
          // Exclude some parts close to the camera, so the user can see.
          let taxicabDistance =
          coordinates[0].magnitude +
          coordinates[1].magnitude +
          coordinates[2].magnitude
          let plane111Distance = Float(cubeSize / 2)
          guard taxicabDistance > plane111Distance else {
            continue
          }
          
          let position = coordinates * spacing
          output.append(position)
        }
      }
    }
    
    return output
  }
  
  // Find a cube size, iterate until we converge on the desired count.
  var improvedPartCount = partCount
  for i in 0..<30 {
    let candidate = candidateOutput(
      approximatePartCount: improvedPartCount)
    
    let ratio = Float(candidate.count) / Float(partCount)
    print(improvedPartCount, candidate.count, ratio)
    
    if candidate.count >= partCount {
      break
    }
    
    var partCountFloat = Float(improvedPartCount)
    partCountFloat /= ratio
    if i > 10 {
      // Speed up convergence of the algorithm.
      // 1.04^20 = 2.19
      partCountFloat *= 1.04
    }
    partCountFloat.round(.down)
    improvedPartCount = Int(partCountFloat)
  }
  
  var output = candidateOutput(approximatePartCount: improvedPartCount)
  print("improved approximate part count:", improvedPartCount)
  print("after culling interior parts:", output.count)
  guard output.count >= partCount else {
    fatalError("Could not converge.")
  }
  
  output.sort { lhs, rhs in
    let lhsDistanceSquared = (lhs * lhs).sum()
    let rhsDistanceSquared = (rhs * rhs).sum()
    if lhsDistanceSquared >= rhsDistanceSquared {
      return true
    } else {
      return false
    }
  }
  
  guard output.count >= 6 else {
    fatalError("Could not display representation of list.")
  }
  print("first positions after sorting:")
  print("- \(output[0])")
  print("- \(output[1])")
  print("- \(output[2])")
  print("last positions after sorting:")
  print("- \(output[output.count - 3])")
  print("- \(output[output.count - 2])")
  print("- \(output[output.count - 1])")
  
  while output.count > partCount {
    output.removeLast()
  }
  
  guard output.count >= 6 else {
    fatalError("Could not display representation of list.")
  }
  print("last positions after trimming to desired size:")
  print("- \(output[output.count - 3])")
  print("- \(output[output.count - 2])")
  print("- \(output[output.count - 1])")
  
  return output
}

struct SceneDescriptor {
  var isDenselyPacked: Bool?
  
  // WARNING: Use the address space size after initializing the application. It
  // is rounded down from the number entered into the program.
  var targetAtomCount: Int?
  
  // We do not hold a reference / copy of the topology. The original topology in
  // the global scope should remain the source of truth.
  var topology: Topology?
}

struct Scene {
  var partPositions: [SIMD3<Float>]
  var partRotations: [RotationBasis]
  
  init(descriptor: SceneDescriptor) {
    guard let isDenselyPacked = descriptor.isDenselyPacked,
          let targetAtomCount = descriptor.targetAtomCount,
          let topology = descriptor.topology else {
      fatalError("Descriptor was incomplete.")
    }
    
    let partCount = targetAtomCount / topology.atoms.count
    let spacing = getSafeSpacing(
      topology: topology,
      isDenselyPacked: isDenselyPacked)
    self.partPositions = createPartPositions(
      spacing: spacing,
      partCount: partCount)
    
    self.partRotations = []
    for _ in 0..<partCount {
      var basis: RotationBasis
      if isDenselyPacked {
        basis = (
          SIMD3<Float>(1, 0, 0),
          SIMD3<Float>(0, 1, 0),
          SIMD3<Float>(0, 0, 1))
      } else {
        basis = createRandomRotation()
      }
      partRotations.append(basis)
    }
  }
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
  displayDesc.frameBufferSize = SIMD2<Int>(repeating: screenDimension)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 3
  
  applicationDesc.addressSpaceSize = desiredAtomCount
  applicationDesc.voxelAllocationSize = voxelAllocationSize
  applicationDesc.worldDimension = worldDimension
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

var sceneDesc = SceneDescriptor()
sceneDesc.isDenselyPacked = isDenselyPacked
sceneDesc.targetAtomCount = application.atoms.addressSpaceSize
sceneDesc.topology = topology
let scene = Scene(descriptor: sceneDesc)
do {
  let partCount = scene.partPositions.count
  print("part count:", partCount)
  print("achieved atom count:", partCount * topology.atoms.count)
}
print()

guard scene.partPositions.count >= 6 else {
  fatalError("Could not display representation of list.")
}
print("first positions in scene:")
print("- \(scene.partPositions[0])")
print("- \(scene.partPositions[1])")
print("- \(scene.partPositions[2])")
print("last positions in scene:")
print("- \(scene.partPositions[scene.partPositions.count - 3])")
print("- \(scene.partPositions[scene.partPositions.count - 2])")
print("- \(scene.partPositions[scene.partPositions.count - 1])")
print("first rotations in scene:")
print("- \(scene.partRotations[0])")
print("- \(scene.partRotations[1])")
print("- \(scene.partRotations[2])")
print("last rotations in scene:")
print("- \(scene.partRotations[scene.partRotations.count - 3])")
print("- \(scene.partRotations[scene.partRotations.count - 2])")
print("- \(scene.partRotations[scene.partRotations.count - 1])")

@MainActor
func load(frameID: Int) {
  func createPartRange() -> Range<Int> {
    var startPartID = frameID * loadingSpeed
    var endPartID = startPartID + loadingSpeed
    startPartID = min(startPartID, scene.partPositions.count)
    endPartID = min(endPartID, scene.partPositions.count)
    return startPartID..<endPartID
  }
  let partRange = createPartRange()
  guard partRange.count > 0 else {
    return
  }
  
  nonisolated(unsafe)
  let topologyCopy = topology
  nonisolated(unsafe)
  let atomsReference = application.atoms
  @Sendable
  func load(partID: Int) {
    let partPosition = scene.partPositions[partID]
    let partRotation = scene.partRotations[partID]
    
    // The base address in the address space for atoms.
    let baseAddress = partID * topologyCopy.atoms.count
    
    for atomID in topologyCopy.atoms.indices {
      var atom = topologyCopy.atoms[atomID]
      
      var position: SIMD3<Float> = .zero
      position += partRotation.0 * atom.position[0]
      position += partRotation.1 * atom.position[1]
      position += partRotation.2 * atom.position[2]
      position += partPosition
      atom.position = position
      
      atomsReference[baseAddress + atomID] = atom
    }
  }
  
  let start = Date()
  if loadingUsesMultithreading {
    DispatchQueue.concurrentPerform(
      iterations: partRange.count
    ) { taskID in
      let partID = partRange.startIndex + taskID
      load(partID: partID)
    }
  } else {
    for partID in partRange {
      load(partID: partID)
    }
  }
  let end = Date()
  
  // Report latency diagnostics.
  let latency = end.timeIntervalSince(start)
  let latencyMicroseconds = Int(latency * 1e6)
  let latencyNanoseconds = latency * 1e9
  
  let atomCount = partRange.count * topology.atoms.count
  let nsPerAtom = latencyNanoseconds / Double(atomCount)
  let nsPerAtomRepr = String(format: "%.1f", nsPerAtom)
  print(partRange.count, latencyMicroseconds, "μs", nsPerAtomRepr, "ns/atom")
}

@MainActor
func createTime() -> Float {
  let elapsedFrames = application.clock.frames
  let frameRate = application.display.frameRate
  let seconds = Float(elapsedFrames) / Float(frameRate)
  return seconds
}

@MainActor
func modifyCamera() {
  // 0.1 Hz rotation rate
  // Starts out at 30° to capture more of the action.
  let time = createTime()
  let angleDegrees = 0.1 * time * 360 + 30
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * -angleDegrees,
    axis: SIMD3(0, 1, 0))
  
  application.camera.basis.0 = rotation.act(on: SIMD3(1, 0, 0))
  application.camera.basis.1 = rotation.act(on: SIMD3(0, 1, 0))
  application.camera.basis.2 = rotation.act(on: SIMD3(0, 0, 1))
  application.camera.fovAngleVertical = Float.pi / 180 * fovAngleDegrees
}

application.run {
  // Use 'frameID' instead of 'clock.frames' for timing the loading. We want to
  // make sure every frame is handled, and not a single one is skipped.
  load(frameID: application.frameID)
  
  // Conversely, real-time animations want to skip frames when it's actually
  // skipped ahead in time from a random instance of lag. The camera rotation
  // animation uses 'clock.frames'.
  modifyCamera()
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
