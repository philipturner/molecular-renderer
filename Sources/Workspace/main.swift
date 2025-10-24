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
