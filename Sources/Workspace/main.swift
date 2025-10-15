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
// - Clean up the code base after the previous test.
//   - Retain the functionality for reading buffers from the public API.
//   - Remove the intersection of 4 custom occupied slots prior to frame 0.
//   - Merge the two parts of updateBVH back into a single command buffer.
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
func inspectAtomsRemovedVoxels() {
  let voxelCoords = application.downloadAtomsRemovedVoxelCoords()
  
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

for frameID in 0...5 {
  for atomID in lattice.atoms.indices {
    let atom = lattice.atoms[atomID]
    
    // voxels spanned: 24
    //
    //    0: 8432
    //    1:   63
    //    2:   97
    //    3:    0
    //    4:   35
    //    5:    0
    //    6:    0
    //    7:    0
    //    8:    4
    //    9:    0
    //   10:    0
    //   11:    0
    //   12:    0
    //   13:    0
    //   14:    0
    //   15:    0
    //   16:    0
    // total atom count: 199
    // total reference count: 429
    var isSelected1 = false
    if atomID >= 0 && atomID <= 99 {
      isSelected1 = true
    }
    if atomID >= 4000 && atomID <= 4049 {
      isSelected1 = true
    }
    if atomID >= 4051 && atomID <= 4099 {
      isSelected1 = true
    }
    
    // voxels spanned: 14
    //
    //    0: 8330
    //    1:  107
    //    2:  147
    //    3:    0
    //    4:   44
    //    5:    0
    //    6:    0
    //    7:    0
    //    8:    3
    //    9:    0
    //   10:    0
    //   11:    0
    //   12:    0
    //   13:    0
    //   14:    0
    //   15:    0
    //   16:    0
    // total atom count: 301
    // total reference count: 601
    var isSelected2 = false
    if atomID >= 500 && atomID <= 800 {
      isSelected2 = true
    }
    
    // voxels spanned: 60
    //
    //    0:  500
    //    1: 4743
    //    2: 2792
    //    3:    0
    //    4:  557
    //    5:    0
    //    6:    0
    //    7:    0
    //    8:   39
    //    9:    0
    //   10:    0
    //   11:    0
    //   12:    0
    //   13:    0
    //   14:    0
    //   15:    0
    //   16:    0
    // total atom count: 8131
    // total reference count: 12867
    let isSelected3 = !(isSelected1 || isSelected2)
    
    enum TransactionType {
      case remove
      case move
      case add
    }
    
    var transactionType: TransactionType?
    if isSelected1 {
      if frameID == 0 {
        transactionType = .add
      } else if frameID == 1 {
        
      } else if frameID == 2 {
        transactionType = .move
      } else if frameID == 3 {
        transactionType = .remove
      }
    } else if isSelected2 {
      if frameID == 1 {
        transactionType = .add
      } else if frameID == 2 {
        
      } else if frameID == 3 {
        transactionType = .move
      } else if frameID == 4 {
        transactionType = .remove
      }
    } else if isSelected3 {
      if frameID == 2 {
        transactionType = .add
      } else if frameID == 3 {
        
      } else if frameID == 4 {
        transactionType = .move
      } else if frameID == 5 {
        transactionType = .remove
      }
    }
    
    if let transactionType {
      switch transactionType {
      case .remove:
        application.atoms[atomID] = nil
      case .move:
        var movedAtom = atom
        movedAtom.position += SIMD3<Float>(1, 1, 1)
        application.atoms[atomID] = movedAtom
      case .add:
        application.atoms[atomID] = atom
      }
    }
  }
  
  application.updateBVH1(inFlightFrameID: frameID % 3)
  
  print()
  print("===============")
  print("=== frame \(frameID) ===")
  print("===============")
  
  print()
  analyzeGeneralCounters()
  print()
//  inspectAtomsRemovedVoxels()
  inspectMemorySlots()
  
  application.updateBVH2(inFlightFrameID: frameID % 3)
  
  print()
  analyzeGeneralCounters()
  print()
//  inspectRebuiltVoxels()
  inspectMemorySlots()
  
  application.forgetIdleState(inFlightFrameID: frameID % 3)
}

#endif
