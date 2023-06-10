//
//  NanoEngineerParser.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 5/14/23.
//

import Foundation

// Inputs a file name from the bundle's resources, and outputs an array of
// `Atom` data structures.
//
// File format specification at:
// https://github.com/kanzure/nanoengineer/blob/master/cad/doc/old_doc/mmpformat
final class NanoEngineerParser: StaticAtomProvider {
  var atoms: [Atom]
  
  // You can omit the ".mmp" extension.
  // Example: "gears/MarkIII[k] Planetary Gear Box"
  convenience init(partLibPath: String) {
    let site = "https://raw.githubusercontent.com/kanzure/nanoengineer"
    let folder = "master/cad/partlib"
    
    var fullPath = "\(site)/\(folder)/\(partLibPath)"
    if fullPath.suffix(4) != ".mmp" {
      fullPath.append(".mmp")
    }
    self.init(url: URL(string: fullPath)!)
  }
  
  init(url: URL?) {
    guard let url else {
      fatalError("Must enter URL.")
    }
    
    let downloader = try! StaticDownloader(url: url)
    downloader.logLatency()
    let string = downloader.string
    
    let lines = string.split(separator: "\n").filter {
      $0.starts(with: "atom ")
    }
    self.atoms = lines.map { lineOriginal in
      var line = lineOriginal
      line.removeFirst("atom ".count)
      
      // Parse the atomic number.
      var leftParenthesisIndex = line.firstIndex(of: "(")!
      var rightParenthesisIndex = line.firstIndex(of: ")")!
      let numberIndex = line.index(after: leftParenthesisIndex)
      let numberRange = numberIndex..<rightParenthesisIndex
      let number = Int(line[numberRange])!
      
      // Parse the position text.
      let remainderIndex = line.index(after: rightParenthesisIndex)
      let remainderSlice = line[remainderIndex...]
      leftParenthesisIndex = remainderSlice.firstIndex(of: "(")!
      rightParenthesisIndex = remainderSlice.firstIndex(of: ")")!
      let positionIndex = remainderSlice.index(after: leftParenthesisIndex)
      let positionRange = positionIndex..<rightParenthesisIndex
      let positionSlice = remainderSlice[positionRange]
      
      // Extract the quantized position.
      var positionInt: SIMD3<Int64> = .zero
      let lines = positionSlice.split(separator: ", ")
      precondition(lines.count == 3, "Unexpected coordinate count.")
      for i in 0..<3 {
        positionInt[i] = Int64(lines[i])!
      }
      
      // Create the atom data structure.
      let quantizedToMeters: Float = 1e-13
      let metersToNanometers: Float = 1e9
      let scaleFactor = metersToNanometers * quantizedToMeters
      
      if number >= 1 && number <= 36 {
        return Atom(
          origin: scaleFactor * SIMD3<Float>(positionInt),
          element: UInt8(number))
      } else {
        return Atom(
          origin: scaleFactor * SIMD3<Float>(positionInt),
          element: UInt8(0), flags: 0x1 | 0x2)
      }
    }
  }
}
