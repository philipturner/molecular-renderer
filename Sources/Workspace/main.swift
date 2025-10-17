import HDL
import MolecularRenderer
import QuaternionModule

// Remaining tasks of this PR:
// - Implement a kernel that intersects primary rays with atoms.
// - Before implementing AO, implement a scheme where the atom's pixel count is
//   diagnosed in the on-screen texture. Confirm that upscale factors don't
//   change this (backend code has properly corrected for the upscale factor).
// - Implement fully optimized primary ray intersector from main-branch-backup.
// - Implement 32 nm scoping to further optimize the per-dense-voxel cost.
//   Then, see whether this can benefit the primary ray intersector for large
//   distances.

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
  applicationDesc.upscaleFactor = 1
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 32
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

let lattice = Lattice<Cubic> { h, k, l in
  Bounds { 10 * (h + k + l) }
  Material { .checkerboard(.carbon, .silicon) }
}

func createRotationCenter() -> SIMD3<Float> {
  let latticeConstant = Constant(.square) {
    .checkerboard(.silicon, .carbon)
  }
  let halfSize = latticeConstant * 5
  return SIMD3<Float>(repeating: halfSize)
}

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
  let latticeCopy = lattice
  let applicationCopy = application
  
  for atomID in lattice.atoms.indices {
    var atom = latticeCopy.atoms[atomID]
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
  
  let image = application.render()
  application.present(image: image)
}
