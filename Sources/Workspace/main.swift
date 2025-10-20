import HDL
import MolecularRenderer

// Remaining tasks of this PR:
// - Implement 32 nm scoping to further optimize the per-dense-voxel cost.
//   - Implement the proposed changes.
//     - Sort out the rearrangement to GeneralCounters, with 4 new indirect
//       dispatch arguments.
//     - Modify the pseudocode for relevant existing kernels.
//     - Sort out the decoding of voxel group coords, similar to the decoding
//       of 2 nm voxel coords.
//     - Add the 4 new list allocations to the allocations to purge at the
//       start of every frame.
//     - Relabel all coords buffers as either 2 or 8.
//     - Create a single utility kernel that reads from 3 marks, which may be
//       duplicates of each other. This kernel globally reduces into a list of
//       8 nm voxel groups to dispatch.
//   - Clean up the codebase into a state that can compile and execute.
//   - Test for correctness by running several tests in the Tests folder.
//     - Recycle the rotating beam test, re-activate the code for inspecting
//       the general counters. Remember 164, 184, 190-194 growing all the way
//       to ~230 after 16 iterations with beamDepth = 2 (80k atoms in cross,
//       40k atoms in beam). Make the shader code intentionally wrong and watch
//       the results change.
//   - Validate a substantial improvement to latency on the GPU timeline
//     (several hundred microseconds at large world dimensions).
// - Integrate the critical pixel count heuristic into the code base.
//   - Implement the critical pixel count test; shouldn't take much time.
//   - Implement the heuristic once this test is set up.
// - Clean up the documentation and implement the remaining tests.

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

/*
application.run {
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
*/
