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
  Material { .checkerboard(.silicon, .carbon) }
}

for atomID in lattice.atoms.indices {
  let atom = lattice.atoms[atomID]
  application.atoms[atomID] = atom
}

application.run {
  let latticeConstant = Constant(.square) {
    .checkerboard(.silicon, .carbon)
  }
  let halfSize = latticeConstant * 5
  application.camera.position = SIMD3(
    halfSize,
    halfSize,
    2 * halfSize + 2 * halfSize)
  application.camera.fovAngleVertical = Float.pi / 180 * 60
  
  let image = application.render()
  application.present(image: image)
}
