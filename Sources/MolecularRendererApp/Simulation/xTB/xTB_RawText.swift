//
//  xTB_RawText.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/3/23.
//

import Foundation
import MolecularRenderer

// Utilities for manually running geometry through xTB.

func exportToXTB(_ atoms: [MRAtom]) -> String {
  exportToText(atoms, xtb: true)
}

func exportToXTB(_ diamondoids: [Diamondoid]) -> String {
  exportToText(diamondoids.flatMap(\.atoms), xtb: true)
}

/// Used for storing xTB trajectories as Swift source code.
func exportToSwift(_ atoms: [MRAtom]) -> String {
  exportToText(atoms, xtb: false)
}

func importFromXTB(_ data: String) -> [MRAtom] {
  var lines = data.split(separator: "\n").map(String.init)
  guard lines.first!.starts(with: "$coord") else {
    fatalError("Did not start with $coord.")
  }
  guard !lines.first!.starts(with: "$coord ang") else {
    fatalError("Coordinates cannot be in angstroms.")
  }
  while lines.last!.allSatisfy(\.isWhitespace) {
    lines.removeLast()
  }
  guard lines.last!.starts(with: "$end") else {
    fatalError("Did not start with $coord.")
  }
  lines.removeFirst()
  lines.removeLast()
  lines.removeAll(where: { $0.starts(with: "$")})
  
  var output: [MRAtom] = []
  for line in lines {
    let segments = line.split(separator: " ", omittingEmptySubsequences: true)
    var origin: SIMD3<Float> = .zero
    for i in 0..<3 {
      // Units: bohr -> nm
      origin[i] = Float(segments[i])!
      origin[i] /= BohrPerAngstrom * AngstromPerNm
    }
    
    var element: UInt8
    switch segments.last! {
    case "h": element = 1
    case "c": element = 6
    case "si": element = 14
    case "s": element = 16
    case "ge": element = 32
    default: fatalError("This should never happen.")
    }
    output.append(MRAtom(origin: origin, element: element))
  }
  
  return output
}

fileprivate let AngstromPerNm: Float = 10
fileprivate let BohrPerAngstrom: Float = 1 / 0.529177

fileprivate func exportToText(_ atoms: [MRAtom], xtb: Bool) -> String {
  var output: String = ""
  if xtb {
    output += "$coord"
    output += "\n"
  }
  
  for atom in atoms {
    if !xtb {
      output += "MRAtom(origin: SIMD3("
    }
    
    for index in 0..<3 {
      var coord = atom.origin[index]
      if coord >= 0 {
        output += " "
      }
      if xtb {
        // Units: nm -> bohr
        coord *= BohrPerAngstrom * AngstromPerNm
        output += String(format: "%.3f", coord)
        output += " "
      } else {
        output += String(format: "%.4f", coord)
        if index != 2 {
          output += ", "
        }
      }
    }
    
    if xtb {
      var repr: String
      switch atom.element {
      case 1: repr = "h "
      case 6: repr = "c "
      case 14: repr = "si"
      case 16: repr = "s "
      case 32: repr = "ge"
      default:
        fatalError("Unrecognized element: \(atom.element)")
      }
      output += repr
      output += "\n"
    } else {
      output += "), element: "
      output += "\(atom.element)"
      output += "),"
      output += "\n"
    }
    
  }
  
  if xtb {
    output += "$end"
    output += "\n"
  }
  return output
}

// Utilities for running MD simulations through xTB.

// WARNING: This does not include which atoms should be anchors, and does not
// include the number of unpaired electrons. It should go in "coord.inp".
let xtbSettingsMD: String = """
$md
   temp=298.15 # in K
   time=  1.0  # in ps
   dump=  2.0  # in fs
   step=  2.0  # in fs
   velo=false
   nvt =true
   hmass=2
   shake=0
   sccacc=2.0
$end
"""

// MD simulations are in angstroms, while coordinate files are in bohr.
// - declare a function that imports the xTB simulation from text

// TODO: - Debug the text deserialization before rendering a simulation with
// 'XtbAtomProvider'.
struct XtbAtomProvider: MRAtomProvider {
  var frames: [[MRAtom]] = []
  
  // Main initializer from an array of frames.
  
  // Convenience initializer directly from xTB text.
  
  mutating func atoms(time: MRTimeContext) -> [MRAtom] {
    var arrayIndex = time.absolute.frames
    arrayIndex = min(arrayIndex, frames.count - 1)
    guard frames.count > 0 else {
      return []
    }
    return frames[arrayIndex]
  }
}
