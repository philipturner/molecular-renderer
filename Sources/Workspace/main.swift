import HDL
import MM4
import MolecularRenderer
import QuaternionModule

// MARK: - Compile Structure

let lattice = Lattice<Cubic> { h, k, l in
  Bounds { 1 * (h + k + l) }
  Material { .checkerboard(.carbon, .silicon) }
}
var reconstruction = Reconstruction()
reconstruction.atoms = lattice.atoms
reconstruction.material = .checkerboard(.silicon, .carbon)
var topology = reconstruction.compile()

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
passivate(topology: &topology)
guard topology.atoms.count == 26,
      topology.bonds.count == 28 else {
  fatalError("Failed to compile adamantane.")
}

// MARK: - Run Simulation Analysis

// Make sure the MM4Parameters can be set up successfully.
var parametersDesc = MM4ParametersDescriptor()
parametersDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
parametersDesc.bonds = topology.bonds
let parameters = try! MM4Parameters(descriptor: parametersDesc)

// Set up the MM4ForceField.
var forceFieldDesc = MM4ForceFieldDescriptor()
forceFieldDesc.parameters = parameters
var forceField = try! MM4ForceField(descriptor: forceFieldDesc)
forceField.positions = topology.atoms.map(\.position)
forceField.timeStep = 0.001

guard forceField.energy.kinetic == 0 else {
  fatalError("Force field kinetic energy was not exactly zero.")
}

// Utility function for calculating temperature.
@MainActor
func temperature(kineticEnergy: Double) -> Float {
  let energyInJ = kineticEnergy * 1e-21
  let energyPerAtom = Float(energyInJ / Double(topology.atoms.count))
  return energyPerAtom * 2 / (3 * 1.380649e-23)
}

// Analyze the energy over a few timesteps.
let frameTimeInterval: Float = 0.002
for frameID in 0...10 {
  // report statistics
  print()
  print("frame ID = \(frameID)")
  
  let time = Float(frameID) * frameTimeInterval
  let timeRepr = String(format: "%.3f", time)
  print("time = \(timeRepr) ps")
  
  let kinetic = forceField.energy.kinetic
  let kineticRepr = String(format: "%.1f", kinetic)
  print("kinetic energy = \(kineticRepr) zJ")
  
  let potential = forceField.energy.potential
  let potentialRepr = String(format: "%.1f", potential)
  print("potential energy = \(potentialRepr) zJ")
  
  let totalEnergy = kinetic + potential
  let totalEnergyRepr = String(format: "%.1f", totalEnergy)
  print("total energy = \(totalEnergyRepr) zJ")
  
  let temperature = temperature(kineticEnergy: kinetic)
  let temperatureRepr = String(format: "%.1f", temperature)
  print("temperature = \(temperatureRepr) K")
  
  guard temperature < 1000 else {
    fatalError("Temperature exceeded 1000 K or was NaN.")
  }
  
  if frameID < 10 {
    // perform time evolution
    forceField.simulate(time: Double(frameTimeInterval))
  }
}

guard forceField.energy.kinetic > 0 else {
  fatalError("Force field kinetic energy was zero.")
}

// Separate the console diagnostics for the two simulation runs.
print()

// Need to create a completely new force field to reset the OpenMM internal
// state. Confirmed that this previous-state dependence bug is a fault of
// OpenMM, not my code. The kinetic energy does decrease when you erase the
// velocities, although not all the way to 0 zJ.
forceField = try! MM4ForceField(descriptor: forceFieldDesc)
forceField.positions = topology.atoms.map(\.position)
forceField.velocities = [SIMD3<Float>](
  repeating: .zero, count: topology.atoms.count)
forceField.timeStep = 0.001

guard forceField.energy.kinetic == 0 else {
  fatalError("Force field kinetic energy was not exactly zero.")
}

// Gather frames for a basic test animation.
// 201 frames, 50 Hz frame displaying, will interpolate the time
var frames: [[Atom]] = []
for frameID in 0...200 {
  var atoms: [Atom] = []
  for atomID in topology.atoms.indices {
    let position = forceField.positions[atomID]
    let element = topology.atoms[atomID].element
    let atom = Atom(position: position, element: element)
    atoms.append(atom)
  }
  frames.append(atoms)
  
  let time = Float(frameID) * frameTimeInterval
  let timeRepr = String(format: "%.3f", time)
  
  let kinetic = forceField.energy.kinetic
  let potential = forceField.energy.potential
  let totalEnergy = kinetic + potential
  let totalEnergyRepr = String(format: "%.1f", totalEnergy)
  
  let temperature = temperature(kineticEnergy: kinetic)
  let temperatureRepr = String(format: "%.1f", temperature)
  print("t = \(timeRepr) ps, energy = \(totalEnergyRepr) zJ, temp = \(temperatureRepr) K")
  
  guard temperature < 1000 else {
    fatalError("Temperature exceeded 1000 K or was NaN.")
  }
  
  if frameID < 200 {
    forceField.simulate(time: Double(frameTimeInterval))
  }
}

guard forceField.energy.kinetic > 0 else {
  fatalError("Force field kinetic energy was zero.")
}

// Input: time in seconds
// Output: atoms
@MainActor
func interpolate(time: Float) -> [Atom] {
  let multiple50Hz = time * 50
  var lowFrame = Int(multiple50Hz.rounded(.down))
  var highFrame = lowFrame + 1
  var lowInterpolationFactor = Float(highFrame) - multiple50Hz
  var highInterpolationFactor = multiple50Hz - Float(lowFrame)
  
  if lowFrame < -1 {
    fatalError("This should never happen.")
  }
  if lowFrame >= 200 {
    lowFrame = 200
    highFrame = 200
    lowInterpolationFactor = 1
    highInterpolationFactor = 0
  }
  
  var output: [Atom] = []
  for atomID in topology.atoms.indices {
    let lowAtom = frames[lowFrame][atomID]
    let highAtom = frames[highFrame][atomID]
    
    var position: SIMD3<Float> = .zero
    position += lowAtom.position * lowInterpolationFactor
    position += highAtom.position * highInterpolationFactor
    
    let element = topology.atoms[atomID].element
    let atom = Atom(position: position, element: element)
    output.append(atom)
  }
  return output
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
  displayDesc.frameBufferSize = SIMD2<Int>(1080, 1440)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 3
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 64
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
func modifyAtoms() {
  let time = createTime()
  if time < 2 {
    let atoms = topology.atoms
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      application.atoms[atomID] = atom
    }
  } else {
    let atoms = interpolate(time: time - 2)
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      application.atoms[atomID] = atom
    }
  }
}

@MainActor
func modifyCamera() {
  // Add user option for avoiding graphical bug on Windows.
  let time = createTime()
  let angleDegrees = 0.005 * time * 360
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * angleDegrees,
    axis: SIMD3(0, 1, 0))
  
  application.camera.position = rotation.act(on: SIMD3(0.20, 0.20, 1.40))
  
  application.camera.basis.0 = rotation.act(on: SIMD3(1, 0, 0))
  application.camera.basis.1 = rotation.act(on: SIMD3(0, 1, 0))
  application.camera.basis.2 = rotation.act(on: SIMD3(0, 0, 1))
  application.camera.fovAngleVertical = Float.pi / 180 * 60
}

// Enter the run loop.
application.run {
  modifyAtoms()
  modifyCamera()
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
