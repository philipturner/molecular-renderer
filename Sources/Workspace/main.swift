// Clean up all repositories:
// - Integrate simulators into main as an 'add-simulators' branch.
//   - During this task, the pending minor maintenance to the simulator code
//     bases will be performed.
//   - Delete the built-in minimizer before the test.
//   - Test simple molecular dynamics of adamantane with MM4.
//   - Run the exact same test with GFN2-xTB and GFN-FF.
// - Implement the planned demo.
//   - Perhaps host the demo on both a GitHub gist, and the 'main.swift' of
//     this repo for the time being.
// - Begin the 'million-atom-scale' branch. Estimated to begin 5 days from now,
//   on Oct 6 2025.

import HDL
import MM4
import MolecularRenderer
import QuaternionModule

// MARK: - Compile Structure

let lattice = Lattice<Cubic> { h, k, l in
  Bounds { 1 * (h + k + l) }
  Material { .elemental(.carbon) }
}
var reconstruction = Reconstruction()
reconstruction.atoms = lattice.atoms
reconstruction.material = .elemental(.carbon)
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
let forceField = try! MM4ForceField(descriptor: forceFieldDesc)

// Utility function for calculating temperature.
@MainActor
func temperature(kineticEnergy: Double) -> Float {
  let energyInJ = kineticEnergy * 1e-21
  let energyPerAtom = Float(energyInJ / Double(topology.atoms.count))
  return energyPerAtom * 2 / (3 * 1.380649e-23)
}

// Analyze the energy over a few timesteps.
let frameCount: Int = 10
for frameID in 0...frameCount {
  // report statistics
  
  if frameID < frameCount {
    // perform time evolution
  }
}

// MARK: - Launch Application

#if false

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  displayDesc.frameBufferSize = SIMD2<Int>(1440, 1080)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.allocationSize = 10_000
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 3
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

@MainActor
func modifyAtoms() {
  let atoms = topology.atoms
  for atomID in atoms.indices {
    let atom = atoms[atomID]
    application.atoms[atomID] = atom
  }
}

@MainActor
func modifyCamera() {
  application.camera.position = SIMD3(0, 0, 2.00)
  
  application.camera.basis.0 = SIMD3(1, 0, 0)
  application.camera.basis.1 = SIMD3(0, 1, 0)
  application.camera.basis.2 = SIMD3(0, 0, 1)
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

#endif
