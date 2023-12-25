//
//  Adamantanes.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/2/23.
//

import HDL
import MolecularRenderer
import QuaternionModule

#if false

struct Adamantanes {
  var provider: MRAtomProvider
  
  init() {
    
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 4 * h + 4 * k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 2 * h + 2 * k + 2 * l }
        Origin { 0.25 * (h + k - l) }
        
        // Remove the front plane.
        Convex {
          Origin { 0.25 * (h + k + l) }
          Plane { h + k + l }
        }
        
        func triangleCut(sign: Float) {
          Convex {
            Origin { 0.25 * sign * (h - k - l) }
            Plane { sign * (h - k / 2 - l / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (k - l - h) }
            Plane { sign * (k - l / 2 - h / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (l - h - k) }
            Plane { sign * (l - h / 2 - k / 2) }
          }
        }
        
        // Remove three sides forming a triangle.
        triangleCut(sign: +1)
        
        // Remove their opposites.
        triangleCut(sign: -1)
        
        // Remove the back plane.
        Convex {
          Origin { -0.25 * (h + k + l) }
          Plane { -(h + k + l) }
        }
        
        Replace { .empty }
      }
    }
    
    let latticeAtoms = lattice.entities.map(MRAtom.init)
    provider = ArrayAtomProvider(latticeAtoms)
    
    var diamondoid0 = Diamondoid(atoms: latticeAtoms)
    var diamondoid1 = diamondoid0
    var diamondoid2 = diamondoid0
    var diamondoid3 = diamondoid0
    diamondoid1.translate(offset: [0.5, -0.5, 0])
    diamondoid2.translate(offset: [0, -0.5, 0.5])
    diamondoid3.translate(offset: [0.5, -1.0, 0.5])
    
    diamondoid0.atoms.removeAll(where: { $0.element != 6 })
    diamondoid3.atoms.removeAll(where: { $0.element != 6 })
    diamondoid3.atoms = diamondoid3.atoms.map {
      var atom = $0
      if atom.origin.x > 1.3,
         atom.origin.y > -0.15,
         atom.origin.z > 1.2 {
        atom.element = 32
      }
      return atom
    }
    
    var diamondoid2Atoms = diamondoid2.atoms
    let closestCarbons: [Int] = diamondoid2Atoms.indices.map { index in
      if diamondoid2Atoms[index].element != 1 {
        return -1
      }
      
      var minDistance: Float = .greatestFiniteMagnitude
      var minIndex: Int = -1
      let origin = diamondoid2Atoms[index].origin
      
      for atomID in diamondoid2Atoms.indices where index != atomID {
        let atom = diamondoid2Atoms[atomID]
        let distance = (
          (origin - atom.origin) * (origin - atom.origin)).sum()
        if distance < minDistance {
          minDistance = distance
          minIndex = atomID
        }
      }
      guard minIndex != -1,
            diamondoid2Atoms[minIndex].element != 1 else {
        fatalError("Did not retrieve a carbon.")
      }
      return minIndex
    }
    diamondoid2Atoms = diamondoid2Atoms.indices.map { index in
      var atom = diamondoid2Atoms[index]
      if closestCarbons[index] == -1 {
        return atom
      }
      
      let carbon = diamondoid2Atoms[closestCarbons[index]]
      let delta = atom.origin - carbon.origin
      let newDelta = 1.3900 / 1.1120 * delta
      atom.origin = carbon.origin + newDelta
      atom.element = 9
      return atom
    }
    diamondoid2.atoms = diamondoid2Atoms
    
    provider = ArrayAtomProvider([diamondoid0, diamondoid1, diamondoid2, diamondoid3])
    
    let lattice2 = Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 10 * k + 10 * l }
      Material { .elemental(.silicon) }
      
      Volume {
        Origin { 5 * h + 5 * k + 5 * l }
        Plane { h + k + l }
        
        Replace { .empty }
      }
    }
    let latticeAtoms2 = lattice2.entities.map(MRAtom.init)
    var baseDelta: SIMD3<Float> = SIMD3(2.30, 2.30, 2.30)
    baseDelta += SIMD3<Float>(-1, -1, 1) * 0.1
    baseDelta += SIMD3<Float>(-1, 1, -1) * 0.05
    
    func makeArray(magnitude: Float) -> [SIMD3<Float>] {
      return [
        baseDelta + 0.543 * SIMD3(1, 0, -1) * magnitude,
        baseDelta + 0.543 * SIMD3(1, 0, -1) * -magnitude,
        baseDelta + 0.543 * SIMD3(0, 1, -1) * magnitude,
        baseDelta + 0.543 * SIMD3(0, 1, -1) * -magnitude,
        baseDelta + 0.543 * SIMD3(-1, 1, 0) * magnitude,
        baseDelta + 0.543 * SIMD3(-1, 1, 0) * -magnitude,
      ]
    }
    var deltas: [SIMD3<Float>] = [
      baseDelta
    ]
    for magnitude in [Float(1.5), 3.0] {
      deltas += makeArray(magnitude: magnitude)
    }
    
    let silicon111Surface = latticeAtoms2
    for delta in deltas {
//      silicon111Surface += diamondoid3.atoms.map {
//        var atom = $0
//        atom.origin += delta
//        return atom
//      }
      for axis in 0..<3 {
        var sulfurOffset: SIMD3<Float> = [-0.15, -0.15, -0.15]
        sulfurOffset[axis] = +0.15
        
        let quaternion = Quaternion<Float>(
          angle: 3.14159, axis: SIMD3(repeating: 0.577350))
        sulfurOffset = quaternion.act(on: sulfurOffset)
        
        var sulfurOrigin: SIMD3<Float> = [0.35, 0.35, 0.35]
        sulfurOrigin += delta
        sulfurOrigin += [0.75, -0.75, 0.75]
        sulfurOrigin += [0.09,  0.09, -0.09]
        
        let atom = MRAtom(
          origin: sulfurOrigin + sulfurOffset, element: 16)
        _ = atom
//        silicon111Surface.append(atom)
      }
    }
    
    
    provider = ArrayAtomProvider(silicon111Surface)
  }
}

#endif

