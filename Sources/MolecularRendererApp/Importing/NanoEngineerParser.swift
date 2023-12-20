//
//  NanoEngineerParser.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 5/14/23.
//

import Foundation
import MolecularRenderer

// Inputs a file name from the bundle's resources, and outputs an array of
// `Atom` data structures.
//
// File format specification at:
// https://github.com/kanzure/nanoengineer/blob/master/cad/doc/old_doc/mmpformat
final class NanoEngineerParser: MRAtomProvider {
  var _atoms: [MRAtom]
  
  func atoms(time: MRTime) -> [MRAtom] {
    return _atoms
  }
  
  // You can omit the ".mmp" extension.
  // Example: "gears/MarkIII[k] Planetary Gear Box"
  convenience init(partLibPath: String) {
    let site = "https://raw.githubusercontent.com/kanzure/nanoengineer"
    let folder = "master/cad/partlib"
    
    var fullPath = "\(site)/\(folder)/\(partLibPath)"
    if fullPath.suffix(4) != ".mmp" {
      fullPath.append(".mmp")
    }
    self.init(path: fullPath)
  }
  
  init(path: String) {
    let url = URL(string: path)!
    let downloader = try! Downloader(url: url)
    downloader.logLatency()
    let string = downloader.string
    
    var lines = string.split(separator: "\n").filter {
      $0.starts(with: "atom ")
    }
    if lines.count == 0 {
      lines = string.split(separator: "\r\n").filter {
        $0.starts(with: "atom ")
      }
    }
    self._atoms = lines.map { lineOriginal in
      var line = lineOriginal
      line.removeFirst("atom ".count)
      
      // Parse the atomic number.
      var leftParenthesisIndex = line.firstIndex(of: "(")!
      var rightParenthesisIndex = line.firstIndex(of: ")")!
      let numberIndex = line.index(after: leftParenthesisIndex)
      let numberRange = numberIndex..<rightParenthesisIndex
      let atomicNumber = Int(line[numberRange])!
      
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
      return MRAtom(
        origin: scaleFactor * SIMD3<Float>(positionInt),
        element: UInt8(atomicNumber))
    }
  }
}

