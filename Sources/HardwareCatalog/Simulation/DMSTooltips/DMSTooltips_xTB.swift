//
//  DMSTooltips_xTB.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 1/22/24.
//

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
      
      descriptor.state = states[stateID]
      let tooltip = Tooltip(descriptor: descriptor)
      tooltips.append(tooltip)
    }
  }
  
  #if false
  var tooltipFlags = [Int](repeating: 0, count: tooltips.count)
  let serialQueue = DispatchQueue(label: "com.philipturner.molecular-renderer.DMSTooltips")
  let tooltipCounter = ManagedAtomic<Int>(0)
  let tooltipCount = tooltipFlags.count
  
  DispatchQueue.concurrentPerform(iterations: 6) { z in
    while true {
      let tooltipID = tooltipCounter.loadThenWrappingIncrement(
        ordering: .sequentiallyConsistent)
      guard tooltipID < tooltipCount else {
        break
      }
      var tooltip: Tooltip?
      var tooltipName: String?
      serialQueue.sync {
        tooltip = tooltips[tooltipID]
        tooltipName = tooltipNames[tooltipID]
        tooltipFlags[tooltipID] = 1
        
        print()
        print("running jobs:")
        for i in tooltipFlags.indices {
          if tooltipFlags[i] == 1 {
            print("-", tooltipNames[i])
          }
        }
      }
      
      var solver = XTBSolver(cpuID: z)
      solver.atoms = tooltip!.topology.atoms
      solver.process.anchors = tooltip!.constrainedAtoms
      solver.process.standardError = false
      solver.process.standardOutput = false
      solver.solve(arguments: ["--opt"])
      solver.load()
      
      serialQueue.sync {
        tooltips[tooltipID].topology.atoms = solver.atoms
        tooltipFlags[tooltipID] = 2
        
        print()
        print("singlepoint for '\(tooltipName!)':")
        print()
        
        solver.process.standardOutput = true
        solver.solve(arguments: [""])
      }
    }
  }
  
  var allAtoms: [Entity] = []
  for tooltip in tooltips {
    allAtoms += tooltip.topology.atoms
  }
  print()
  print(Base64Coder.encodeAtoms(allAtoms))
  print()
  #else
  let decodedAtoms = Base64Coder.decodeAtoms(xtbBase64String)
  var decodedAtomCursor = 0
  for i in tooltips.indices {
    var tooltip = tooltips[i]
    let rangeStart = decodedAtomCursor
    let rangeEnd = rangeStart + tooltip.topology.atoms.count
    decodedAtomCursor = rangeEnd
    
    let range = rangeStart..<rangeEnd
    tooltip.topology.atoms = Array(decodedAtoms[range])
    if i != 15 {
      tooltips[i] = tooltip
    }
  }
  
  let tooltip = tooltips[5 * 3 + 0]
  var solver = XTBSolver(cpuID: 0)
  solver.atoms = tooltip.topology.atoms
  solver.process.anchors = tooltip.constrainedAtoms
  solver.solve(arguments: [])
  #endif
  
  for variantID in 0..<6 {
    let states: [TooltipState] = [.charged, .carbenicRearrangement, .discharged]
    for stateID in states.indices {
      // NOTE: Only perform this transformation when presenting tooltips for
      // rendering. Otherwise, keep them centered and in their original
      // orientation.
      
      // NOTE: For the production render, FOV was fixed at 30 degrees.
      var tooltip = tooltips[variantID * 3 + stateID]
      let angle0: Float = 20
      let angle1 = 15 * Float(1 - stateID)
      let translation1 = 1.2 * (2.5 - Float(variantID))
      let translation2 = 1.2 * Float(1 - stateID)
      
      let rotation0 = Quaternion<Float>(
        angle: angle0 * .pi / 180, axis: [1, 0, 0])
      let rotation1 = Quaternion<Float>(
        angle: angle1 * .pi / 180, axis: [1, 0, 0])
      let radius: Float = 15
      
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
      tooltips[variantID * 3 + stateID] = tooltip
    }
  }

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
  }
  
  mutating func load() {
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

let xtbBase64String = """
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
AIA/
"""

