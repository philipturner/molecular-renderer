//
//  CasingProvider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/9/23.
//

import Foundation
import MolecularRenderer
import simd

class CasingAtomProvider: MRAtomProvider {
  private let atomsDict: [String: [MRAtom]]
  
  init() {
    let urls = [
      "casings/Embedded Bushing in SiC with Shaft",
      "casings/Pump Casing",
      "casings/SiC Large Slab",
      "casings/SiC Small Slab",
    ]
    
    var selfAtomsDict: [String: [MRAtom]] = [:]
    for url in urls {
      let parser = NanoEngineerParser(partLibPath: url)
      selfAtomsDict[url] = parser._atoms
    }
    self.atomsDict = selfAtomsDict
  }
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    let t = Float(time.absolute.seconds)
    
    var currentAtomsDict: [String: [MRAtom]] = [:]
    for key in atomsDict.keys {
      var translation: SIMD3<Float>
      
      // TODO: Use quaternions to fix the rotation of the parts.
      switch key {
      case "casings/Embedded Bushing in SiC with Shaft":
        translation = [-3, 0, -3]
        break
      case "casings/Pump Casing":
        translation = [-1, 0, -1]
        break
      case "casings/SiC Large Slab":
        translation = [+1, 0, +1]
        break
      case "casings/SiC Small Slab":
        translation = [+3, 0, +3]
        break
      default:
        fatalError()
      }
      
      // Rotate once every two seconds.
      let rotation = simd_quatf(angle: t * .pi, axis: [0, 0, 1])
      var atoms = atomsDict[key]!
      for i in 0..<atoms.count {
        var atom = atoms[i]
        var pos = SIMD3<Float>(atom.origin)
        pos = simd_act(rotation, pos)
        pos += translation
        atom.origin = pos
        atoms[i] = atom
      }
      currentAtomsDict[key] = atoms
    }
    return currentAtomsDict.values.flatMap { $0 }
  }
}
