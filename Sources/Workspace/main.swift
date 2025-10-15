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
  
  print()
  print(outputArray.count)
  print(outputArray)
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
    
    // After this, switch the order of which ones were added, which removed.
    // Then, test a scenario with removed, moved and added simultaneously.
    if frameID == 0 {
      if isSelected {
//        let atom = lattice.atoms[atomID]
//        application.atoms[atomID] = atom
      }
    } else if frameID == 1 {
      if isSelected {
//        application.atoms[atomID] = nil
      }
      if !isSelected {
        let atom = lattice.atoms[atomID]
        application.atoms[atomID] = atom
      }
    }
  }
  
  application.updateBVH1(inFlightFrameID: frameID)
  
  /*
   // 199 added, then removed
   
   0:  199
   1: 4765
   2: 2841
   3:    0
   4:  585
   5:    0
   6:    0
   7:    0
   8:  241
   9:    0
  10:    0
  11:    0
  12:    0
  13:    0
  14:    0
  15:    0
  16:    0
   
   total atom count: 8432
   total reference count: 14715
   
   62
   [1911, 1912, 1927, 1928, 1929, 1930, 1943, 1944, 1945, 1946, 1959, 1960, 1961, 1962, 2167, 2168, 2169, 2170, 2183, 2184, 2185, 2186, 2199, 2200, 2201, 2202, 2215, 2216, 2217, 2218, 2423, 2424, 2425, 2426, 2439, 2440, 2441, 2442, 2455, 2456, 2457, 2458, 2471, 2472, 2473, 2474, 2679, 2680, 2681, 2682, 2695, 2696, 2697, 2698, 2711, 2712, 2713, 2714, 2727, 2728, 2729, 2730]
   
   // 199 never added
   
   0:  199
   1: 4850
   2: 2939
   3:    0
   4:  601
   5:    0
   6:    0
   7:    0
   8:   42
   9:    0
  10:    0
  11:    0
  12:    0
  13:    0
  14:    0
  15:    0
  16:    0
   
   total atom count: 8432
   total reference count: 13468
   
   60
   [1927, 1928, 1929, 1930, 1943, 1944, 1945, 1946, 1959, 1960, 1961, 1962, 2167, 2168, 2169, 2170, 2183, 2184, 2185, 2186, 2199, 2200, 2201, 2202, 2215, 2216, 2217, 2218, 2423, 2424, 2425, 2426, 2439, 2440, 2441, 2442, 2455, 2456, 2457, 2458, 2471, 2472, 2473, 2474, 2679, 2680, 2681, 2682, 2695, 2696, 2697, 2698, 2711, 2712, 2713, 2714, 2727, 2728, 2729, 2730]
   */
  
  print()
  analyzeGeneralCounters()
  print()
  inspectAtomsRemovedVoxels()
  //inspectMemorySlots()
  
  application.updateBVH2(inFlightFrameID: frameID)
  
  print()
  analyzeGeneralCounters()
  print()
  inspectRebuiltVoxels()
  //inspectMemorySlots()
  
  application.forgetIdleState(inFlightFrameID: frameID)
}

/*
 0 SIMD3<Float>(-2.0, -2.0, 0.0)
 1 SIMD3<Float>(-2.0, -2.0, 2.0)
 2 SIMD3<Float>(-2.0, -2.0, 4.0)
 3 SIMD3<Float>(0.0, -2.0, 4.0)
 4 SIMD3<Float>(2.0, -2.0, 4.0)
 5 SIMD3<Float>(4.0, -2.0, 4.0)
 6 SIMD3<Float>(0.0, -2.0, 0.0)
 7 SIMD3<Float>(2.0, -2.0, 0.0)
 8 SIMD3<Float>(4.0, -2.0, 0.0)
 9 SIMD3<Float>(0.0, -2.0, 2.0)
10 SIMD3<Float>(2.0, -2.0, 2.0)
11 SIMD3<Float>(4.0, -2.0, 2.0)
12 SIMD3<Float>(0.0, 0.0, 0.0)
13 SIMD3<Float>(2.0, 0.0, 0.0)
14 SIMD3<Float>(4.0, 0.0, 0.0)
15 SIMD3<Float>(0.0, 2.0, 0.0)
16 SIMD3<Float>(2.0, 2.0, 0.0)
17 SIMD3<Float>(4.0, 2.0, 0.0)
18 SIMD3<Float>(0.0, 4.0, 0.0)
19 SIMD3<Float>(2.0, 4.0, 0.0)
20 SIMD3<Float>(4.0, 4.0, 0.0)
21 SIMD3<Float>(0.0, 0.0, 2.0)
22 SIMD3<Float>(2.0, 0.0, 2.0)
23 SIMD3<Float>(4.0, 0.0, 2.0)
24 SIMD3<Float>(0.0, 2.0, 2.0)
25 SIMD3<Float>(2.0, 2.0, 2.0)
26 SIMD3<Float>(4.0, 2.0, 2.0)
27 SIMD3<Float>(0.0, 4.0, 2.0)
28 SIMD3<Float>(2.0, 4.0, 2.0)
29 SIMD3<Float>(4.0, 4.0, 2.0)
30 SIMD3<Float>(0.0, 0.0, 4.0)
31 SIMD3<Float>(2.0, 0.0, 4.0)
32 SIMD3<Float>(4.0, 0.0, 4.0)
33 SIMD3<Float>(0.0, 2.0, 4.0)
34 SIMD3<Float>(2.0, 2.0, 4.0)
35 SIMD3<Float>(4.0, 2.0, 4.0)
36 SIMD3<Float>(0.0, 4.0, 4.0)
37 SIMD3<Float>(2.0, 4.0, 4.0)
38 SIMD3<Float>(4.0, 4.0, 4.0)
39 SIMD3<Float>(-2.0, 0.0, 4.0)
40 SIMD3<Float>(-2.0, 2.0, 4.0)
41 SIMD3<Float>(-2.0, 4.0, 4.0)
42 SIMD3<Float>(-2.0, 0.0, 0.0)
43 SIMD3<Float>(-2.0, 2.0, 0.0)
44 SIMD3<Float>(-2.0, 4.0, 0.0)
45 SIMD3<Float>(-2.0, 0.0, 2.0)
46 SIMD3<Float>(-2.0, 2.0, 2.0)
47 SIMD3<Float>(-2.0, 4.0, 2.0)
48 SIMD3<Float>(-2.0, 0.0, -2.0)
49 SIMD3<Float>(-2.0, 2.0, -2.0)
50 SIMD3<Float>(-2.0, 4.0, -2.0)
51 SIMD3<Float>(0.0, 0.0, -2.0)
52 SIMD3<Float>(2.0, 0.0, -2.0)
53 SIMD3<Float>(4.0, 0.0, -2.0)
54 SIMD3<Float>(0.0, 2.0, -2.0)
55 SIMD3<Float>(2.0, 2.0, -2.0)
56 SIMD3<Float>(4.0, 2.0, -2.0)
57 SIMD3<Float>(0.0, 4.0, -2.0)
58 SIMD3<Float>(2.0, 4.0, -2.0)
59 SIMD3<Float>(4.0, 4.0, -2.0)
 
 0 SIMD3<Float>(0.0, 0.0, 4.0)
 1 SIMD3<Float>(2.0, 0.0, 4.0)
 2 SIMD3<Float>(4.0, 0.0, 4.0)
 3 SIMD3<Float>(0.0, 2.0, 4.0)
 4 SIMD3<Float>(2.0, 2.0, 4.0)
 5 SIMD3<Float>(4.0, 2.0, 4.0)
 6 SIMD3<Float>(0.0, 4.0, 4.0)
 7 SIMD3<Float>(2.0, 4.0, 4.0)
 8 SIMD3<Float>(4.0, 4.0, 4.0)
 9 SIMD3<Float>(0.0, 0.0, 0.0)
10 SIMD3<Float>(2.0, 0.0, 0.0)
11 SIMD3<Float>(4.0, 0.0, 0.0)
12 SIMD3<Float>(0.0, 2.0, 0.0)
13 SIMD3<Float>(2.0, 2.0, 0.0)
14 SIMD3<Float>(4.0, 2.0, 0.0)
15 SIMD3<Float>(0.0, 4.0, 0.0)
16 SIMD3<Float>(2.0, 4.0, 0.0)
17 SIMD3<Float>(4.0, 4.0, 0.0)
18 SIMD3<Float>(0.0, 0.0, 2.0)
19 SIMD3<Float>(2.0, 0.0, 2.0)
20 SIMD3<Float>(4.0, 0.0, 2.0)
21 SIMD3<Float>(0.0, 2.0, 2.0)
22 SIMD3<Float>(2.0, 2.0, 2.0)
23 SIMD3<Float>(4.0, 2.0, 2.0)
24 SIMD3<Float>(0.0, 4.0, 2.0)
25 SIMD3<Float>(2.0, 4.0, 2.0)
26 SIMD3<Float>(4.0, 4.0, 2.0)
27 SIMD3<Float>(-2.0, 0.0, 4.0)
28 SIMD3<Float>(-2.0, 2.0, 4.0)
29 SIMD3<Float>(-2.0, 4.0, 4.0)
30 SIMD3<Float>(-2.0, 0.0, 0.0)
31 SIMD3<Float>(-2.0, 2.0, 0.0)
32 SIMD3<Float>(-2.0, 4.0, 0.0)
33 SIMD3<Float>(-2.0, 0.0, 2.0)
34 SIMD3<Float>(-2.0, 2.0, 2.0)
35 SIMD3<Float>(-2.0, 4.0, 2.0)
36 SIMD3<Float>(-2.0, 0.0, -2.0)
37 SIMD3<Float>(-2.0, 2.0, -2.0)
38 SIMD3<Float>(-2.0, 4.0, -2.0)
39 SIMD3<Float>(0.0, 0.0, -2.0)
40 SIMD3<Float>(2.0, 0.0, -2.0)
41 SIMD3<Float>(4.0, 0.0, -2.0)
42 SIMD3<Float>(0.0, 2.0, -2.0)
43 SIMD3<Float>(2.0, 2.0, -2.0)
44 SIMD3<Float>(4.0, 2.0, -2.0)
45 SIMD3<Float>(0.0, 4.0, -2.0)
46 SIMD3<Float>(2.0, 4.0, -2.0)
47 SIMD3<Float>(4.0, 4.0, -2.0)
48 SIMD3<Float>(0.0, -2.0, 0.0)
49 SIMD3<Float>(2.0, -2.0, 0.0)
50 SIMD3<Float>(4.0, -2.0, 0.0)
51 SIMD3<Float>(0.0, -2.0, 2.0)
52 SIMD3<Float>(2.0, -2.0, 2.0)
53 SIMD3<Float>(4.0, -2.0, 2.0)
54 SIMD3<Float>(0.0, -2.0, 4.0)
55 SIMD3<Float>(2.0, -2.0, 4.0)
56 SIMD3<Float>(4.0, -2.0, 4.0)
57 SIMD3<Float>(-2.0, -2.0, 0.0)
58 SIMD3<Float>(-2.0, -2.0, 2.0)
59 SIMD3<Float>(-2.0, -2.0, 4.0)
60 SIMD3<Float>(-2.0, -2.0, -2.0) *
61 SIMD3<Float>(0.0, -2.0, -2.0) *
 
 1911 = 7 * 16 * 16 + 7 * 16 + 7
 1912 = 7 * 16 * 16 + 7 * 16 + 8
 1911 -> (14, 14, 14) -> (-2, -2, -2)
 1912 -> (16, 14, 14) -> (0, -2, -2)
 */

#endif
