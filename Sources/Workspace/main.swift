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
// - Bind all buffers needed for all BVH update stages, draft the root
//   signatures, and smoke test the CPU-side command encoding.
// - Try using R10G10B10A2_UNORM format in Metal to natively compress and
//   de-compress voxel coordinates.
// - Create an upload (copy) buffer to sparse.assignedVoxels for testing
//   memory allocation. Verify the contents with a debug diagnostic, sized at
//   the previously queried exact memory slot count.
// - Implement removeProcess4 and then addProcess2. Along the way, develop
//   utilities to improve code reuse for GPU reductions, when appropriate.
// - Debug all the steps toward the minimum viable product of rendering, one at
//   a time. The rotating rod test might be a helpful tool to facilitate
//   debugging, but is not mandatory at the moment.

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
}

application.updateBVH(inFlightFrameID: 0)
application.forgetIdleState(inFlightFrameID: 0)
