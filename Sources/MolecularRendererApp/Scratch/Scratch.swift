// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // MARK: - Housing
  
  let housingLattice = Lattice<Cubic> { h, k, l in
    Bounds { 48 * h + 28 * k + 30 * l }
    Material { .elemental(.carbon) }
    
    func createHoleZ(offset: SIMD3<Float>) {
      Convex {
        Origin { offset[0] * h + offset[1] * k + offset[2] * l }
        Origin { 1.5 * h + 1.5 * k }
        Concave {
          Plane { h }
          Plane { k }
          Origin { 4 * h + 4.25 * k }
          Plane { -h }
          Plane { -k }
        }
      }
    }
    
    func createHoleX(offset: SIMD3<Float>) {
      Convex {
        Origin { offset[0] * h + offset[1] * k + offset[2] * l }
        Origin { 1.5 * k + 1.5 * l }
        Concave {
          Plane { k }
          Plane { l }
          Origin { 4.25 * k + 4 * l }
          Plane { -k }
          Plane { -l }
        }
      }
    }
    
    func createHoleY(offset: SIMD3<Float>) {
      Convex {
        Origin { offset[0] * h + offset[1] * k + offset[2] * l }
        Origin { 1.5 * h + 1.5 * l }
        Concave {
          Plane { h }
          Plane { l }
          Origin { 4 * h + 4.25 * l }
          Plane { -h }
          Plane { -l }
        }
      }
    }
    
    Volume {
      for layerID in 0..<4 {
        let y = 6 * Float(layerID)
        
        for positionZ in 0..<5 {
          let z = 5.75 * Float(positionZ)
          createHoleX(offset: SIMD3(0, y + 2.5, z + 0))
        }
        for positionX in 0..<2 {
          let x = 5.5 * Float(positionX)
          createHoleZ(offset: SIMD3(x + 0, y + 0, 0))
        }
        for positionX in 0..<5 {
          let x = 5.5 * Float(positionX)
          createHoleZ(offset: SIMD3(x + 13.5, y + 0, 0))
        }
        createHoleZ(offset: SIMD3(41, y + 0, 0))
      }
      
      for positionZ in 0..<4 {
        let z = 5.75 * Float(positionZ)
        createHoleY(offset: SIMD3(11, 0, z + 2.5))
      }
      for positionX in 1..<5 {
        let x = 5.5 * Float(positionX)
        createHoleY(offset: SIMD3(x + 11, 0, 17.75 + 2.5))
      }
      
      Replace { .empty }
    }
  }
  
  // MARK: - Rods
  
  let rodLatticeX = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 68 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
  }
  
  let rodLatticeY = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 40 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
  }
  
  let rodLatticeZ = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 43 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
  }
  
  func createRodX(offset: SIMD3<Float>) -> [Entity] {
    rodLatticeX.atoms.map {
      var copy = $0
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      copy.position += SIMD3(0, 0.85, 0.91)
      copy.position += offset * latticeConstant
      return copy
    }
  }
  
  func createRodY(offset: SIMD3<Float>) -> [Entity] {
    rodLatticeY.atoms.map {
      var copy = $0
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      copy.position = SIMD3(copy.position.z, copy.position.x, copy.position.y)
      copy.position += SIMD3(0.91, 0, 0.85)
      copy.position += offset * latticeConstant
      return copy
    }
  }
  
  func createRodZ(offset: SIMD3<Float>) -> [Entity] {
    rodLatticeZ.atoms.map {
      var copy = $0
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      copy.position = SIMD3(copy.position.z, copy.position.y, copy.position.x)
      copy.position += SIMD3(0.91, 0.85, 0)
      copy.position += offset * latticeConstant
      return copy
    }
  }
  
  // MARK: - Atoms
  
  var atoms: [Entity] = []
//  atoms += housingLattice.atoms
  
  for layerID in 0..<4 {
    let y = 6 * Float(layerID)
    
    for positionZ in 0..<5 {
      let z = 5.75 * Float(positionZ)
      atoms += createRodX(offset: SIMD3(0, y + 2.5, z + 0))
    }
    for positionX in 0..<2 {
      let x = 5.5 * Float(positionX)
      atoms += createRodZ(offset: SIMD3(x + 0, y + 0, 0))
    }
    for positionX in 0..<5 {
      let x = 5.5 * Float(positionX)
      atoms += createRodZ(offset: SIMD3(x + 13.5, y + 0, 0))
    }
    atoms += createRodZ(offset: SIMD3(41, y + 0, 0))
  }
  
  for positionZ in 0..<4 {
    let z = 5.75 * Float(positionZ)
    atoms += createRodY(offset: SIMD3(11, 0, z + 2.5))
  }
  for positionX in 1..<5 {
    let x = 5.5 * Float(positionX)
    atoms += createRodY(offset: SIMD3(x + 11, 0, 17.75 + 2.5))
  }
  
  
  var centerOfMass: SIMD3<Float> = .zero
  for atomID in atoms.indices {
    centerOfMass += atoms[atomID].position
  }
  centerOfMass /= Float(atoms.count)
  
  for atomID in atoms.indices {
    atoms[atomID].position -= centerOfMass
  }
 
  
  return atoms
}
