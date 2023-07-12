//
//  FCCCrystal.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/11/23.
//

import Foundation
import MolecularRenderer
import simd

struct FCCCrystalCuboid {
  var latticeConstant: Float
  var element: Int
  var plane: CrystalPlane
  
  var atoms: [MRAtom] = []
  
  init(
    latticeConstant: Float,
    element: Int,
    plane: CrystalPlane
  ) {
    self.latticeConstant = latticeConstant
    self.element = element
    self.plane = plane
    
    switch plane {
    case .plane100(let width, let height, let depth):
      precondition(
        width >= 2 && height >= 2 && depth >= 2, "Volume too small.")
      var numAtoms = width * height * depth
      numAtoms += (width - 1) * (height - 1) * depth
      numAtoms += (width - 1) * height * (depth - 1)
      numAtoms += width * (height - 1) * (depth - 1)
      
      let offset: SIMD3<Float> = [
        -Float((width - 1) / 2),
        -Float((height - 1) / 2),
        -Float((depth - 1) / 2),
      ]
      for i in 0..<width {
        for j in 0..<height {
          for k in 0..<depth {
            var coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
      for i in 0..<width - 1 {
        for j in 0..<height - 1 {
          for k in 0..<depth {
            var coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin.x += 0.5
            origin.y += 0.5
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
      for i in 0..<width - 1 {
        for j in 0..<height {
          for k in 0..<depth - 1 {
            var coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin.x += 0.5
            origin.z += 0.5
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
      for i in 0..<width {
        for j in 0..<height - 1 {
          for k in 0..<depth - 1 {
            var coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin.y += 0.5
            origin.z += 0.5
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
    case .plane111(let width, let diagonalHeight, let layers):
      // Based on: https://chem.libretexts.org/Bookshelves/Physical_and_Theoretical_Chemistry_Textbook_Maps/Surface_Science_(Nix)/01%3A_Structure_of_Solid_Surfaces/1.03%3A_Surface_Structures-_fcc_Metals#:~:text=in%20the%20troughs)-,The%20fcc%20(111)%20Surface,%2Dfold%2C%20hexagonal)%20symmetry.
      let spacingX = latticeConstant
      let spacingY = latticeConstant * sqrt(3)
      let spacingZ = latticeConstant * 2 * sqrt(2.0 / 3)
    }
  }
  
}
