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
// - Rigorous test for correct functionality during add/remove: experiment on
//   atoms 0...99, 4000...4049, and 4051...4099.
//   - First test: these atoms are not rewritten, the rest register as 'moved'.
//   - Second test: these atoms are moved, the rest are either 'moved', 'added',
//     or unchanged. Test each of the 3 cases.
//   - Third test: these atoms are either 'moved' or unchanged. The rest are
//     removed. Test each of the 2 cases.
// - Archive the above testing code to a GitHub gist, along with its utilities
//   in "Application+UpdateBVH.swift".
// - Rigorous test for correct functionality during rebuild
//   - Probably less complex than the previous test.
//   - Out of scope for the previous test, does not need to be cross-coupled
//     with the various possibilities for behavior during add/remove.
//   - Will still rely on the same silicon carbide lattice as the previous test.

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
func inspectRebuiltVoxels() {
  let voxelCoords = application.downloadRebuiltVoxelCoords()
  
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
      
      /*
       pad(atomCount)
       
       2184 1161   58 3464 3472 3480 2720  184 3712 1176 3720 1024 1792 1800 1952 3728 1032 1960 1184 1040 2856 3616  928  936 2696 3624 2864  944 1192 2704 3632 2712 1696 3640 2872  952 3648  960 1120 1704 2880 2784 1200 3536 2792 1936 2888  192 1712  200 2800 1944 3544
       2185 1162   42 1080 3584 2072  288 2816 2824 3592 2736  296 3600 2832 2744 2840  912 3488 3736 3496 1808 3504 1816 1968 1048 3512  304 2080 1976 3744 1824  224  232 3752 2088
       2186 1163   10 1000 1248 2008 3600
       2199 1183    4
       2200 1164   39 3104 3112 1424 2344 2432 1432 2352 3120 3128 2440 2096 3872 2448 3880  584 1584 2944 3200  592 2104 3968  600 2952  608 1440 2184 1256 2112 1448 2360 1264 2960 3976
       2201 1165   58 3248 1304  544  648  552 1568  560 1312  568 1320 3072  616 3080 1456 3088 3984 1464  624  632 3896 1472 3168 3992 3840 1480 1544 1376 2136 1384 1552 2976 3224 1488 2304 3848 1560 1392 1400 2984 2312 1632 1640 1648 2992 2296 2320
       2202 1166   18 1248  648  568 1488 3088 2328 2168
       */
      
      /*
       pad(UInt32(j))
       
       2184 289   58    8    9   10   11   12   13   14   15   16   17   18   19   20   21   22   23   24   25   26   27   28   29   30   31   32   33   34   35   36   37   38   39   40   41   42   43   44   45   46   47   48   49   50   51   52   53   54   55   56   57
       2185 290   42   10   11   12   13   14   15   16   17   18   19   20   21   22   23   24   25   26   27   28   29   30   31   32   33   34   35   36   37   38   39   40   41
       2186 291   10    6    7    8    9
       2199 281    4
       2200 292   39    5    6    7    8    9   10   11   12   13   14   15   16   17   18   19   20   21   22   23   24   25   26   27   28   29   30   31   32   33   34   35   36   37   38
       2201 293   58    9   10   11   12   13   14   15   16   17   18   19   20   21   22   23   24   25   26   27   28   29   30   31   32   33   34   35   36   37   38   39   40   41   42   43   44   45   46   47   48   49   50   51   52   54   55   56   57
       2202 294   18   10   11   12   13   14   15   16   17
       */
      
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
  
  if summary[1] < 500 {
    print()
    for atomID in atomDuplicatedReferences.indices {
      let referenceCount = atomDuplicatedReferences[atomID]
      if referenceCount > 0 {
        print(atomID)
      }
    }
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
    var isSelected = false
    if atomID >= 0 && atomID <= 99 {
      isSelected = true
    }
    if atomID >= 4000 && atomID <= 4049 {
      isSelected = true
    }
    if atomID >= 4051 && atomID <= 4099 {
      isSelected = true
    }
    
    if frameID == 1 {
      if isSelected {
        continue
      }
    }
    
    let atom = lattice.atoms[atomID]
    application.atoms[atomID] = atom
  }
  
  application.updateBVH1(inFlightFrameID: frameID)
  
  print()
  analyzeGeneralCounters()
  print()
  //inspectAtomsRemovedVoxels()
  inspectMemorySlots()
  
  application.updateBVH2(inFlightFrameID: frameID)
  
  print()
  analyzeGeneralCounters()
  print()
  //inspectRebuiltVoxels()
  inspectMemorySlots()
  
  application.forgetIdleState(inFlightFrameID: frameID)
}

#endif
