import HDL
import MolecularRenderer

// Remaining tasks of this PR:
// - Implement the critical pixel count test; shouldn't take much time.
//   - Move the camera into the basis of the lattice, instead of the other
//     way around.
//   - Inspect the diamond and GaAs structures after compiling, to see the
//     cleaned up surfaces.
//   - Use a common lattice dimension for all structures. Start with a small
//     number, then scale it when other components of the test are working.
// - Clean up the documentation and implement the remaining tests.

let latticeSize: Float = 20
let material: MaterialType = .elemental(.carbon)
let is111: Bool = true

#if false
// Drafting the (111) basis vectors.
let basisX = SIMD3<Float>(1, 0, -1) / Float(2).squareRoot()
let basisY = SIMD3<Float>(-1, 2, -1) / Float(6).squareRoot()
let basisZ = SIMD3<Float>(1, 1, 1) / Float(3).squareRoot()
print((basisX * basisX).sum())
print((basisY * basisY).sum())
print((basisZ * basisZ).sum())
print((basisX * basisY).sum())
print((basisY * basisZ).sum())
print((basisZ * basisX).sum())
#endif

#if false
// Drafting the (110) basis vectors.
let basisX = SIMD3<Float>(1, 0, 0) / Float(1).squareRoot()
let basisY = SIMD3<Float>(0, 1, -1) / Float(2).squareRoot()
let basisZ = SIMD3<Float>(0, 1, 1) / Float(2).squareRoot()
print((basisX * basisX).sum())
print((basisY * basisY).sum())
print((basisZ * basisZ).sum())
print((basisX * basisY).sum())
print((basisY * basisZ).sum())
print((basisZ * basisX).sum())
#endif

// MARK: - Compile Structure

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

@MainActor
func createTopology() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { latticeSize * (h + k + l) }
    Material { .elemental(.carbon) }
    
    let frontPlaneDistance = latticeSize / 2
    let backPlaneDistance = frontPlaneDistance - 2
    
    Volume {
      if is111 {
        Convex {
          Origin { frontPlaneDistance * (h + k + l) }
          Plane { h + k + l }
        }
        Convex {
          Origin { backPlaneDistance * (h + k + l) }
          Plane { -h - k - l }
        }
      } else {
        Convex {
          Origin { frontPlaneDistance * (k + l) }
          Plane { k + l }
        }
        Convex {
          Origin { backPlaneDistance * (k + l) }
          Plane { -k - l }
        }
      }
      Replace { .empty }
    }
  }
  
  #if false
  
  // Temporary path to check the effect of Reconstruction on surfaces.
  var topology = Topology()
  topology.atoms = lattice.atoms
  
  #else
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = material
  var topology = reconstruction.compile()
  
  var canPassivate: Bool
  switch material {
  case .elemental(.carbon):
    canPassivate = true
  default:
    canPassivate = false
  }
  
  if is111 && canPassivate {
    passivate(topology: &topology)
  }
  
  #endif
  
  return topology
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
  displayDesc.frameBufferSize = SIMD2<Int>(1440, 1440)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 3
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 256
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

for atomID in topology.atoms.indices {
  let atom = topology.atoms[atomID]
  application.atoms[atomID] = atom
}

application.run {
  let latticeConstant = Constant(.square) { material }
  
  application.camera.position = SIMD3<Float>(
    latticeSize / 2 * latticeConstant,
    latticeSize / 2 * latticeConstant,
    latticeSize * 2 * latticeConstant)
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
