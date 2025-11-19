import Foundation
import HDL
import MolecularRenderer
import QuaternionModule
import xTB

xTB_Environment.verbosity = .muted

// MARK: - Compile Structure

// Passivate only the carbon atoms.
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
    let atom = topology.atoms[atomID]
    guard atom.atomicNumber == 6 else {
      continue
    }
    
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

func createTripod(
  isAzastannatrane: Bool
) -> Topology {
  var topology = Topology()
  topology.atoms += [
    Atom(position: SIMD3(0.00, 0.00, 0.00), element: .tin),
    Atom(position: SIMD3(0.00, -0.26, -0.00), element: .nitrogen),
  ]
  
  for legID in 0..<3 {
    let baseAtomID = topology.atoms.count
    var insertedAtoms: [Atom] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    
    // Isolate the temporary variables for this part in a contained scope.
    do {
      let carbon0 = Atom(
        position: SIMD3(0.15, -0.28, 0.00), element: .carbon)
      insertedAtoms.append(carbon0)
      insertedBonds.append(
        SIMD2(UInt32(1), UInt32(baseAtomID + 0)))
      
      let carbon1 = Atom(
        position: SIMD3(0.23, -0.15, -0.05), element: .carbon)
      insertedAtoms.append(carbon1)
      insertedBonds.append(
        SIMD2(UInt32(baseAtomID + 0), UInt32(baseAtomID + 1)))
      
      let nitrogen2 = Atom(
        position: SIMD3(0.23, -0.00, 0.00),
        element: isAzastannatrane ? .nitrogen : .carbon)
      insertedAtoms.append(nitrogen2)
      insertedBonds.append(
        SIMD2(UInt32(baseAtomID + 1), UInt32(baseAtomID + 2)))
      insertedBonds.append(
        SIMD2(UInt32(baseAtomID + 2), UInt32(0)))
      
      let carbon3 = Atom(
        position: SIMD3(0.38, -0.20, -0.05), element: .carbon)
      insertedAtoms.append(carbon3)
      insertedBonds.append(
        SIMD2(UInt32(baseAtomID + 1), UInt32(baseAtomID + 3)))
      
      let sulfur4 = Atom(
        position: SIMD3(0.45, -0.36, -0.05), element: .sulfur)
      insertedAtoms.append(sulfur4)
      insertedBonds.append(
        SIMD2(UInt32(baseAtomID + 3), UInt32(baseAtomID + 4)))
      
      let hydrogen5 = Atom(
        position: SIMD3(0.57, -0.36, -0.05), element: .hydrogen)
      insertedAtoms.append(hydrogen5)
      insertedBonds.append(
        SIMD2(UInt32(baseAtomID + 4), UInt32(baseAtomID + 5)))
    }
    
    if isAzastannatrane {
      let carbon6 = Atom(
        position: SIMD3(0.32, 0.08, -0.05), element: .carbon)
      insertedAtoms.append(carbon6)
      insertedBonds.append(
        SIMD2(UInt32(baseAtomID + 2), UInt32(baseAtomID + 6)))
      
      let hydrogen7 = Atom(
        position: SIMD3(0.32, 0.20, -0.05), element: .hydrogen)
      insertedAtoms.append(hydrogen7)
      insertedBonds.append(
        SIMD2(UInt32(baseAtomID + 6), UInt32(baseAtomID + 7)))
    }
    
    // Apply the rotation transform to all atoms, just before inserting.
    let angleDegrees = Float(legID) * 120 - 30
    let rotation = Quaternion<Float>(
      angle: Float.pi / 180 * angleDegrees,
      axis: SIMD3(0, 1, 0))
    for relativeAtomID in insertedAtoms.indices {
      var atom = insertedAtoms[relativeAtomID]
      atom.position = rotation.act(on: atom.position)
      insertedAtoms[relativeAtomID] = atom
    }
    topology.atoms += insertedAtoms
    topology.bonds += insertedBonds
  }
  
  // Don't forget the feedstock.
  topology.atoms += [
    Atom(position: SIMD3(0.00, 0.19, 0.00), element: .hydrogen),
  ]
  
  passivate(topology: &topology)
  return topology
}

func createCarbatranePositions() -> [Atom] {
  let topology = createTripod(isAzastannatrane: false)
  let trajectory = loadCachedTrajectory(tripod: topology)
  guard trajectory.count > 0 else {
    fatalError("No starting structure to render.")
  }
  return trajectory.last!
}

func createAzatranePositions() -> [Atom] {
  let topology = createTripod(isAzastannatrane: true)
  let trajectory = loadCachedTrajectory(tripod: topology)
  guard trajectory.count > 0 else {
    fatalError("No starting structure to render.")
  }
  return trajectory.last!
}

let carbatranePositions = createCarbatranePositions()
let azatranePositions = createAzatranePositions()

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
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 1
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 64
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

// Set the atoms of the compiled structure(s) here.
//
// Render static image showing both side and top view.
var baseAtomID: Int = .zero
for structureID in 0..<4 {
  let angleDegrees = Float(90)
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * angleDegrees,
    axis: SIMD3(1, 0, 0))
  
  var positions: [Atom]
  if structureID < 2 {
    positions = carbatranePositions
  } else {
    positions = azatranePositions
  }
  
  for atomID in positions.indices {
    var atom = positions[atomID]
   
    // Apply the rotation before messing with any translations.
    if structureID % 2 == 1 {
      atom.position = rotation.act(on: atom.position)
    }
    
    let separationDistanceX: Float = 1.5
    let separationDistanceY: Float = 1.5
    if structureID < 2 {
      atom.x -= separationDistanceX / 2
    } else {
      atom.x += separationDistanceX / 2
    }
    if structureID % 2 == 0 {
      atom.y -= separationDistanceY / 2
    } else {
      atom.y += separationDistanceY / 2
    }
    
    application.atoms[baseAtomID + atomID] = atom
  }
  
  baseAtomID += positions.count
}

// Set up the camera statically here.
application.camera.position = SIMD3(0, 0, 9)
application.camera.fovAngleVertical = Float.pi / 180 * 20
application.camera.secondaryRayCount = 64

do {
  let image = application.render()
  let frameBufferSize = application.display.frameBufferSize
  let pixelCount = frameBufferSize[0] * frameBufferSize[1]
  guard image.pixels.count == pixelCount else {
    fatalError("Invalid pixel buffer size.")
  }
  
  // Create the header.
  let header = """
  P6
  \(frameBufferSize[0]) \(frameBufferSize[1])
  255
  
  """
  let headerData = header.data(using: .utf8)!
  
  // Convert the pixels from FP16 to UInt8.
  var output: [UInt8] = []
  for pixel in image.pixels {
    let scaled = pixel * 255
    var rounded = scaled.rounded(.toNearestOrEven)
    rounded.replace(
      with: SIMD4<Float16>(repeating: 0),
      where: rounded .< 0)
    rounded.replace(
      with: SIMD4<Float16>(repeating: 255),
      where: rounded .> 255)
    
    let integerValue = SIMD4<UInt8>(rounded)
    output.append(integerValue[0])
    output.append(integerValue[1])
    output.append(integerValue[2])
  }
  let outputData = output.withUnsafeBufferPointer { bufferPointer in
    Data(buffer: bufferPointer)
  }
  
  // Write to the file. The forward slash usage is safe on Windows.
  let ppmData = headerData + outputData
  let packagePath = FileManager.default.currentDirectoryPath
  let filePath = "\(packagePath)/.build/image.ppm"
  let succeeded = FileManager.default.createFile(
    atPath: filePath,
    contents: ppmData)
  guard succeeded else {
    fatalError("Could not write to file.")
  }
}
