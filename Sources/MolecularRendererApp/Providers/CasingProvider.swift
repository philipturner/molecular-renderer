//
//  CasingProvider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/9/23.
//

import Foundation
import MolecularRenderer
import simd

class Casing_DynamicAtomProvider: MRStaticAtomProvider {
  private let atomsDict: [String: [MRAtom]]
  private var currentAtomsDict: [String: [MRAtom]] = [:]
  private var frameID: Int = -1
  
  var atoms: [MRAtom] {
    currentAtomsDict.values.flatMap { $0 }
  }
  
  init(styleProvider: MRStaticStyleProvider) {
    let urls = [
      "casings/Embedded Bushing in SiC with Shaft",
      "casings/Pump Casing",
      "casings/SiC Large Slab",
      "casings/SiC Small Slab",
    ]
    
    var selfAtomsDict: [String: [MRAtom]] = [:]
    for url in urls {
      let parser = NanoEngineerParser(
        styleProvider: styleProvider, partLibPath: url)
      let atoms = parser.atoms
      selfAtomsDict[url] = atoms
    }
    self.atomsDict = selfAtomsDict
  }
  
  @_optimize(speed)
  func nextFrame() {
    self.frameID += 1
    let t = Float(frameID) / 120
    
    for key in atomsDict.keys {
//      var transform: simd_float4x4 = simd_float4x4(diagonal: .one)
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
//      translation *= 0
      
      // Rotate once every two seconds.
//      let rotation = simd_quatf(angle: t * .pi, axis: [0, 0, 1])
//      var atoms = atomsDict[key]!
//      for i in 0..<atoms.count {
//        var atom = atoms[i]
//        var pos = SIMD3<Float>(atom.origin)
//        pos = simd_act(rotation, pos)
//        pos += translation
//        atom.origin = pos
//        atoms[i] = atom
//      }
//      currentAtomsDict[key] = atoms
      
      currentAtomsDict[key] = transformAtomDict(
        atomsDict, key: key, t: t, translation: translation)
    }
  }
}

@inline(never) @_optimize(speed)
fileprivate func transformAtomDict(
  _ atomsDict: [String: [MRAtom]], key: String,
  t: Float, translation: SIMD3<Float>
) -> [MRAtom] {
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
    return atoms
}
