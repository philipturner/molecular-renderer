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
//      if atomID == 8432 {
        print(pad(atomID), terminator: " ")
      }
      
      if atomID >= atomDuplicatedReferences.count {
        fatalError("Invalid atom ID: \(atomID)")
      }
      atomDuplicatedReferences[Int(atomID)] += 1
    }
    print()
  }
  
  print()
  var summary = [Int](repeating: .zero, count: 17)
  for atomID in atomDuplicatedReferences.indices {
    let referenceCount = atomDuplicatedReferences[atomID]
    if referenceCount > 16 {
      fatalError("Invalid reference count: \(referenceCount)")
    }
    summary[referenceCount] += 1
    
    if referenceCount == 8 {
      print(pad(atomID))
    }
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

// 1911  256  199 8432 8552 8560 8568 8576 8584 8592 8600 8608 8520 8440 8528
// 1912  257  199 8552 8560 8568 8576 8584 8592 8600 8608 8616 8624 8520 8528
print()
print(lattice.atoms[8432])
print(AtomStyles.radii[14])
print(lattice.atoms[8432].position - AtomStyles.radii[14])
print(lattice.atoms[8432].position + AtomStyles.radii[14])

// 1911
// 1912
// 1927
// 1928
// 2167
// 2168
// 2183
// 2184

// behavior if all atoms added at once:
// 2696

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

/*
 167
 168
 207
 539
 540
 577
 611
 612
 617
3201
3202
3241
3495
3496
3567
3568
3806
3840
3841
3878
3880
7370
7371
7406
7442
7443
7446
7700
7736
7737
7772
7776
8108
8109
8110
8144
8146
8180
8181
8182
8184
8186
8432
8433
8434
8435
8436
8437
8438
8439
8440
8441
8442
8443
8444
8445
8446
8447
8448
8449
8450
8451
8452
8453
8454
8455
8456
8457
8458
8459
8460
8461
8462
8463
8464
8465
8466
8467
8468
8469
8470
8471
8472
8473
8474
8475
8476
8477
8478
8479
8480
8481
8482
8483
8484
8485
8486
8487
8488
8489
8490
8491
8492
8493
8494
8495
8496
8497
8498
8499
8500
8501
8502
8503
8504
8505
8506
8507
8508
8509
8510
8511
8512
8513
8514
8515
8516
8517
8518
8519
8520
8521
8522
8523
8524
8525
8526
8527
8528
8529
8530
8531
8532
8533
8534
8535
8536
8537
8538
8539
8540
8541
8542
8543
8544
8545
8546
8547
8548
8549
8550
8551
8552
8553
8554
8555
8556
8557
8558
8559
8560
8561
8562
8563
8564
8565
8566
8567
8568
8569
8570
8571
8572
8573
8574
8575
8576
8577
8578
8579
8580
8581
8582
8583
8584
8585
8586
8587
8588
8589
8590
8591
8592
8593
8594
8595
8596
8597
8598
8599
8600
8601
8602
8603
8604
8605
8606
8607
8608
8609
8610
8611
8612
8613
8614
8615
8616
8617
8618
8619
8620
8621
8622
8623
8624
8625
8626
8627
8628
8629
8630
 
 366
 367
 406
 738
 739
 776
 810
 811
 816
3400
3401
3440
3694
3695
3766
3767
4104
4138
4139
4176
4178
7569
7570
7605
7641
7642
7645
7899
7935
7936
7971
7975
8307
8308
8309
8343
8345
8379
8380
8381
8383
8385
 */

#endif
