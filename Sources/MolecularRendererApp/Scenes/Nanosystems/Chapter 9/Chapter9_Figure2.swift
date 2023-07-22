//
//  Chapter9_Figure2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/21/23.
//

import Foundation
import MolecularRenderer
import simd

extension Nanosystems.Chapter9 {
  struct Figure2 {
    // A polyethylene chain with seven monomers.
    var a: [MRAtom] = []
    
    init() {
      let ccBondLength: Float = 0.154
      let chBondLength: Float = 0.109
      let sp3BondAngle: Float = 109.5 * .pi / 180
      
      do {
        let centerCarbon = MRAtom(origin: .zero, element: 6)
        a.append(centerCarbon)
        
        let hydrogenXRotation = simd_quatf(
          angle: sp3BondAngle / 2, axis: [1, 0, 0])
        let hydrogenDelta = simd_act(hydrogenXRotation, [0, -chBondLength, 0])
        a.append(MRAtom(
          origin: centerCarbon.origin + hydrogenDelta, element: 1))
        a.append(MRAtom(
          origin: centerCarbon.origin + __tg_copysign(
            hydrogenDelta, [0, -1, +1]), element: 1))
        
        let carbonZRotation = simd_quatf(
          angle: -sp3BondAngle / 2, axis: [0, 0, 1])
        let carbonDelta = simd_act(carbonZRotation, [0, ccBondLength, 0])
        
        @discardableResult
        func appendMonomer(
          to carbon: MRAtom, direction: SIMD3<Float>
        ) -> MRAtom {
          let nextCarbon = MRAtom(
            origin: carbon.origin + __tg_copysign(
              carbonDelta, direction), element: 6)
          a.append(nextCarbon)
          
          a.append(MRAtom(
            origin: nextCarbon.origin + __tg_copysign(
              hydrogenDelta, [0, direction.y, +1]), element: 1))
          a.append(MRAtom(
            origin: nextCarbon.origin + __tg_copysign(
              hydrogenDelta, [0, direction.y, -1]), element: 1))
          return nextCarbon
        }
        for side in 0..<2 {
          var currentCarbon = centerCarbon
          for index in 0..<3 {
            let xPositive = side == 0
            let yPositive = (index % 2) == 0
            let direction: SIMD3<Float> = [
              xPositive ? 1 : -1,
              yPositive ? 1 : -1,
              0
            ]
            currentCarbon = appendMonomer(
              to: currentCarbon, direction: direction)
          }
        }
      }
      
      // Need a data structure that's a linked list of carbon atoms. It will
      // automatically find missing orbitals and fill them with hydrogens.
      
      // Rewrite code to generate (a) using the nicer Diamondoid API, ensure it
      // produces the same structure.
    }
  }
}
