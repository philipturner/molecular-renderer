//
//  FCCCrystal.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/11/23.
//

import Foundation
import MolecularRenderer
import simd

struct GoldCuboid {
  var latticeConstant: Float
  let element: Int = 79
  var plane: CrystalPlane
  
  var atoms: [MRAtom] = []
  
  init(
    latticeConstant: Float,
    plane: CrystalPlane
  ) {
    self.latticeConstant = latticeConstant
    self.plane = plane
    
    switch plane {
    case .fcc100(let width, let height, let depth):
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
            let coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
      for i in 0..<width - 1 {
        for j in 0..<height - 1 {
          for k in 0..<depth {
            let coords = SIMD3<Int>(i, j, k)
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
            let coords = SIMD3<Int>(i, j, k)
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
            let coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin.y += 0.5
            origin.z += 0.5
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
    case .fcc111(let width, let diagonalHeight, let layers):
      // Based on: https://chem.libretexts.org/Bookshelves/Physical_and_Theoretical_Chemistry_Textbook_Maps/Surface_Science_(Nix)/01%3A_Structure_of_Solid_Surfaces/1.03%3A_Surface_Structures-_fcc_Metals#:~:text=in%20the%20troughs)-,The%20fcc%20(111)%20Surface,%2Dfold%2C%20hexagonal)%20symmetry.
      let spacingX = latticeConstant
      let spacingY = latticeConstant * sqrt(3)
      let spacingZ = latticeConstant * 2 * sqrt(2.0 / 3)
      _ = spacingX
      _ = spacingY
      _ = spacingZ
      _ = width
      _ = diagonalHeight
      _ = layers
      fatalError("(111) not supported yet.")
    }
  }
}

struct DiamondCuboid {
  var latticeConstant: Float
  var hydrogenBondLength: Float
  let element: Int = 6
  var plane: CrystalPlane
  
  // Inclusive start/end of the hollow part.
  var hollowStart: SIMD3<Int>?
  var hollowEnd: SIMD3<Int>?
  
  var atoms: [MRAtom] = []
  
  init(
    latticeConstant: Float,
    hydrogenBondLength: Float,
    plane: CrystalPlane,
    hollowStart: SIMD3<Int>? = nil,
    hollowEnd: SIMD3<Int>? = nil
  ) {
    self.latticeConstant = latticeConstant
    self.hydrogenBondLength = hydrogenBondLength
    self.plane = plane
    self.hollowStart = hollowStart
    self.hollowEnd = hollowEnd
    
    var width: Int
    var height: Int
    var depth: Int
    switch plane {
    case .fcc100(let _width, let _height, let _depth):
      width = _width
      height = _height
      depth = _depth
    default:
      fatalError("Need (100) plane.")
    }
    
    struct Hydrogen {
      var origin: SIMD3<Float>
      var direction: SIMD3<Float>
    }
    var carbons: [SIMD3<Float>] = []
    var hydrogens: [Hydrogen] = []
    
    struct Lattice {
      var bounds: SIMD3<Int>
      var offset: SIMD3<Float>
      var alternating: Bool = false
      var hasHydrogens: Bool = true
    }
    let lattices: [Lattice] = [
      Lattice(
        bounds: [width + 1, height + 1, depth + 1], offset: [0, 0, 0],
        alternating: true),
      
      Lattice(bounds: [width + 1, height, depth], offset: [0, 0.5, 0.5]),
      Lattice(bounds: [width, height + 1, depth], offset: [0.5, 0, 0.5]),
      Lattice(bounds: [width, height, depth + 1], offset: [0.5, 0.5, 0]),
      
      Lattice(
        bounds: [width, height, depth], offset: [0.25, 0.25, 0.25],
        hasHydrogens: false),
      Lattice(
        bounds: [width, height, depth], offset: [0.25, 0.75, 0.75],
        hasHydrogens: false),
      Lattice(
        bounds: [width, height, depth], offset: [0.75, 0.25, 0.75],
        hasHydrogens: false),
      Lattice(
        bounds: [width, height, depth], offset: [0.75, 0.75, 0.25],
        hasHydrogens: false),
    ]
    
    let center: SIMD3<Float> = [
       Float(width) / 2 + 0.5,
       Float(height) / 2 + 0.5,
       Float(depth) / 2 + 0.5,
    ]
    var minCoords: SIMD3<Float> = center
    var maxCoords: SIMD3<Float> = center
    if let hollowStart, let hollowEnd {
      minCoords = SIMD3(hollowStart)
      maxCoords = SIMD3(hollowEnd)
    }
    
    for lattice in lattices {
      for i in 0..<lattice.bounds.x {
        for j in 0..<lattice.bounds.y {
          for k in 0..<lattice.bounds.z {
            if lattice.alternating {
              if (i ^ j ^ k) & 1 != 0 {
                continue
              }
            }
            
            var coords = SIMD3<Float>(SIMD3(i, j, k))
            coords += lattice.offset
            if all(coords .> minCoords) && all(coords .< maxCoords) {
              continue
            }
            carbons.append(coords)
            
            // Add hydrogens to the outside.
            guard lattice.hasHydrogens else {
              continue
            }
            let bounds = SIMD3<Float>(SIMD3(width, height, depth))
            if any(coords .== 0) || any(coords .== bounds) {
              var direction: SIMD3<Float> = .zero
              for component in 0..<3 {
                if coords[component] == 0 {
                  direction[component] = -1
                } else if coords[component] == bounds[component] {
                  direction[component] = +1
                }
              }
              
              hydrogens.append(
                Hydrogen(origin: coords, direction: direction))
            }
            
            // TODO: Also add hydrogens to the occluded inside.
          }
        }
      }
    }
    
    // Offset by the center, then scale by the lattice constant.
    for coords in carbons {
      let origin = latticeConstant * (coords - center)
      atoms.append(MRAtom(origin: origin, element: 6))
    }
    
    // Use an additional physical constant for hydrogens.
    for hydrogen in hydrogens {
      var origin = latticeConstant * (hydrogen.origin - center)
      origin += hydrogenBondLength * normalize(hydrogen.direction)
      atoms.append(MRAtom(origin: origin, element: 1))
    }
  }
}
