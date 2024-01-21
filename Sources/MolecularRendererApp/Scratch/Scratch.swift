// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Atomics
import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  var tooltips: [Tooltip] = []
  var tooltipNames: [String] = []
  for variantID in 0..<6 {
    var descriptor = TooltipDescriptor()
    var name = ""
    
    if variantID == 0 {
      descriptor.reactiveSiteLeft = .carbon
      descriptor.reactiveSiteRight = .carbon
      name = "C"
    }
    if variantID == 1 {
      descriptor.reactiveSiteLeft = .silicon
      descriptor.reactiveSiteRight = .silicon
      name = "Si"
    }
    if variantID == 2 {
      descriptor.reactiveSiteLeft = .silicon
      descriptor.reactiveSiteRight = .germanium
      name = "SiGe"
    }
    if variantID == 3 {
      descriptor.reactiveSiteLeft = .germanium
      descriptor.reactiveSiteRight = .germanium
      name = "Ge"
    }
    if variantID == 4 {
      descriptor.reactiveSiteLeft = .tin
      descriptor.reactiveSiteRight = .tin
      name = "Sn"
    }
    if variantID == 5 {
      descriptor.reactiveSiteLeft = .lead
      descriptor.reactiveSiteRight = .lead
      name = "Pb"
    }
    name = "DCB6-" + name
    
    let states: [TooltipState] = [.charged, .carbenicRearrangement, .discharged]
    let stateNames = ["charged", "carbenic rearrangement", "discharged"]
    for stateID in states.indices {
      let stateName = stateNames[stateID]
      let tooltipName = "\(name) (\(stateName))"
      tooltipNames.append(tooltipName)
      
      // NOTE: Only perform this transformation when presenting tooltips for
      // rendering. Otherwise, keep them centered and in their original
      // orientation.
      
      let angle0: Float = 20
      let angle1 = 15 * Float(1 - stateID)
      let translation1 = 1.2 * (2.5 - Float(variantID))
      let translation2 = 1.2 * Float(1 - stateID)
      
      let rotation0 = Quaternion<Float>(
        angle: angle0 * .pi / 180, axis: [1, 0, 0])
      let rotation1 = Quaternion<Float>(
        angle: angle1 * .pi / 180, axis: [1, 0, 0])
      let radius: Float = 15
      
      descriptor.state = states[stateID]
      var tooltip = Tooltip(descriptor: descriptor)
      for i in tooltip.topology.atoms.indices {
        var atom = tooltip.topology.atoms[i]
        var position = atom.position
        
        position = rotation0.act(on: position)
        position = rotation1.act(on: position)
        position.z -= radius
        position.x -= translation1
        position.y += translation2
        position.z += 1 // player position
        
        atom.position = position
        tooltip.topology.atoms[i] = atom
      }
      tooltips.append(tooltip)
    }
  }
  
  // Next: Serialize the (non-tilted) structures into a base64 string and decode
  // in another app launch.
  
  return tooltips.flatMap { $0.topology.atoms }
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
