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
  struct Figure2/*: Figure3D*/ {
    var a: [MRAtom] = []
    // var a: Diamondoid
    
    init() {
      let ccBondLength: Float = 0.154
      let chBondLength: Float = 0.109
      
      func sp3Delta(
        start: SIMD3<Float>, axis: SIMD3<Float>
      ) -> SIMD3<Float> {
        let sp3BondAngle: Float = 109.5 * .pi / 180
        let rotation = simd_quatf(angle: sp3BondAngle / 2, axis: axis)
        return simd_act(rotation, start)
      }
      
      do {
        var centerCarbon = Diamondoid.CarbonCenter(origin: .zero)
        centerCarbon.addHydrogenBond(
          sp3Delta(start: [0, -chBondLength, 0], axis: [+1, 0, 0]))
        centerCarbon.addHydrogenBond(
          sp3Delta(start: [0, -chBondLength, 0], axis: [-1, 0, 0]))
        var carbons = [centerCarbon]
        
        for side in 0..<2 {
          var previousCarbonIndex = 0
          for index in 0..<3 {
            var carbonChainDelta: SIMD3<Float>
            if side == 0 {
              if index % 2 == 0 {
                carbonChainDelta = sp3Delta(
                  start: [0, +ccBondLength, 0], axis: [0, 0, -1])
              } else {
                carbonChainDelta = sp3Delta(
                  start: [0, -ccBondLength, 0], axis: [0, 0, +1])
              }
            } else {
              if index % 2 == 0 {
                carbonChainDelta = sp3Delta(
                  start: [0, +ccBondLength, 0], axis: [0, 0, +1])
              } else {
                carbonChainDelta = sp3Delta(
                  start: [0, -ccBondLength, 0], axis: [0, 0, -1])
              }
            }
            carbons[previousCarbonIndex].addCarbonBond(carbonChainDelta)
            
            let previousOrigin = carbons[previousCarbonIndex].origin
            var carbon = Diamondoid.CarbonCenter(
              origin: previousOrigin + carbonChainDelta)
            carbon.addCarbonBond(-carbonChainDelta)
            
            var hydrogenBondsStart: SIMD3<Float>
            if index % 2 == 0 {
              hydrogenBondsStart = [0, +chBondLength, 0]
            } else {
              hydrogenBondsStart = [0, -chBondLength, 0]
            }
            carbon.addHydrogenBond(
              sp3Delta(start: hydrogenBondsStart, axis: [+1, 0, 0]))
            carbon.addHydrogenBond(
              sp3Delta(start: hydrogenBondsStart, axis: [-1, 0, 0]))
            
            previousCarbonIndex = carbons.count
            carbons.append(carbon)
          }
        }
        
        var diamondoid = Diamondoid()
        for carbon in carbons {
          diamondoid.addCarbon(carbon)
        }
        self.a = diamondoid.makeAtoms()
      }
    }
  }
  
  struct Figure5/*: Figure3D*/ {
    
  }
  
  struct Figure6/*: Figure3D*/ {
    
  }
}
