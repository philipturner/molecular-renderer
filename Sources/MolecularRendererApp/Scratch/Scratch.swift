// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  var descriptor = TooltipDescriptor()
  descriptor.reactiveSiteLeft = .germanium
  descriptor.reactiveSiteRight = .germanium
  descriptor.state = .charged
  let tooltip = Tooltip(descriptor: descriptor)
  
  var solver = XTBSolver(cpuID: 0)
  solver.atoms = tooltip.topology.atoms
  solver.process.anchors = tooltip.constrainedAtoms
//  solver.solve(arguments: ["--opt"])
  
  // Next: generate a list of all the tooltips, present the renders. Tilt all
  // of them to their local Z axis points straight toward the global (0, 0, 0).
  // Serialize the (non-tilted) structures into a base64 string and decode in
  // another app launch.
  
  return solver.atoms
}

struct XTBSolver {
  var atoms: [Entity] = []
  var process: XTBProcess
  
  init(cpuID: Int) {
    let path = "/Users/philipturner/Documents/OpenMM/xtb/cpu\(cpuID)"
    self.process = XTBProcess(path: path)
  }
  
  mutating func solve(arguments: [String]) {
    process.writeFile(name: "xtb.inp", process.encodeSettings())
    process.writeFile(name: "coord", try! process.encodeAtoms(atoms))
    process.run(arguments: ["coord", "--input", "xtb.inp"] + arguments)
    atoms = try! process.decodeAtoms(process.readFile(name: "xtbopt.coord"))
  }
}

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
