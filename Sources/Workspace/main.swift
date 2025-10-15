import HDL
import MolecularRenderer

// Components of this PR:
// - Tasks on "BVH Update Process". Estimated completion: Oct 16 2025
// - Jump straight to a kernel that intersects primary rays with atoms, with
//   no fear of infinite loops crashing the Mac.
//   - Will have validated that corrupted BVH is not a likely culprit of bugs.
// - Implement fully optimized primary ray intersector from main-branch-backup.
// - Critical distance heuristic is mandatory. Unacceptable to have a warped
//   data distribution where atoms far from the user suffer two-fold: more cost
//   for the primary ray, more divergence for the secondary rays. Another
//   factor that degrades the viability of predicting & controlling performance.
//
// Current task:
// - Test for correct functionality during rebuild.
//   - Less complex than the previous test; quite easy and quick.
//   - Out of scope for the previous test, does not need to be cross-coupled
//     with the various possibilities for behavior during add/remove.
//   - Will still rely on the same silicon carbide lattice as the previous test.
// - Archive the above testing code to a GitHub gist, along with its utilities
//   in "Application+UpdateBVH.swift".

// Helpful facts about the test setup:
// atom count: 8631
// memory slot count: 3616
// memory slot size: 55304 B
//   .headerLarge = 0 B
//   .headerSmall = 8 B
//   .referenceLarge = 2056 B
//   .referenceSmall = 14344 B
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
  
  let image = application.render()
  application.present(image: image)
}
#else

func pad<T: BinaryInteger>(_ integer: T) -> String {
  var output = "\(integer)"
  while output.count < 4 {
    output = " " + output
  }
  return output
}

@MainActor
func analyzeGeneralCounters() {
  let output = application.downloadGeneralCounters()
  
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
func inspectRebuiltVoxels() {
  let voxelCoords = application.downloadRebuiltVoxelCoords()
  
  for i in voxelCoords.indices {
    let encoded = voxelCoords[i]
    guard encoded != UInt32.max else {
      continue
    }
    
    let decoded = SIMD3<UInt32>(
      encoded & 1023,
      (encoded >> 10) & 1023,
      encoded >> 20
    )
    let lowerCorner = SIMD3<Float>(decoded) * 2 - (Float(32) / 2)
    print(pad(i), lowerCorner)
  }
}

@MainActor
func inspectMemorySlots() {
  let assignedSlotIDs = application.downloadAssignedSlotIDs()
  let memorySlots = application.downloadMemorySlots()
  
  var atomDuplicatedReferences = [Int](repeating: .zero, count: 8631)
  var outputArray: [Int] = []
  for i in assignedSlotIDs.indices {
    let assignedSlotID = assignedSlotIDs[i]
    guard assignedSlotID != UInt32.max else {
      continue
    }
    outputArray.append(i)
    
    let headerAddress = Int(assignedSlotID) * 55304 / 4
    let atomCount = memorySlots[headerAddress]
    print(pad(i), pad(assignedSlotID), pad(atomCount), terminator: " ")
    
    let listAddress = headerAddress + 2056 / 4
    for j in 0..<Int(atomCount) {
      let atomID = memorySlots[listAddress + j]
      if j < 12 {
        print(pad(atomID), terminator: " ")
      }
      
      if atomID >= atomDuplicatedReferences.count {
        fatalError("Invalid atom ID: \(atomID)")
      }
      atomDuplicatedReferences[Int(atomID)] += 1
    }
    print()
  }
  
  var summary = [Int](repeating: .zero, count: 17)
  for atomID in atomDuplicatedReferences.indices {
    let referenceCount = atomDuplicatedReferences[atomID]
    if referenceCount > 16 {
      fatalError("Invalid reference count: \(referenceCount)")
    }
    summary[referenceCount] += 1
  }
  
  print()
  for referenceCount in summary.indices {
    let atomCount = summary[referenceCount]
    print("\(pad(referenceCount)): \(pad(atomCount))")
  }
  print("total atom count: \(summary[1...].reduce(0, +))")
  print("total reference count: \(atomDuplicatedReferences.reduce(0, +))")
}

for frameID in 0...0 {
  for atomID in lattice.atoms.indices {
    let atom = lattice.atoms[atomID]
    application.atoms[atomID] = atom
  }
  
  application.updateBVH(inFlightFrameID: frameID % 3)
  application.forgetIdleState(inFlightFrameID: frameID % 3)
  
  print()
  print("===============")
  print("=== frame \(frameID) ===")
  print("===============")
  
  print()
  analyzeGeneralCounters()
  print()
  inspectMemorySlots()
}

#endif
