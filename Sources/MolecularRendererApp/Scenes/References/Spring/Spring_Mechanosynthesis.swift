//
//  Spring_Mechanosynthesis.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/20/23.
//

import Foundation
import MolecularRenderer
import HDL
import simd
import QuartzCore

// Mechanosynthesis Scene
//
// US Patent 11592463B2
// Systems and methods for mechanosynthesis
// CBN Nano Technologies (2023)
// Robert Freitas, Ralph Merkle
struct Spring_Mechanosynthesis {
  var provider: any MRAtomProvider
  var diamondoid: Diamondoid!
  
  init() {
    provider = ArrayAtomProvider([MRAtom(origin: .zero, element: 6)])
    
    // Adamantane-Benzene Molecules
    // With Ge and sp1 carbon feedstock
    //
    // sp3 C-C bond length 0.15247
    // sp2 C-C bond length 0.13320
    // sp1 C-C bond length 0.12100
    //
    // sp2 C-H bond length 0.11010
    // sp2 C-O bond length 0.13536
    // sp2 C-F bond length 0.13535
    //
    // What about the carbon-germanium bonds?
    let benzeneAtoms: [MRAtom] = (0..<6).flatMap { i -> [MRAtom] in
      let angle = 2 * Float.pi * Float(i) / 6
      let x = sin(angle)
      let y = -cos(angle)
      let direction = normalize(SIMD3<Float>(x, y, 0))
      let carbonCenter = direction * 0.13320
      let carbon = MRAtom(origin: carbonCenter, element: 6)
      
      var otherBondLength: Float?
      var otherElement: UInt8?
      if i == 0 {
        // oxygen
        otherBondLength = 0.13536
        otherElement = 8
      } else if i == 1 || i == 3 || i == 5 {
        // fluorine
        otherBondLength = 0.13535
        otherElement = 9
      } else if i == 2 {
        // nothing (bond to adamantane)
      } else if i == 4 {
        // hydrogen
        otherBondLength = 0.11010
        otherElement = 1
      }
      
      var output: [MRAtom] = [carbon]
      if let otherBondLength, let otherElement {
        let origin = carbonCenter + direction * otherBondLength
        output.append(MRAtom(
          origin: origin, element: otherElement))
      }
      return output
    }
    provider = ArrayAtomProvider(benzeneAtoms)
    
    // Group IV Elements AFM Tooltip (2004 Research Paper)
    // Covalently bonds to bulk diamond crystal
    //   (carve out of crystal, replace a few atoms in the
    //    Diamondoid, manual atom-by-atom bond reforming)
    //
    // TODO: Bond lengths for silicon variant
    
    // Silicon (110):
    // Holds several adamantane-benzene feedstocks
    // Make a carbon procedural geometry crystal, change to Si.
    //
    // sp3  O-Si bond length 0.16360
    // sp3 Si-Si bond length 0.23240
  }
}
