import HDL
import MolecularRenderer
import QuaternionModule

// Remaining tasks of this PR:
// - Implement the "rigorous test" described in the next section, prior to
//   starting work on the better intersector.
//   - Archive the current code somewhere. Perhaps the "LongDistances" file in
//     the Tests directory of this repo.
// - Implement 8 nm scoped primary ray intersector from main-branch-backup.
//   - Start off with 2 nm scoped. Ensure correctness and gather perf data.
//   - Then, implement the 8 nm skipping optimization.
//   - Use a rotating lattice + rotating camera to rigorously assert
//     correct behavior of the optimized primary ray intersector, prior to
//     gathering benchmarks at any step of development. There could be
//     a bug that treats different axes and directions differently.
//   - The test should be run on a few permutations of quaternion directions,
//     perhaps chosen at random and just tested multiple times. This test will
//     be carefully set up and probably valuable to archive on a GitHub gist.
// - Implement the critical pixel count heuristic.
// - Implement 32 nm scoping to further optimize the per-dense-voxel cost.
//   Then, see whether this can benefit the primary ray intersector for large
//   distances.

// MARK: - Compile Structure

// Use these parameters to guarantee correct functioning of the 2 nm scoped
// primary ray intersector.
let latticeSizeXY: Float = 64
let latticeSizeZ: Float = 2
let screenDimension: Int = 1440
let worldDimension: Float = 256
do {
  let latticeConstant = Constant(.square) {
    .elemental(.silicon)
  }
  
  // The lattice is not rotating; the camera is. No need to increase this
  // by a factor of sqrt(2).
  let latticeSpan = latticeSizeXY * latticeConstant
  guard latticeSpan < 0.9 * worldDimension else {
    fatalError("Lattice was too large for the world.")
  }
}

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

func createTopology() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds {
      latticeSizeXY * h +
      latticeSizeXY * k +
      latticeSizeZ * l
    }
    Material { .elemental(.silicon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .elemental(.silicon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  
  // Shift the lattice so it's centered in XY and flush with Z = 0.
  let latticeConstant = Constant(.square) {
    .elemental(.silicon)
  }
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    atom.position.x -= (latticeSizeXY / 2) * latticeConstant
    atom.position.y -= (latticeSizeXY / 2) * latticeConstant
    atom.position.z -= latticeSizeZ * latticeConstant
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

let topology = createTopology()
analyze(topology: topology)

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
  displayDesc.frameBufferSize = SIMD2<Int>(repeating: screenDimension)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 3
  
  applicationDesc.addressSpaceSize = 6_000_000
  applicationDesc.voxelAllocationSize = 3_000_000_000
  applicationDesc.worldDimension = worldDimension
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

@MainActor
func createTime() -> Float {
  let elapsedFrames = application.clock.frames
  let frameRate = application.display.frameRate
  let seconds = Float(elapsedFrames) / Float(frameRate)
  return seconds
}

@MainActor
func modifyCamera() {
  let latticeConstant = Constant(.square) {
    .elemental(.silicon)
  }
  application.camera.position = SIMD3<Float>(
    0,
    0,
    (latticeSizeXY / 3) * latticeConstant)
  application.camera.fovAngleVertical = Float.pi / 180 * 90
  application.camera.secondaryRayCount = nil
  
  let time = createTime()
  let angleDegrees = 0.1 * time * 360
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * -angleDegrees,
    axis: SIMD3(0, 0, 1))
  application.camera.basis.0 = rotation.act(on: SIMD3(1, 0, 0))
  application.camera.basis.1 = rotation.act(on: SIMD3(0, 1, 0))
  application.camera.basis.2 = rotation.act(on: SIMD3(0, 0, 1))
}

application.run {
  #if true
  modifyCamera()
  
  var startIndex = application.frameID * 1_000_000
  var endIndex = startIndex + 1_000_000
  startIndex = min(startIndex, topology.atoms.count)
  endIndex = min(endIndex, topology.atoms.count)
  for atomID in startIndex..<endIndex {
    guard atomID < application.atoms.addressSpaceSize else {
      fatalError("Exceeded address space size.")
    }
    
    let atom = topology.atoms[atomID]
    application.atoms[atomID] = atom
  }
  #endif
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
