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
// - Implement addProcess3, then the remove process. At the end of this, we
//   will no longer have the GPU crash from too many atoms/voxel.
// - Inspect contents of buffers only when it feels appropriate.
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

@MainActor
func uploadDebugInput() {
  var input = [UInt32](repeating: UInt32.max, count: 3616)
  input[5] = 0
  input[120] = 1
  input[121] = 2
  input[184] = 3
  application.uploadDebugInput(input)
}
uploadDebugInput()

#if false
application.run {
  for atomID in lattice.atoms.indices {
    let atom = lattice.atoms[atomID]
    application.atoms[atomID] = atom
  }
  
  let image = application.render()
  application.present(image: image)
}
#else

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
func analyzeDebugOutput() -> [SIMD8<UInt32>] {
  var output = [SIMD8<UInt32>](repeating: .zero, count: 4096)
  application.downloadDebugOutput(&output)
  return output
}
func analyzeBeforeAfter(
  _ before: [SIMD8<UInt32>],
  _ after: [SIMD8<UInt32>]
) {
  for i in 0..<4096 {
    let beforeValue = before[i]
    let afterValue = after[i]
    if all(beforeValue .== SIMD8.zero) {
      if all(afterValue .== SIMD8.zero) {
        continue
      } else {
        fatalError("This should never happen.")
      }
    }
    print(i, beforeValue, afterValue)
  }
}

for frameID in 0...1 {
  for atomID in lattice.atoms.indices {
    let atom = lattice.atoms[atomID]
    application.atoms[atomID] = atom
  }
  
  application.updateBVH1(inFlightFrameID: frameID)
  
  print()
  analyzeDebugOutput2()
  print()
  let output1 = analyzeDebugOutput()
  
  application.updateBVH2(inFlightFrameID: frameID)
  
  print()
  analyzeDebugOutput2()
  print()
  let output2 = analyzeDebugOutput()
  analyzeBeforeAfter(output1, output2)
  
  application.forgetIdleState(inFlightFrameID: frameID)
}

#endif
