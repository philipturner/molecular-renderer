import Foundation
import HDL
import MolecularRenderer
import QuaternionModule
import xTB

// TODO: Debug the compilation process for setting up the structure. Use
// rendering to analyze the atom positions during this process.

// Take a look at the old code for working with DMS tooltips. Take a fresh
// approach to the structure generation, but copy the FIRE, Minimization, and
// serialization or disk-accessing utilities.

// Check that Serialization is accurately replaying the entire minimization
// trajectory on both platforms.

// MARK: - Compile Structure

let isAzastannatrane: Bool = false

var topology = Topology()
topology.atoms += [
  Atom(position: SIMD3(0.00, 0.00, 0.00), element: .tin),
  Atom(position: SIMD3(0.00, -0.26, -0.00), element: .nitrogen),
]

for legID in 0..<1 {
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
    
    // optional last carbon for azastannatrane
  }
  
  // Apply the rotation transform to all atoms, just before inserting.
  let angleDegrees = Float(legID) * 120 - 180
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
  displayDesc.frameBufferSize = SIMD2<Int>(1440, 1080)
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

// Set the atoms of the compiled structure(s) here.
//
// When debugging a trajectory, it will be easy to just set atoms during the
// run loop and animate by clock.frames.
for atomID in topology.atoms.indices {
  let atom = topology.atoms[atomID]
  application.atoms[atomID] = atom
}

// Set up the camera statically here.
application.camera.position = SIMD3(0, 0, 2)
application.camera.secondaryRayCount = 15 // eventually 64

application.run {
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}

// Reference code for saving a TIFF image.
#if false
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
#endif
