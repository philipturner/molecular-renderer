//
//  XTBSolver.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/3/24.
//

import Foundation
import HDL
import MM4
import Numerics

// Utility for optimizing structures.
struct XTBSolver {
  var atoms: [Entity] = []
  var process: XTBProcess
  
  init(cpuID: Int) {
    let path = "/Users/philipturner/Documents/OpenMM/xtb/cpu\(cpuID)"
    self.process = XTBProcess(path: path)
  }
  
  mutating func solve(arguments: [String]) {
    process.writeFile(name: "xtb.inp", process.encodeSettings())
    process.writeFile(name: "coord", try! XTBProcess.encodeAtoms(atoms))
    process.run(arguments: ["coord", "--input", "xtb.inp"] + arguments)
  }
  
  mutating func load() {
    atoms = try! XTBProcess.decodeAtoms(process.readFile(name: "xtbopt.coord"))
  }
}

// Utility for storing structures as source code, with minimal overhead.
struct Base64Coder {
  static func decodeAtoms(_ string: String) -> [Entity] {
    let options: Data.Base64DecodingOptions = [
      .ignoreUnknownCharacters
    ]
    guard let data = Data(base64Encoded: string, options: options) else {
      fatalError("Could not decode the data.")
    }
    guard data.count % 16 == 0 else {
      fatalError("Data did not have the right alignment.")
    }
    
    let rawMemory: UnsafeMutableBufferPointer<SIMD4<Float>> =
      .allocate(capacity: data.count / 16)
    let encodedBytes = data.copyBytes(to: rawMemory)
    guard encodedBytes == data.count else {
      fatalError("Did not encode the right number of bytes.")
    }
    
    let output = Array(rawMemory)
    rawMemory.deallocate()
    return output.map(Entity.init(storage:))
  }
  
  static func encodeAtoms(_ atoms: [Entity]) -> String {
    let rawMemory: UnsafeMutableRawPointer =
      .allocate(byteCount: 16 * atoms.count, alignment: 16)
    rawMemory.copyMemory(from: atoms, byteCount: 16 * atoms.count)
    
    let data = Data(bytes: rawMemory, count: 16 * atoms.count)
    let options: Data.Base64EncodingOptions = [
      .lineLength76Characters,
      .endLineWithLineFeed
    ]
    let string = data.base64EncodedString(options: options)
    
    rawMemory.deallocate()
    return string
  }
}
