import HDL
import MM4
import MolecularRenderer

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

func createTopology() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * (h + k + l) }
    Material { .checkerboard(.carbon, .silicon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  return topology
}
let topology = createTopology()

// MARK: - Run Minimization

// Utility for logging quantities to the console.
struct Format {
  static func pad(_ x: String, to size: Int) -> String {
    var output = x
    while output.count < size {
      output = " " + output
    }
    return output
  }
  static func time<T: BinaryFloatingPoint>(_ x: T) -> String {
    let xInFs = Float(x) * 1e3
    var repr = String(format: "%.2f", xInFs) + " fs"
    repr = pad(repr, to: 9)
    return repr
  }
  static func energy(_ x: Double) -> String {
    var repr = String(format: "%.2f", x / 160.218) + " eV"
    repr = pad(repr, to: 13)
    return repr
  }
  static func force(_ x: Float) -> String {
    var repr = String(format: "%.2f", x) + " pN"
    repr = pad(repr, to: 13)
    return repr
  }
  static func distance(_ x: Float) -> String {
    var repr = String(format: "%.2f", x) + " nm"
    repr = pad(repr, to: 9)
    return repr
  }
}

var paramsDesc = MM4ParametersDescriptor()
paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
paramsDesc.bonds = topology.bonds
let parameters = try! MM4Parameters(descriptor: paramsDesc)

var forceFieldDesc = MM4ForceFieldDescriptor()
forceFieldDesc.parameters = parameters
let forceField = try! MM4ForceField(descriptor: forceFieldDesc)

var minimizationDesc = FIREMinimizationDescriptor()
minimizationDesc.masses = parameters.atoms.masses
minimizationDesc.positions = topology.atoms.map(\.position)
var minimization = FIREMinimization(descriptor: minimizationDesc)

var frames: [[SIMD4<Float>]] = []
@MainActor
func createFrame() -> [Atom] {
  var output: [SIMD4<Float>] = []
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    atom.position = minimization.positions[atomID]
    output.append(atom)
  }
  return output
}

let maxIterationCount: Int = 500
for trialID in 0..<maxIterationCount {
  frames.append(createFrame())
  forceField.positions = minimization.positions
  
  let forces = forceField.forces
  var maximumForce: Float = .zero
  for atomID in topology.atoms.indices {
    let force = forces[atomID]
    let forceMagnitude = (force * force).sum().squareRoot()
    maximumForce = max(maximumForce, forceMagnitude)
  }
  
  let energy = forceField.energy.potential
  print("time: \(Format.time(minimization.time))", terminator: " | ")
  print("energy: \(Format.energy(energy))", terminator: " | ")
  print("max force: \(Format.force(maximumForce))", terminator: " | ")
  
  let converged = minimization.step(forces: forces)
  if !converged {
    print("Δt: \(Format.time(minimization.Δt))", terminator: " | ")
  }
  print()
  
  if converged {
    print("converged at trial \(trialID)")
    frames.append(createFrame())
    break
  } else if trialID == maxIterationCount - 1 {
    print("failed to converge!")
  }
}

// MARK: - Launch Application

// Input: time in seconds
// Output: atoms
@MainActor
func interpolate(
  frames: [[Atom]],
  time: Float
) -> [Atom] {
  let multiple25Hz = time * 25
  var lowFrame = Int(multiple25Hz.rounded(.down))
  var highFrame = lowFrame + 1
  var lowInterpolationFactor = Float(highFrame) - multiple25Hz
  var highInterpolationFactor = multiple25Hz - Float(lowFrame)
  
  if lowFrame < -1 {
    fatalError("This should never happen.")
  }
  if lowFrame >= frames.count - 1 {
    lowFrame = frames.count - 1
    highFrame = frames.count - 1
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
  let delayTime: Float = 1
  let animationEndTime: Float = delayTime + Float(frames.count) / 25
  
  if time < delayTime {
    let atoms = topology.atoms
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      application.atoms[atomID] = atom
    }
  } else if time < animationEndTime {
    let atoms = interpolate(
      frames: frames,
      time: time - delayTime)
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      application.atoms[atomID] = atom
    }
  } else {
    let atoms = frames.last!
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      application.atoms[atomID] = atom
    }
  }
}

@MainActor
func modifyCamera() {
  let basisX = SIMD3<Float>(1, 0, 0) / Float(1).squareRoot()
  let basisY = SIMD3<Float>(0, 1, -1) / Float(2).squareRoot()
  let basisZ = SIMD3<Float>(0, 1, 1) / Float(2).squareRoot()
  application.camera.basis = (basisX, basisY, basisZ)
  
  let latticeConstant = Constant(.square) {
    .checkerboard(.silicon, .carbon)
  }
  let halfSize = latticeConstant * 5
  
  application.camera.position = SIMD3<Float>(
    halfSize,
    3.5 * halfSize,
    3.5 * halfSize)
}

// Enter the run loop.
application.run {
  modifyAtoms()
  modifyCamera()
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
