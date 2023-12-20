//
//  PDBParser.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/4/23.
//

import Foundation
import MolecularRenderer

final class PDBParser: MRAtomProvider {
  var _atoms: [MRAtom]
  
  func atoms(time: MRTime) -> [MRAtom] {
    return _atoms
  }
  
  init(url: URL, hasA1: Bool) {
    let data = try! Data(contentsOf: url)
    let string = String(data: data, encoding: .utf8)!
    var lines = string.split(separator: "\r\n").filter {
      $0.starts(with: "HETATM")
    }
    if lines.count == 0 {
      lines = string.split(separator: "\n").filter {
        $0.starts(with: "HETATM")
      }
    }
    
    self._atoms = lines.map { lineOriginal in
      var line = lineOriginal
      // Remove the "HETATM" header.
      removeExpectedPrefix("HETATM", from: &line)
      removeIncluding(" ", from: &line)
      
      // Remove the atom's index within the list of atoms.
      let indexRepr = extractExcluding(" ", from: &line)
      precondition(Int(indexRepr) != nil, "Invalid index repr.")
      removeIncluding(" ", from: &line)
      
      // Find the atom's identity on the periodic table.
      let symbol = extractExcluding(" ", from: &line)
      precondition(symbol.count > 0, "No element symbol.")
      guard let Z = Self.recognizedSymbols[symbol] else {
        fatalError("Unrecognized symbol: '\(symbol)'")
      }
      removeIncluding(" ", from: &line)
      
      // Remove the "A" and "1" text.
      if hasA1 {
        let A = extractExcluding(" ", from: &line)
        precondition(A == "A", "Unexpected formatting.")
        removeIncluding(" ", from: &line)
        
        let _1 = extractExcluding(" ", from: &line)
        precondition(_1 == "1", "Unexpected formatting.")
        removeIncluding(" ", from: &line)
      }
      
      // Extract the coordinates in Angstroms, then convert to nm.
      func extractNumber() -> Double {
        let repr = extractExcluding(" ", from: &line)
        removeIncluding(" ", from: &line)
        guard let number = Double(repr) else {
          fatalError("Invalid number repr: '\(repr)'")
        }
        return number
      }
      let x = extractNumber()
      let y = extractNumber()
      let z = extractNumber()
      if hasA1 {
        precondition(extractNumber() == 1.00, "Unexpected formatting.")
        precondition(extractNumber() == 0.00, "Unexpected formatting.")
      }
      
      // Ensure it ends with the same symbol it starts with.
      precondition(
        symbol == extractExcluding(" ", from: &line), "Unexpected formatting.")
      
      // Determine the color to present.
      let origin = SIMD3<Float>(SIMD3(x, y, z) / 10)
      return MRAtom(origin: origin, element: UInt8(Z))
    }
  }
  
  static let recognizedSymbols: [String: Int] = [
    "H" : 1,
    "C" : 6,
    "N" : 7,
    "Si": 14,
    "S" : 16,
    "Ge": 34,
    "Br": 35
  ]
}
