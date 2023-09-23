//
//  Spring_Mechanosynthesis.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/22/23.
//

import Foundation
import MolecularRenderer
import HDL
import simd
import QuartzCore

struct Spring_Mechanosynthesis {
  var provider: any MRAtomProvider
  var diamondoid: Diamondoid!
  
  init() {
    provider = ArrayAtomProvider([MRAtom(origin: .zero, element: 6)])
    
    // Adamantane-Benzene Molecules
    // With Ge and sp1 carbon feedstock
    //
    // sp3 C-C bond length 1.5247
    // sp2 C-C bond length 1.3320
    // sp1 C-C bond length 1.2100
    //
    // sp2 C-H bond length 1.1010
    // sp2 C-O bond length 1.3536
    // sp2 C-F bond length 1.3535
    //
    // sp3 C-sp3 C bond length 1.5247
    // sp2 C-sp3 C bond length 1.4990
    // sp1 C-sp3 C bond length 1.4990
    //
    // sp3 C-sp3 Ge bond length 1.9490
    // sp2 C-sp3 Ge bond length 1.9350
    // sp1 C-sp3 Ge bond length 1.9350
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
    _ = benzeneAtoms
    
    let adamantaneAtoms: [MRAtom] = (0..<3).flatMap { i -> [MRAtom] in
      var hydrogenCenters: [SIMD3<Float>] = []
      
      let angle1 = 2 * Float.pi * Float(i) / 3
      let x1 = sin(angle1)
      let z1 = cos(angle1)
      let direction1 = normalize(SIMD3<Float>(x1, 0, z1))
      let carbonCenter1 = direction1 * 0.1437
      
      let angle2 = angle1 + 2 * Float.pi * 1.0 / 6
      let x2 = sin(angle2)
      let z2 = cos(angle2)
      let direction2 = normalize(SIMD3<Float>(x2, 0, z2))
      var carbonCenter2 = direction2 * 0.1437
      carbonCenter2.y = -0.0509
      do {
        hydrogenCenters.append(carbonCenter2 - [0, 0.11010, 0])
        
        let angle = 2 * Float.pi * (180 - 109.5) / 360
        let verticalPart = cos(angle)
        let horizontalPart = sin(angle)
        let direction = direction2 * horizontalPart + [0, verticalPart, 0]
        hydrogenCenters.append(carbonCenter2 + direction * 0.11010)
      }
      
      let angle3 = 2 * Float.pi * 10 / 360
      var direction3 = direction1 * sin(angle3)
      direction3.y = cos(angle3)
      let carbonCenter3 = carbonCenter1 + direction3 * 0.1525
      do {
        if i > -1 {
          var deltas = hydrogenCenters
          deltas = deltas.map { $0 - carbonCenter1 }
          let rotation1 = simd_quatf(angle: -angle1, axis: [0, 1, 0])
          deltas = deltas.map { simd_act(rotation1, $0) }
          
          let rotation2 = simd_quatf(angle: 2 * Float.pi / 3, axis: [
            0, -cos(Float(70.5) * .pi / 180), sin(Float(70.5) * .pi / 180)
          ])
          deltas = deltas.map { simd_act(rotation2, $0) }
          
          let rotation3 = simd_quatf(angle: angle3, axis: [1, 0, 0])
          deltas = deltas.map { simd_act(rotation3, $0) }
  
          let rotation5 = simd_quatf(angle: angle1, axis: [0, 1, 0])
          deltas = deltas.map { simd_act(rotation5, $0) }
          
          hydrogenCenters += deltas.map { $0 + carbonCenter1 }
        }
      }
      
      var output = [carbonCenter1, carbonCenter2, carbonCenter3].map {
        MRAtom(origin: $0, element: 6)
      }
      output += hydrogenCenters.map {
        MRAtom(origin: $0, element: 1)
      }
      
      let germaniumBondXZ = carbonCenter3 * SIMD3(1, 0, 1)
      let germaniumLengthXZ = length(germaniumBondXZ)
      let germaniumY = carbonCenter3.y + sqrt(
        0.19490 * 0.19490 - germaniumLengthXZ * germaniumLengthXZ)
      let germaniumCenter = SIMD3(0, germaniumY, 0)
      print(germaniumY - carbonCenter3.y, germaniumLengthXZ, 90 + asin((germaniumY - carbonCenter3.y) / germaniumLengthXZ) * 180 / Float.pi)
      
      if i == 0 {
        var atomCenter = germaniumCenter
        output.append(MRAtom(origin: atomCenter, element: 31))
        atomCenter.y += 0.19350
        output.append(MRAtom(origin: atomCenter, element: 6))
        atomCenter.y += 0.12100
        output.append(MRAtom(origin: atomCenter, element: 6))
      }
      return output
    }
    provider = ArrayAtomProvider(adamantaneAtoms)
    
    // Group IV Elements AFM Tooltip (2004 Research Paper)
    // Covalently bonds to bulk diamond crystal
    //   (carve out of crystal, replace a few atoms in the
    //    Diamondoid, manual atom-by-atom bond reforming)
    // Also use the crossbar design for a 2nd-gen AFM tooltip
    //
    // TODO: Bond lengths for silicon variant
    
    // Silicon (111):
    // Holds several adamantane-benzene feedstocks
    // Make a carbon procedural geometry crystal, change to Si.
    //
    // sp3  O-Si bond length 1.6360 - use for Y positioning, but not XZ
    // sp3 Si-Si bond length 2.3240
  }
}
