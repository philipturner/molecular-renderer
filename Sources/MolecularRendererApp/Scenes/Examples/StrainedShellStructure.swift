//
//  StrainedShellStructure.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/22/23.
//

import Foundation
import MolecularRenderer

extension ExampleProviders {
  static func strainedShellStructure() -> any MRAtomProvider {
    //    let url2 = URL(filePath: "/Users/philipturner/Desktop/armchair-graphane-W-structure.pdb")
        
        let url2 = URL(filePath: "/Users/philipturner/Desktop/lonsdaleite-gear.pdb")
        let parsed = PDBParser(url: url2, hasA1: true)
    //    let parsed = NanoEngineerParser(path: url2.absoluteString)
        
    //    let parsed = NanoEngineerParser(
    //      partLibPath: "bearings/Hydrocarbon Strained Sleeve Bearing.mmp")
        let centers = parsed._atoms.compactMap { atom -> SIMD3<Float>? in
          if atom.element == 6 {
            return atom.origin
          } else {
            return nil
          }
        }
    //
    //    var diamondoid = Diamondoid(carbonCenters: centers)
    //    diamondoid.translate(offset: -diamondoid.createCenterOfMass())
    //    diamondoid.rotate(angle: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]))
    //
    //    var simulation = MM4(diamondoid: diamondoid, fsPerFrame: 20)
    //    let ranges = simulation.rigidBodies
    //    let state = simulation.context.state(types: [.positions, .velocities])
    //    let statePositions = state.positions
    //    let stateElements = simulation.provider.elements
    //    var rigidBodies = ranges.map { range -> Diamondoid in
    //      var centers: [SIMD3<Float>] = []
    //      for index in range {
    //        guard stateElements[index] == 6 else {
    //          continue
    //        }
    //
    //        let position = statePositions[index]
    //        centers.append(SIMD3(position))
    //      }
    //      return Diamondoid(carbonCenters: centers)
    //    }
    //    print(rigidBodies.count)
    //    print(rigidBodies[0].atoms.count)
    //    print(rigidBodies[1].atoms.count)
    //
    //    rigidBodies[1].angularVelocity = simd_quatf(angle: 1, axis: [0, 0, 1])
    //
    //    simulation = MM4(diamondoids: rigidBodies, fsPerFrame: 20)
    //    simulation.simulate(ps: 15)
    //
    //
    //
    //    self.atomProvider = simulation.provider
    //    serializer.save(fileName: "Strained Shell Bearing", provider: simulation.provider)
        
        
    //    self.atomProvider = ArrayAtomProvider(diamondoid.atoms)
    //
    ////    }
        let provider = ArrayAtomProvider(centers.map {
          MRAtom(origin: $0, element: 6)
        })
        return provider
  }
}
