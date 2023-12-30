//
//  XTBProcess.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/30/23.
//

import Foundation
import HDL
import MolecularRenderer

let XTBNmPerBohr: Double = 0.0529177
let XTBBohrPerNm: Double = 1 / XTBNmPerBohr

enum XTBError: Error {
  // An error containing an identifying number (such as line or atom index) and
  // a descriptive message.
  case invalidFormatting(Int, String)
}

// A better API centered around 'HDL.Entity'. This invokes xTB by launching
// processes. It can also be used in hybrid scripting + command-line workflows,
// where scripting just automates the saving/loading of data.
struct XTBProcess {
  var workspace: URL
  
  var anchors: [Int] = []
  var atoms: [HDL.Entity] = []
  var spinMultiplicity: Int = 0
  
  init(path: String) {
    let url = URL(filePath: path, directoryHint: .isDirectory)
    precondition(try! url.checkResourceIsReachable())
    self.workspace = url
  }
  
  // ideas for future features:
  //   mutating function to energy-minimize the structure
  //   properties such as spinMultiplicity, algorithm, anchors
  //     prove anchors work by constraining H on a ridiculous water molecule
  //   ability to perform ONIOM
  
  func readFile(name: String) -> String {
    let fileURL = workspace.appending(component: name)
    let filePath = fileURL.path(percentEncoded: false)
    precondition(filePath != "")
    
    let contents = FileManager.default.contents(atPath: filePath)
    if let contents {
      return String(data: contents, encoding: .utf8)!
    }
    
    let succeeded = FileManager.default.createFile(
      atPath: filePath, contents: Data())
    precondition(succeeded)
    return ""
  }
  
  func writeFile(name: String, _ input: String) {
    let fileURL = workspace.appending(component: name)
    let filePath = fileURL.path(percentEncoded: false)
    precondition(filePath != "")
    
    let data = input.data(using: .utf8)!
    let succeeded = FileManager.default.createFile(
      atPath: filePath, contents: data)
    precondition(succeeded)
  }
  
  
  
}

// Write better functions to I/O geometry from scratch.
// - write settings
// - read geometry
// - write geometry
// - Swift source string of geometry
extension XTBProcess {
  func writeSettings() {
    var contents = ""
    if anchors.count > 0 {
      var anchorList: [String] = []
      for anchor in anchors {
        guard anchor >= 0, anchor < atoms.count else {
          fatalError("Invalid anchor: \(anchor)")
        }
        
        // Anchors are 1-indexed in xTB.
        anchorList.append("\(1 + anchor)")
      }
      
      let anchorString = anchorList.joined(separator: ",")
      contents += """
      $fix
         atoms: \(anchorString)
      $end
      
      """
    }
    writeFile(name: "xtb.inp", contents)
  }
  
  static let atomicNumbersToSymbolsMap: [UInt8: String] = [
    1: "h",
    6: "c",
    7: "n",
    8: "o",
    9: "f",
    14: "si",
    15: "p",
    16: "s",
    32: "ge",
  ]
  
  enum Encoding {
    case hdl
    case xtb
  }
  
  func decodeAtoms(
    _ input: String, encoding: Encoding = .xtb
  ) throws -> [Entity] {
    guard encoding == .xtb else {
      fatalError("Encoding not supported.")
    }
    let lines = input
      .split(separator: "\n")
      .map(String.init)
    
    var decodeStart = false
    var decodeEnd = false
    var output: [Entity] = []
    
    var symbolsToAtomicNumbersMap: [String: UInt8] = [:]
    for (key, value) in Self.atomicNumbersToSymbolsMap {
      symbolsToAtomicNumbersMap[value] = key
    }
    
    for line in lines {
      if line.starts(with: "$coord") {
        decodeStart = true
        continue
      }
      if line.starts(with: "$end") {
        decodeEnd = true
        continue
      }
      if line.starts(with: "$") {
        continue
      }
      if line.allSatisfy(\.isWhitespace) {
        continue
      }
      guard decodeStart, !decodeEnd else {
        continue
      }
      
      let segments = line
        .split(separator: " ", omittingEmptySubsequences: true)
        .map(String.init)
      guard segments.count == 4 else {
        throw XTBError.invalidFormatting(
          output.count, "Unexpected segment count: '\(segments.count)'.")
      }
      
      var positionInBohr: SIMD3<Double> = .zero
      for lane in 0..<3 {
        let segment = segments[lane]
        guard let value = Double(segment) else {
          throw XTBError.invalidFormatting(
            output.count, "Lane \(lane): '\(segment)' is not a floating-point number.")
        }
        positionInBohr[lane] = value
      }
      let symbol = segments[3]
      guard let atomicNumber = symbolsToAtomicNumbersMap[symbol] else {
        throw XTBError.invalidFormatting(
          output.count, "'\(symbol)' is not a recognized symbol.")
      }
      
      let positionInNm = SIMD3<Float>(positionInBohr * XTBNmPerBohr)
      let element = Element(rawValue: atomicNumber)!
      let atom = Entity(position: positionInNm, type: .atom(element))
      output.append(atom)
    }
    
    return output
  }
  
  func encodeAtoms(
    _ input: [Entity], encoding: Encoding = .xtb
  ) throws -> String {
    var output: [String] = []
    switch encoding {
    case .hdl:
      output.append("[")
    case .xtb:
      output.append("$coord")
    }
    
    var columnSizes: SIMD4<Int> = .zero
    for pass in 0..<2 {
      for atomID in input.indices {
        // Encode the position.
        let atom = input[atomID]
        var strings: [String] = []
        for lane in 0..<3 {
          let valueInNm = atom.position[lane]
          var string: String
          switch encoding {
          case .hdl:
            string = String(format: "%.4f", valueInNm)
          case .xtb:
            let valueInBohr = Double(valueInNm) * XTBBohrPerNm
            string = String(format: "%.3f", valueInBohr)
          }
          strings.append(string)
        }
        
        // Encode the atomic number.
        let atomicNumber = atom.atomicNumber
        var symbol: String?
        switch encoding {
        case .hdl:
          if let element = Element(rawValue: atomicNumber) {
            symbol = ".atom(\(element.description))"
          }
        case .xtb:
          symbol = Self.atomicNumbersToSymbolsMap[atomicNumber]
        }
        guard let symbol else {
          throw XTBError.invalidFormatting(
            atomID, "'\(atomicNumber)' is not a recognized atomic number.")
        }
        strings.append(symbol)
        
        // Find the largest column size on pass 0.
        for i in 0..<4 {
          columnSizes[i] = max(columnSizes[i], strings[i].count)
        }
        guard pass == 1 else {
          continue
        }
        
        // Encode the actual line on pass 1.
        for i in 0..<3 {
          var string = strings[i]
          let columnSize = columnSizes[i]
          while string.count < columnSize {
            string = " " + string
          }
          strings[i] = string
        }
        
        var line = "  "
        switch encoding {
        case .hdl:
          let vector = "SIMD3(\(strings[0]), \(strings[1]), \(strings[2]))"
          line += "Entity(position: \(vector), type: \(strings[3])),"
        case .xtb:
          line += "\(strings[0]) \(strings[1]) \(strings[2]) \(strings[3])"
        }
        output.append(line)
      }
    }
    
    switch encoding {
    case .hdl:
      output.append("]")
    case .xtb:
      output.append("$end")
    }
    
    // Don't append a newline. It should be the user's job to decide how
    // whitespace is formatted.
    return output.joined(separator: "\n")
  }
}
