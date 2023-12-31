//
//  Chapter9_Figure3.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/23/23.
//

import Foundation
import MolecularRenderer
import QuaternionModule

extension Nanosystems.Chapter9 {
  struct Figure3: NanosystemsFigure {
    var a: Diamondoid
    
    init() {
      let ccBondLength = Constants.bondLengths[[6, 6]]!.average
      let cnBondLength = Constants.bondLengths[[6, 7]]!.average
      let coBondLength = Constants.bondLengths[[6, 8]]!.average
      let nnBondLength = Constants.bondLengths[[7, 7]]!.average
      
      let thicknessDelta = sp3Delta(
        start: [0, -ccBondLength, 0], axis: [0, 0, +1])
      let thickness = thicknessDelta.x
      precondition(thickness > 0, "Unexpected thickness.")
      
      var atoms: [MRAtom] = []
      atoms.append(MRAtom(
        origin: [0, -thicknessDelta.y / 2, 0], element: 6))
      do {
        let delta = sp3Delta(start: [0, +ccBondLength, 0], axis: [+1, 0, 0])
        let origin = atoms[0].origin + delta
        atoms.append(MRAtom(origin: origin, element: 6))
      }
      
      func makeOpposite(adjacent: Float, hypotenuse: Float) -> Float {
        var opposite = hypotenuse * hypotenuse - adjacent * adjacent
        opposite = sqrt(opposite)
        precondition(opposite > 0.001, "Opposite too small.")
        return opposite
      }
      
      var cnDelta: SIMD3<Float>
      do {
        let adjacent = thickness / 2
        let hypotenuse = nnBondLength / 2
        let opposite = makeOpposite(adjacent: adjacent, hypotenuse: hypotenuse)
        
        let opposite2 = atoms.last!.y - opposite
        let hypotenuse2 = cnBondLength
        var adjacent2 = hypotenuse2 * hypotenuse2 - opposite2 * opposite2
        adjacent2 = sqrt(adjacent2)
        precondition(adjacent2 > 0.001, "Adjacent too small.")
        
        cnDelta = SIMD3(0, -opposite2, adjacent2)
      }
      atoms.append(MRAtom(
        origin: atoms.last!.origin + cnDelta, element: 7))
      
      let rotationCenter: SIMD3<Float> = SIMD3(thickness / 2, 0, 0)
      let rotation = Quaternion<Float>(angle: .pi, axis: [0, 0, +1])
      
      func reflect(_ atom: MRAtom) -> MRAtom {
        var copy = atom
        var rotationDelta = copy.origin - rotationCenter
        rotationDelta = rotation.act(on: rotationDelta)
        copy.origin = rotationCenter + rotationDelta
        return copy
      }
      
      do {
        var origin = reflect(atoms[1]).origin
        
        let adjacent = thickness
        let hypotenuse = cnBondLength
        let opposite = makeOpposite(adjacent: adjacent, hypotenuse: hypotenuse)
        
        origin += SIMD3(-adjacent, -opposite, 0)
        precondition(abs(origin.x) < 0.001, "Incorrect initial placement.")
        origin.x = 0
        atoms.append(MRAtom(origin: origin, element: 7))
      }
      
      do {
        var origin = atoms.last!.origin
        let adjacent = origin.z
        let hypotenuse = cnBondLength
        let opposite = makeOpposite(adjacent: adjacent, hypotenuse: hypotenuse)
        
        origin += SIMD3(0, -opposite, -adjacent)
        precondition(abs(origin.z) < 0.001, "Incorrect initial placement.")
        origin.z = 0
        atoms.append(MRAtom(origin: origin, element: 6))
      }
      
      do {
        var origin = atoms.last!.origin
        let adjacent = thickness
        let hypotenuse = coBondLength
        let opposite = makeOpposite(adjacent: adjacent, hypotenuse: hypotenuse)
        origin += SIMD3(adjacent, -opposite, 0)
        
        let atom = MRAtom(origin: origin, element: 8)
        atoms.append(reflect(atom))
      }
      
      for atom in atoms where atom.z != 0 {
        precondition(abs(atom.z) > 0.001, "Invalid initial Z.")
        var origin = atom.origin
        origin.z = -origin.z
        atoms.append(MRAtom(origin: origin, element: atom.element))
      }
      
      let firstPlane = atoms
      let secondPlane = firstPlane.map(reflect)
      atoms = []
      
      func translate(_ atoms: [MRAtom], steps: Int) -> [MRAtom] {
        let delta: SIMD3<Float> = [Float(steps) * thickness * 2, 0, 0]
        return atoms.map {
          var atom = $0
          atom.origin += delta
          return atom
        }
      }
      
      atoms += firstPlane
      atoms += secondPlane
      atoms += translate(firstPlane, steps: 1)
      atoms += translate(secondPlane, steps: 1)
      atoms += translate(firstPlane, steps: 2)
      atoms += translate(secondPlane, steps: 2)
      atoms += translate(firstPlane, steps: 3)
      self.a = Diamondoid(atoms: atoms)
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a]
    }
  }
}

