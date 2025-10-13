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
// - Implement removeProcess4 and then addProcess2. Along the way, develop
//   utilities to improve code reuse for GPU reductions, when appropriate.
// - Debug all the steps toward the minimum viable product of rendering, one at
//   a time. The rotating rod test might be a helpful tool to facilitate
//   debugging, but is not mandatory at the moment.

// Helpful facts about the test setup:
// atom count: 8631
// memory slot count: 3616
// voxel group count: 64
// voxel count: 4096

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

let lattice = Lattice<Cubic> { h, k, l in
  Bounds { 10 * (h + k + l) }
  Material { .checkerboard(.silicon, .carbon) }
}

#if false
application.run {
  for atomID in lattice.atoms.indices {
    let atom = lattice.atoms[atomID]
    application.atoms[atomID] = atom
  }
  
  let frameID = application.frameID
  application.updateBVH(inFlightFrameID: frameID % 3)
  let image = application.render()
  application.forgetIdleState(inFlightFrameID: frameID % 3)
  application.present(image: image)
}
#else

@MainActor
func uploadDebugInput() {
  var input = [UInt32](repeating: UInt32.max, count: 3616)
  input[5] = 0
  input[120] = 1
  input[121] = 2
  input[184] = 3
  application.uploadDebugInput(input)
}

@MainActor
func analyzeDebugOutput2() {
  var output = [UInt32](repeating: .zero, count: 10)
  application.downloadDebugOutput2(&output)
  
  print("atoms removed voxel count:", output[0])
  guard output[1] == 1,
        output[2] == 1 else {
    fatalError("Indirect dispatch arguments were malformatted.")
  }
  print("vacant slot count:", output[4])
  print("allocated slot count:", output[5])
  print("rebuilt voxel count:", output[6])
  guard output[7] == 1,
        output[8] == 1 else {
    fatalError("Indirect dispatch arguments were malformatted.")
  }
}

@MainActor
func analyzeDebugOutput() {
  var output = [UInt32](repeating: .zero, count: 3616)
  application.downloadDebugOutput(&output)
  
  output.sort()
  
  let readSlotIDs: [Int] = [
    0, 1, 2, 3, 4, 5, 6, 7,
    117, 118, 120, 121, 122, 123,
    179, 180, 181, 182, 183, 184,
    3610, 3611, 3612, 3613, 3614, 3615,
  ]
  
  for slotID in readSlotIDs {
    let outputValue = output[slotID]
    print(slotID, outputValue)
  }
}

for atomID in lattice.atoms.indices {
  let atom = lattice.atoms[atomID]
  application.atoms[atomID] = atom
}

uploadDebugInput()
application.updateBVH(inFlightFrameID: 0)
application.forgetIdleState(inFlightFrameID: 0)

print()
analyzeDebugOutput2()
print()
analyzeDebugOutput()

#endif
