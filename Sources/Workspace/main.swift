import HDL
import MolecularRenderer
import QuaternionModule

// Remaining tasks of this PR:
// - Attempt to render objects far enough to apply to critical pixel count
//   heuristic.
//   - Archive the current contents of 'main.swift' on a GitHub gist, then
//     implement the long distances test.
// - Implement fully optimized primary ray intersector from main-branch-backup.
// - Implement 32 nm scoping to further optimize the per-dense-voxel cost.
//   Then, see whether this can benefit the primary ray intersector for large
//   distances.

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
