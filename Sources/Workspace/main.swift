import HDL
import MolecularRenderer

// Components of this PR:
// - Tasks on "BVH Update Process". Estimated completion: Oct 16 2025
// - Implement fully optimized primary ray intersector from main-branch-backup.
// - Critical distance heuristic is mandatory. Unacceptable to have a warped
//   data distribution where atoms far from the user suffer two-fold: more cost
//   for the primary ray, more divergence for the secondary rays. Another
//   factor that degrades the viability of predicting & controlling performance.
//
// Current task:
// - Reset the idle state of the atomic counters after the kernel is finished,
//   during 'forgetIdleState'. Check for the presence of nonzero counters
//   (reproduce the checksum code) during the active state, otherwise 100% zero
//   during idle. Debug 4 key points during a series of 2 BVH updates.
// - Move on to the second stage of the "add process".
//   - Memory slot list is effectively contiguous and 100% vacant.

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
  
  applicationDesc.addressSpaceSize = 2_000_000
  applicationDesc.voxelAllocationSize = 200_000_000
  applicationDesc.worldDimension = 32
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

// 8631 atoms
let lattice = Lattice<Cubic> { h, k, l in
  Bounds { 10 * (h + k + l) }
  Material { .checkerboard(.silicon, .carbon) }
}

for atomID in lattice.atoms.indices {
  let atom = lattice.atoms[atomID]
  application.atoms[atomID] = atom
  application.atoms[atomID] = atom
  application.atoms[atomID] = atom
}

application.updateBVH(inFlightFrameID: 0)
application.forgetIdleState(inFlightFrameID: 0)
application.runDiagnostic()
