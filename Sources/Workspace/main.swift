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
//   - When done, migrate the test to the appropriate folder.
// - Work on the large scenes test next.

// MARK: - User-Facing Options

enum SurfaceType {
  // Hydrogen passivated C(111) surface
  case diamond111
  
  // Unpassivated C(110) surface
  case diamond110
  
  // Unpassivated GaAs(110) surface
  case galliumArsenide110
  
  // Au(111) surface
  case gold111
}
let surfaceType: SurfaceType = .diamond111
let secondaryRayCount: Int = 15
let criticalPixelCount: Float = 500

// MARK: - Compile Structure

func createMaterial() -> MaterialType {
  switch surfaceType {
  case .diamond111:
    return .elemental(.carbon)
  case .diamond110:
    return .elemental(.carbon)
  case .galliumArsenide110:
    return .checkerboard(.gallium, .arsenic)
  case .gold111:
    return .elemental(.gold)
  }
}

func createIs111() -> Bool {
  switch surfaceType {
  case .diamond111:
    return true
  case .diamond110:
    return false
  case .galliumArsenide110:
    return false
  case .gold111:
    return true
  }
}

let latticeSize: Float = 80
let material = createMaterial()
let is111 = createIs111()
do {
  let latticeConstant = Constant(.square) { material }
  let latticeSpan = latticeSize * latticeConstant
  let latticeSpanRepr = String(format: "%.3f", latticeSpan)
  print()
  print("The lattice spans \(latticeSpanRepr) nm along each cardinal axis.")
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
    Material { material }
    
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
  
  var canPassivate: Bool
  switch material {
  case .elemental(.carbon):
    canPassivate = true
  default:
    canPassivate = false
  }
  
  var canReconstruct: Bool
  switch material {
  case .elemental(.gold):
    canReconstruct = false
  default:
    canReconstruct = true
  }
    
  func createReconstructedTopology() -> Topology {
    if canReconstruct {
      var reconstruction = Reconstruction()
      reconstruction.atoms = lattice.atoms
      reconstruction.material = material
      return reconstruction.compile()
    } else {
      var topology = Topology()
      topology.atoms = lattice.atoms
      return topology
    }
  }
  
  var topology = createReconstructedTopology()
  if is111 && canPassivate {
    passivate(topology: &topology)
  }
  
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

@MainActor
func createTime() -> Float {
  let elapsedFrames = application.clock.frames
  let frameRate = application.display.frameRate
  let seconds = Float(elapsedFrames) / Float(frameRate)
  return seconds
}

@MainActor
func modifyCamera() {
  let latticeConstant = Constant(.square) { material }
  
  var basisX: SIMD3<Float>
  var basisY: SIMD3<Float>
  var basisZ: SIMD3<Float>
  if is111 {
    basisX = SIMD3<Float>(1, 0, -1) / Float(2).squareRoot()
    basisY = SIMD3<Float>(-1, 2, -1) / Float(6).squareRoot()
    basisZ = SIMD3<Float>(1, 1, 1) / Float(3).squareRoot()
  } else {
    basisX = SIMD3<Float>(1, 0, 0) / Float(1).squareRoot()
    basisY = SIMD3<Float>(0, 1, -1) / Float(2).squareRoot()
    basisZ = SIMD3<Float>(0, 1, 1) / Float(2).squareRoot()
  }
  application.camera.basis = (basisX, basisY, basisZ)
  
  var position = SIMD3<Float>(
    repeating: latticeSize / 2 * latticeConstant)
  
  // Shift the starting position 1.000 nm away from the surface.
  position += 1.000 * basisZ
  
  // Animate the camera moving away at 3 nm/s.
  // - Start at 1 nm away after 1 second pause for the FPS to stabilize.
  // - Stop at 50 nm away.
  let time = createTime()
  if time > 1 {
    let nmPerSecond: Float = 3
    let maxDistance: Float = 50
    
    var distance = nmPerSecond * (time - 1)
    distance = min(maxDistance - 1, distance)
    position += distance * basisZ
  }
  
  application.camera.position = position
  application.camera.secondaryRayCount = secondaryRayCount
  application.camera.criticalPixelCount = criticalPixelCount
}

for atomID in topology.atoms.indices {
  let atom = topology.atoms[atomID]
  application.atoms[atomID] = atom
}

application.run {
  modifyCamera()
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
