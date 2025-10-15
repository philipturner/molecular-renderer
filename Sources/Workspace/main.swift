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
// - Take a first pass at the rotating beam benchmark.

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

func createCross() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 10 * k + 5 * l }
    Material { .checkerboard(.silicon, .carbon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  
  return topology
}

let cross = createCross()
print()
print("atom count:", cross.atoms.count)
do {
  var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
  var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
  for atom in cross.atoms {
    let position = atom.position
    minimum.replace(with: position, where: position .< minimum)
    maximum.replace(with: position, where: position .> maximum)
  }
  print("minimum:", minimum - 0.853 / 10)
  print("maximum:", maximum + 0.853 / 10)
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
  
  applicationDesc.addressSpaceSize = 2_000_000
  applicationDesc.voxelAllocationSize = 200_000_000
  applicationDesc.worldDimension = 192
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

//#if true
//application.run {
//  for atomID in lattice.atoms.indices {
//    let atom = lattice.atoms[atomID]
//    application.atoms[atomID] = atom
//  }
//  
//  let image = application.render()
//  application.present(image: image)
//}
//#else
//
//@MainActor
//func analyzeGeneralCounters() {
//  let output = application.downloadGeneralCounters()
//  
//  print("atoms removed voxel count:", output[0])
//  guard output[1] == 1,
//        output[2] == 1 else {
//    fatalError("Indirect dispatch arguments were malformatted.")
//  }
//  print("vacant slot count:", output[4])
//  print("allocated slot count:", output[5])
//  print("rebuilt voxel count:", output[6])
//  guard output[7] == 1,
//        output[8] == 1 else {
//    fatalError("Indirect dispatch arguments were malformatted.")
//  }
//}
//
//for frameID in 0..<6 {
//  for atomID in lattice.atoms.indices {
//    let atom = lattice.atoms[atomID]
//    application.atoms[atomID] = atom
//  }
//  
//  application.checkCrashBuffer()
//  application.updateBVH(inFlightFrameID: frameID % 3)
//  application.forgetIdleState(inFlightFrameID: frameID % 3)
//  
//  print()
//  print("===============")
//  print("=== frame \(frameID) ===")
//  print("===============")
//  
//  print()
//  analyzeGeneralCounters()
//}
//
//#endif
