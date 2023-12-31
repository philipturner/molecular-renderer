//
//  OctaneReference.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/6/23.
//

import Foundation

struct OctaneReference {
  var provider: OpenMM_AtomProvider
  
  init() {
    let figure = Nanosystems.Chapter4.Figure3()
    var diamondoid = figure.a
    diamondoid.translate(offset: -diamondoid.createCenterOfMass())
    
    let simulator = _Old_MM4(diamondoid: diamondoid, fsPerFrame: 4)
    simulator.simulate(ps: 10) // 100
    self.provider = simulator.provider
  }
}
