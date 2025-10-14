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
// - Implement rebuildProcess1 before running the following analysis.
//   - Rigorous test for correct functionality: experiment on atoms 0...99,
//     4000...4049, and 4051...4099.
//   - First test: these atoms are not rewritten, the rest register as 'moved'.
//   - Second test: these atoms are moved, the rest are either 'moved', 'added',
//     or unchanged. Test each of the 3 cases.
//   - Third test: these atoms are either 'moved' or unchanged. The rest are
//     removed. Test each of the 2 cases.

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

@MainActor
func uploadDebugInput() {
  var input = [UInt32](repeating: UInt32.max, count: 3616)
  input[5] = 0
  input[120] = 1
  input[121] = 2
  input[184] = 3
  application.uploadAssignedVoxelCoords(input)
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
func inspectAtomsRemovedVoxels() {
  let voxelCoords = application.downloadAtomsRemovedVoxelCoords()
  
  for i in voxelCoords.indices {
    func pad(_ integer: Int) -> String {
      var output = "\(integer)"
      while output.count < 3 {
        output = " " + output
      }
      return output
    }
    
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
  for i in assignedSlotIDs.indices {
    let assignedSlotID = assignedSlotIDs[i]
    guard assignedSlotID != UInt32.max else {
      continue
    }
    
    func pad(_ integer: UInt32) -> String {
      var output = "\(integer)"
      while output.count < 4 {
        output = " " + output
      }
      return output
    }
    
    let headerAddress = Int(assignedSlotID) * 55304 / 4
    let atomCount = memorySlots[headerAddress]
    print(i, assignedSlotID, pad(atomCount), terminator: " ")
    
    let listAddress = headerAddress + 2056 / 4
    for j in 0..<Int(atomCount) {
      let atomID = memorySlots[listAddress + j]
      if j < 5 {
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
    func pad(_ integer: Int) -> String {
      var output = "\(integer)"
      while output.count < 4 {
        output = " " + output
      }
      return output
    }
    
    let atomCount = summary[referenceCount]
    print("\(pad(referenceCount)): \(pad(atomCount))")
  }
  print("total atom count: \(summary.reduce(0, +))")
  print("total reference count: \(atomDuplicatedReferences.reduce(0, +))")
}

for frameID in 0...1 {
  for atomID in lattice.atoms.indices {
    let atom = lattice.atoms[atomID]
    application.atoms[atomID] = atom
  }
  
  application.updateBVH1(inFlightFrameID: frameID)
  
  print()
  analyzeGeneralCounters()
  print()
  inspectAtomsRemovedVoxels()
  //inspectMemorySlots()
  
  application.updateBVH2(inFlightFrameID: frameID)
  
  print()
  analyzeGeneralCounters()
  print()
  //inspectMemorySlots()
  
  application.forgetIdleState(inFlightFrameID: frameID)
}

#endif
