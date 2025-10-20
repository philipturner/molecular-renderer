import HDL
import MolecularRenderer

// Remaining tasks of this PR:
// - Implement 32 nm scoping to further optimize the per-dense-voxel cost.
//   - Create a new section of the Google Sheet.
//   - Benchmark existing cost of an empty scene with a thorough range of
//     values for world size.
//   - Implement the proposed changes and test for correctness.
//   - Validate a substantial improvement to latency on the GPU timeline
//     (several hundred microseconds at large world dimensions).
// - Integrate the critical pixel count heuristic into the code base.
//   - Save the long distances test to the Tests directory.
//   - Implement the critical pixel count test; shouldn't take much time.
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

application.run {
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
