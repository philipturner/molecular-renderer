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
// Filed: 2021, Granted: 2023
//
// Recipient: CBN Nano Technologies
// (shell company, ~50 employees)
// $40 million funding
// CEO: Robert Freitas, Ralph Merkle
struct Spring_Mechanosynthesis {
  var provider: any MRAtomProvider
  var diamondoid: Diamondoid!
  
  init() {
    provider = ArrayAtomProvider([MRAtom(origin: .zero, element: 6)])
    
    // Adamantane: C-C bond length 1.54
    // Benzene: C-C bond length 1.39
    // Adamantane-Benzene Molecules
    //
    // With Ge and carbon diradical
    
    // Group IV Elements AFM Tooltip
    // Compatible with a bulk diamond crystal
    //   (carve out of crystal, replace a few atoms in the
    //    Diamondoid, replace with Si, manual atom-by-atom
    //    placement)
    // 2004 Research Paper
    
    // Silicon (110) surface
    // Holds several adamantane-benzene feedstocks
    // Make a carbon procedural geometry crystal, change to Si.
    // Elemental Silicon: Si-Si bond length 2.37
  }
}
