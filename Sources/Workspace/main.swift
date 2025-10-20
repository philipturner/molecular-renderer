import HDL
import MolecularRenderer

// Remaining tasks of this PR:
// - Implement 32 nm scoping to further optimize the per-dense-voxel cost.
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

/*
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
*/

import Foundation
import HDL
import MolecularRenderer
import QuaternionModule

// Current task:
// - Archive the current state of the rotating beam benchmark in Tests.
// - Clean up the backend code, archive 'checkExecutionTime' to a GitHub gist.
// - That will conclude the implementation of the BVH update process.

// MARK: - Compile Structures

func passivate(topology: inout Topology) {
  func createHydrogen(
    atomID: UInt32,
    orbital: SIMD3<Float>
  ) -> Atom {
    let atom = topology.atoms[Int(atomID)]
    
    var bondLength = atom.element.covalentRadius
    bondLength += Element.hydrogen.covalentRadius
    
    let position = atom.position + bondLength * orbital
    return Atom(position: position, element: .hydrogen)
  }
  
  let orbitalLists = topology.nonbondingOrbitals()
  
  var insertedAtoms: [Atom] = []
  var insertedBonds: [SIMD2<UInt32>] = []
  for atomID in topology.atoms.indices {
    let orbitalList = orbitalLists[atomID]
    for orbital in orbitalList {
      let hydrogen = createHydrogen(
        atomID: UInt32(atomID),
        orbital: orbital)
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      insertedAtoms.append(hydrogen)
      
      let bond = SIMD2(
        UInt32(atomID),
        UInt32(hydrogenID))
      insertedBonds.append(bond)
    }
  }
  topology.atoms += insertedAtoms
  topology.bonds += insertedBonds
}

let crossThickness: Int = 16
let crossSize: Int = 120
let beamDepth: Int = 2
let worldDimension: Float = 96

func createCross() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds {
      Float(crossSize) * h +
      Float(crossSize) * k +
      Float(2) * l
    }
    Material { .checkerboard(.silicon, .carbon) }
    
    for isPositiveX in [false, true] {
      for isPositiveY in [false, true] {
        let halfSize = Float(crossSize) / 2
        let center = halfSize * h + halfSize * k
        
        let directionX = isPositiveX ? h : -h
        let directionY = isPositiveY ? k : -k
        let halfThickness = Float(crossThickness) / 2
        
        Volume {
          Concave {
            Convex {
              Origin { center + halfThickness * directionX }
              Plane { isPositiveX ? h : -h }
            }
            Convex {
              Origin { center + halfThickness * directionY }
              Plane { isPositiveY ? k : -k }
            }
          }
          Replace { .empty }
        }
      }
    }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    
    // This offset captures just one Si and one C for each unit cell on the
    // (001) surface. By capture, I mean that atom.position.z > 0. We want a
    // small number of static atoms in a 2 nm voxel that overlaps some moving
    // atoms.
    atom.position += SIMD3(0, 0, -0.800)
    
    // Shift the origin to allow larger beam depth, with fixed world dimension.
    atom.position.z -= worldDimension / 2
    atom.position.z += 8
    
    // Shift so the structure is centered in X and Y.
    let latticeConstant = Constant(.square) {
      .checkerboard(.silicon, .carbon)
    }
    let halfSize = Float(crossSize) / 2
    atom.position.x -= halfSize * latticeConstant
    atom.position.y -= halfSize * latticeConstant
    
    topology.atoms[atomID] = atom
  }
  
  return topology
}

func createBeam() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds {
      Float(crossThickness) * h +
      Float(crossSize) * k +
      Float(beamDepth) * l
    }
    Material { .checkerboard(.silicon, .carbon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    
    // Capture just one Si and one C for each unit cell. This time, capturing
    // happens if atom.position.z < 0.
    atom.position += SIMD3(0, 0, -0.090)
    
    // Shift so both captured surfaces fall in the [0, 2] nm range for sharing
    // a voxel.
    atom.position.z += 2
    
    // Shift the origin to allow larger beam depth, with fixed world dimension.
    atom.position.z -= worldDimension / 2
    atom.position.z += 8
    
    // Shift so the structure is centered in X and Y.
    let latticeConstant = Constant(.square) {
      .checkerboard(.silicon, .carbon)
    }
    let halfThickness = Float(crossThickness) / 2
    let halfSize = Float(crossSize) / 2
    atom.position.x -= halfThickness * latticeConstant
    atom.position.y -= halfSize * latticeConstant
    
    topology.atoms[atomID] = atom
  }
  
  return topology
}

func analyze(topology: Topology) {
  print()
  print("atom count:", topology.atoms.count)
  do {
    var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    for atom in topology.atoms {
      let position = atom.position
      minimum.replace(with: position, where: position .< minimum)
      maximum.replace(with: position, where: position .> maximum)
    }
    print("minimum:", minimum)
    print("maximum:", maximum)
  }
}

let cross = createCross()
let beam = createBeam()
analyze(topology: cross)
analyze(topology: beam)

// MARK: - Rotation Animation

@MainActor
func createRotatedBeam(frameID: Int) -> Topology {
  // 0.5 Hz -> 3 degrees/frame @ 60 Hz
  //
  // WARNING: Systems with different display refresh rates may have different
  // benchmark results. The benchmark should be robust to this variation in
  // degrees/frame.
  //
  // Solution: animate by clock.frames instead of the actual time. On 120 Hz
  // systems, the benchmark will rotate 2x faster than on 60 Hz systems.
  let angleDegrees: Float = 3 * Float(frameID)
  let rotation = Quaternion<Float>(
    angle: angleDegrees * Float.pi / 180,
    axis: SIMD3(0, 0, 1))
  
  // Circumvent a massive CPU-side bottleneck from 'rotation.act()'.
  let basis0 = rotation.act(on: SIMD3<Float>(1, 0, 0))
  let basis1 = rotation.act(on: SIMD3<Float>(0, 1, 0))
  let basis2 = rotation.act(on: SIMD3<Float>(0, 0, 1))
  
  let start = Date()
  var topology = beam
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    
    var rotatedPosition: SIMD3<Float> = .zero
    rotatedPosition += basis0 * atom.position[0]
    rotatedPosition += basis1 * atom.position[1]
    rotatedPosition += basis2 * atom.position[2]
    atom.position = rotatedPosition
    
    topology.atoms[atomID] = atom
  }
  let end = Date()
  let rotateLatency = end.timeIntervalSince(start)
  let rotateLatencyMicroseconds = Int(rotateLatency * 1e6)
  print("rotate:", rotateLatencyMicroseconds, "μs")
  
  return topology
}

// MARK: - Launch Application

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
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = worldDimension
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

#if false
application.run {
  let image = application.render()
  application.present(image: image)
}
#else

@MainActor
func analyzeGeneralCounters() {
  let output = application.downloadGeneralCounters()
  
  for region in GeneralCountersRegion.allCases {
    let offset = GeneralCounters.offset(region)
    print("\(region): \(output[offset / 4])")
    
    if region == .vacantSlotCount {
        continue
    }
    if region == .allocatedSlotCount {
      continue
    }
    guard output[offset / 4 + 1] == 1,
          output[offset / 4 + 2] == 1 else {
      fatalError("Indirect dispatch arguments were malformatted.")
    }
    print("validated integrity of dispatch arguments: \(region)")
  }
}

for atomID in cross.atoms.indices {
  let atom = cross.atoms[atomID]
  application.atoms[atomID] = atom
}

for frameID in 0..<16 {
  print()
  print("===============")
  print("=== frame \(frameID) ===")
  print("===============")

  print()
  print("rotation: \(frameID * 3) degrees")
  
  let rotatedBeam = createRotatedBeam(frameID: frameID)
  for atomID in rotatedBeam.atoms.indices {
    let atom = rotatedBeam.atoms[atomID]
    let offset = cross.atoms.count
    application.atoms[offset + atomID] = atom
  }
  
  application.checkCrashBuffer(frameID: frameID)
  application.checkExecutionTime(frameID: frameID)
  application.updateBVH(inFlightFrameID: frameID % 3)
  application.forgetIdleState(inFlightFrameID: frameID % 3)
  
  print()
  analyzeGeneralCounters()
}

#endif
