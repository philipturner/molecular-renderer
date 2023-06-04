//
//  PDBParser.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/4/23.
//

import Foundation

final class PDBParser: ParserProtocol {
  var atoms: [Atom]
  
  init(url: URL) {
    let data = try! Data(contentsOf: url)
    let string = String(data: data, encoding: .utf8)!
    let lines = string.split(separator: "\r\n").filter {
      $0.starts(with: "HETATM")
    }
    
    self.atoms = lines.map { lineOriginal in
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
      do {
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
      precondition(extractNumber() == 1.00, "Unexpected formatting.")
      precondition(extractNumber() == 0.00, "Unexpected formatting.")
      
      // Ensure it ends with the same symbol it starts with.
      precondition(
        symbol == extractExcluding(" ", from: &line), "Unexpected formatting.")
      
      // Determine the color to present.
      var element: UInt8
      var flags: UInt8
      if Z <= 36 {
        element = UInt8(Z)
        flags = 0
      } else {
        // Treat unrecognized elements as chlorine with checkerboard color.
        element = 17
        flags = 0x1 | 0x2
      }
      
      let origin = SIMD3<Float>(SIMD3(x, y, z) / 10)
      return Atom(
        origin: origin, element: element, flags: flags)
    }
    
    for atom in atoms {
      print(atom)
    }
  }
  
  static let recognizedSymbols: [String: Int] = [
    "H" : 1,
    "C" : 6,
    "S" : 16,
    "Br": 35
  ]
}
