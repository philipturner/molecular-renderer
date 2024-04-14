//
//  Supply.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/10/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Supply {
  var tripods: [Tripod] = []
  
  // Instead of animating the recharging of tripods, simply replace them with
  // the original version after a delay period. It could be the moment the AFM
  // probe touches the workpiece for the next reaction.
  
  init() {
    tripods.append(Tripod(atoms: TripodCache.carbonSet.radical))
    tripods.append(Tripod(atoms: TripodCache.germaniumSet.hydrogen))
    tripods.append(Tripod(atoms: TripodCache.germaniumSet.methylene))
    tripods.append(Tripod(atoms: TripodCache.germaniumSet.carbene))
    
    for tripodID in tripods.indices {
      let tripod = tripods[tripodID]
      
      let coordinateH: Float = -11
      var coordinateH2K: Float
      coordinateH2K = Float(tripodID) - 1.5
      coordinateH2K = coordinateH2K * 3
      
      let latticeConstant = Constant(.hexagon) { .elemental(.silicon) }
      let h = SIMD3(
        latticeConstant, 0, 0)
      let k = SIMD3(
        -latticeConstant / 2, 0, -latticeConstant * Float(3).squareRoot() / 2)
      
      func shift(atom: inout Entity) {
        // Correct for misalignment with the surface lattice.
        let rotation = Quaternion<Float>(angle: 4 * .pi / 3, axis: [0, 1, 0])
        atom.position = rotation.act(on: atom.position)
        atom.position.x += Float(1.0) / 2 * latticeConstant
        atom.position.z += Float(3).squareRoot() / 3 * latticeConstant
        
        // Move to the tripod's unique position.
        atom.position += coordinateH * h
        atom.position += coordinateH2K * (h + 2 * k)
      }
      func createShiftedTripod() -> Tripod {
        var copy = tripod
        for atomID in copy.tooltip.topology.atoms.indices {
          shift(atom: &copy.tooltip.topology.atoms[atomID])
        }
        for atomID in copy.legAtoms.indices {
          shift(atom: &copy.legAtoms[atomID])
        }
        for atomID in copy.feedstockAtoms.indices {
          shift(atom: &copy.feedstockAtoms[atomID])
        }
        return copy
      }
      tripods[tripodID] = createShiftedTripod()
    }
  }
  
  func createFrame() -> [Entity] {
    var output: [Entity] = []
    for tripod in tripods {
      output.append(contentsOf: tripod.createFrame())
    }
    
    // Remove the SiH3 groups from the tripods.
    output.removeAll(where: {
      $0.position.y < 0.001
    })
    return output
  }
}
