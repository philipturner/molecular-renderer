//
//  StructureUtilities.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import simd

struct Constants {
  struct BondLength {
    var range: ClosedRange<Float>
    var average: Float
  }
  
  // CH and CC are shown extensively in literature. Other pairs of elements do
  // not have explicit reference values, so they are generated from the table
  // at:
  // https://periodictable.com/Properties/A/CovalentRadius.v.log.html
  //
  // These statistics are all for sigma bonds; pi bonds are not supported yet.
  static let bondLengths: [SIMD2<UInt8>: BondLength] = [
    [1, 6]: BondLength(range: 0.104...0.114, average: 0.109),
    [1, 7]: BondLength(range: 0.097...0.107, average: 0.102),
    [1, 8]: BondLength(range: 0.092...0.102, average: 0.097),
    [1, 16]: BondLength(range: 0.131...0.141, average: 0.136),
    
//    [6, 6]: BondLength(range: 0.149...0.159, average: 0.154),
    [6, 6]: BondLength(range: 0.148...0.168, average: 0.154),
    [6, 7]: BondLength(range: 0.142...0.152, average: 0.147),
    [6, 8]: BondLength(range: 0.138...0.148, average: 0.143),
    
    // Source: https://en.wikipedia.org/wiki/Organosulfur_chemistry
    [6, 16]: BondLength(range: 0.170...0.195, average: 0.183),
    
    [7, 7]: BondLength(range: 0.137...0.147, average: 0.142),
    [7, 8]: BondLength(range: 0.132...0.142, average: 0.137),
    
    // Source:
    // - https://open.library.ubc.ca/media/stream/pdf/24/1.0135560/1
    // - page 27
    [7, 16]: BondLength(range: 0.171...0.181, average: 0.176),
    
    [8, 8]: BondLength(range: 0.127...0.137, average: 0.132),
    [8, 16]: BondLength(range: 0.166...0.176, average: 0.171),
  ]
  
  static func bondLengthMax(element: UInt8) -> Float {
    var output: Float = 0
    for key in bondLengths.keys {
      guard key[0] == element || key[1] == element else {
        continue
      }
      let length = bondLengths[key]!.range.upperBound
      output = max(output, length)
    }
    guard output > 0 else {
      fatalError("No bond lengths found for element \(element).")
    }
    return output
  }
  
  static func valenceElectrons(element: UInt8) -> Int {
    switch element {
    case 1: return 1
    case 6: return 4
    case 7: return 3
    case 8: return 2
    case 16: return 2
    default: fatalError("Element \(element) not supported.")
    }
  }
  
  static let sp2BondAngle: Float = 120 * .pi / 180
  static let sp3BondAngle: Float = 109.5 * .pi / 180
}

func sp2Delta(
  start: SIMD3<Float>, axis: SIMD3<Float>
) -> SIMD3<Float> {
  
  let rotation = simd_quatf(angle: Constants.sp2BondAngle / 2, axis: axis)
  return simd_act(rotation, start)
}

func sp3Delta(
  start: SIMD3<Float>, axis: SIMD3<Float>
) -> SIMD3<Float> {
  
  let rotation = simd_quatf(angle: Constants.sp3BondAngle / 2, axis: axis)
  return simd_act(rotation, start)
}

/// Rounds an integer up to the nearest power of 2.
func roundUpToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - max(0, input - 1).leadingZeroBitCount)
}

/// Rounds an integer down to the nearest power of 2.
func roundDownToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - 1 - input.leadingZeroBitCount)
}
