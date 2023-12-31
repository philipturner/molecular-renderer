//
//  HousingVibrations.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 11/16/23.
//

import Foundation
import HDL
import MolecularRenderer
import QuaternionModule

struct HousingVibrations {
  var provider: any MRAtomProvider
  var openmmProvider: OpenMM_AtomProvider?
  
  init(
    openingWidth: Float,
    wallThicknessY: Float,
    wallThicknessX: Float
  ) {
    self.provider = ArrayAtomProvider([MRAtom(origin: .zero, element: 6)])
    
//    let openingWidth: Float = 6 // make this even
//    let wallThicknessY: Float = 3 // this can be odd, ideally 1 - 3
//    let wallThicknessX: Float = 2 // this can be odd, ideally 1 - 3
    
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      let _2h = 2 * h
      Bounds { 24 * _2h + 24 * h2k + 20 * l }
      Material { .elemental(.carbon) }
      
      let h2k2 = h2k / 2
      
      Volume {
        Origin { 12 * _2h + 12 * h2k }
        if (Int(openingWidth) / 2) % 2 == 0 {
          Origin { 0.5 * h + 0.0 * h2k2 }
        }
        
        Concave {
          for direction in [h, h2k2, -h, -h2k2] {
            Convex {
              Origin { (openingWidth / 2) * direction }
              Plane { -direction }
            }
          }
        }
        for direction in [h2k2, -h2k2] {
          Convex {
            Origin { (openingWidth / 2) * direction }
            Origin { wallThicknessY * direction }
            Plane { direction }
          }
        }
        for direction in [h, -h] {
          Convex {
            Origin { (openingWidth / 2) * direction }
            Origin { wallThicknessX * direction }
            Plane { direction }
          }
        }
        
        Replace { .empty }
      }
    }
    
    let latticeAtoms = lattice.atoms.map(MRAtom.init)
    provider = ArrayAtomProvider(latticeAtoms)
    
    var diamondoid = Diamondoid(atoms: latticeAtoms)
    diamondoid.translate(offset: -diamondoid.createCenterOfMass())
    diamondoid.translate(offset: [0, 0, -5])
    diamondoid.removeLooseCarbons()
    provider = ArrayAtomProvider([diamondoid])
    
    print()
    print("=== ATOM COUNT === \(diamondoid.atoms.count)")
    print()
    
    for temperature in [Double(4), 77, 298, 373] {
      var copy = diamondoid
      copy.minimize(temperature: temperature)
      let simulator = MM4(
        diamondoids: [diamondoid], fsPerFrame: 20, temperature: temperature)
      simulator.simulate(ps: 10)
      
      if self.openmmProvider == nil {
        self.openmmProvider = simulator.provider
      } else {
        self.openmmProvider!.states += simulator.provider.states
      }
    }
    self.provider = self.openmmProvider!
    
    print()
    print("=== ATOM COUNT === \(diamondoid.atoms.count)")
    print()
  }
}
