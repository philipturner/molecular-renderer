import HDL
import MolecularRenderer
import QuaternionModule

// Remaining tasks of this PR:
// - Attempt to render objects far enough to apply to critical pixel count
//   heuristic.
//   - Implement the long distances test now.
// - Implement fully optimized primary ray intersector from main-branch-backup.
// - Implement 32 nm scoping to further optimize the per-dense-voxel cost.
//   Then, see whether this can benefit the primary ray intersector for large
//   distances.

// MARK: - Compile Structure

let latticeSizeXY: Float = 10
let latticeSizeZ: Float = 2

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
let topology = createTopology()

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
  applicationDesc.upscaleFactor = 3
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 32
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
  let halfSize = latticeConstant * 5
  application.camera.position = SIMD3<Float>(
    halfSize,
    halfSize,
    halfSize + 2 * halfSize)
  application.camera.fovAngleVertical = Float.pi / 180 * 90
  
  let time = createTime()
  let angleDegrees = 0.1 * time * 360
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * -angleDegrees,
    axis: SIMD3(0, 0, 1))
  application.camera.basis.0 = rotation.act(on: SIMD3(1, 0, 0))
  application.camera.basis.1 = rotation.act(on: SIMD3(0, 1, 0))
  application.camera.basis.2 = rotation.act(on: SIMD3(0, 0, 1))
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
