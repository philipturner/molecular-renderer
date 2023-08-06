//
//  VdwOscillator.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/6/23.
//

import Foundation
import MolecularRenderer
import simd

// Experiment with two oscillators side-by-side, the first non-superlubricating
// and the second superlubricating. At the time of creation, the MM4 simulator
// lacked a thermostat, so simulations couldn't last more than a few 100 ps.

struct VdwOscillator {
//  var provider: OpenMM_AtomProvider
//  var provider: ArrayAtomProvider
  var provider: any MRAtomProvider
  
  init() {
    // Generate a cube, then cleave it along directions I want.
    //
    // Make a system that only uses (111) and (110) surfaces, filling in (100)
    // surfaces with other things to avoid the need for surface reconstruction.
    //
    // Debug the geometry generator, get things in the shapes you want. After
    // that's all debugged, send a final design through 'Diamondoid' and 'MM4'.
    
    struct Plane {
      var origin: SIMD3<Float>
      var normal: SIMD3<Float>
      
      init(origin: SIMD3<Float>, normal: SIMD3<Float>) {
        self.origin = origin
        self.normal = normal
      }
      
      init(_ latticeOrigin: SIMD3<Int>, normal: SIMD3<Float>) {
        self.origin = SIMD3(latticeOrigin) + 1e-2 * normalize(normal)
        self.normal = normalize(normal)
      }
      
      init(_ latticeOrigin: SIMD3<Float>, normal: SIMD3<Float>) {
        self.origin = SIMD3(latticeOrigin) + 1e-2 * normalize(normal)
        self.normal = normalize(normal)
      }
    }
    
    struct Cell {
      // Local coordinates within the cell, containing atoms that haven't been
      // removed yet. References to atoms may be duplicated across cells.
      var atoms: [SIMD3<Float>] = []
      
      var offset: SIMD3<Int>
      
      init() {
        self.offset = .zero
        
        for i in 0..<2 {
          for j in 0..<2 {
            for k in 0..<2 {
              if i ^ j ^ k == 0 {
                var position = SIMD3(Float(i), Float(j), Float(k))
                atoms.append(position)
                
                for axis in 0..<3 {
                  if position[axis] == 0 {
                    position[axis] = 0.25
                  } else {
                    position[axis] = 0.75
                  }
                }
                atoms.append(position)
              }
            }
          }
        }
        
        for axis in 0..<3 {
          var position = SIMD3<Float>(repeating: 0.5)
          position[axis] = 0
          atoms.append(position)
          
          position[axis] = 1
          atoms.append(position)
        }
      }
      
      // Atom-plane intersection function. Avoid planes that perfectly align
      // with the crystal lattice, as the results of intersection functions may
      // be unpredictable.
      mutating func cleave(planes: [Plane]) {
        atoms = atoms.compactMap {
          let atomOrigin = $0 + SIMD3<Float>(self.offset)
          
          var allIntersectionsPassed = true
          for plane in planes {
            let delta = atomOrigin - plane.origin
            let dotProduct = dot(delta, plane.normal)
            if abs(dotProduct) < 1e-8 {
              fatalError("Cleaved along a perfect plane of atoms.")
            }
            if dotProduct < 0 {
              allIntersectionsPassed = false
            }
          }
          
          if allIntersectionsPassed {
            return nil
          } else {
            return $0
          }
        }
      }
      
      func cleaved(planes: [Plane]) -> Cell {
        var copy = self
        copy.cleave(planes: planes)
        return copy
      }
      
      mutating func translate(offset: SIMD3<Int>) {
        self.offset &+= offset
      }
      
      func translated(offset: SIMD3<Int>) -> Cell {
        var copy = self
        copy.translate(offset: offset)
        return copy
      }
    }
    
    // Only using a cubic lattice for now.
    let latticeWidth: Int = 16
    var baseLattice: [Cell] = []
    let baseCell = Cell()
    for i in 0..<latticeWidth {
      for j in 0..<latticeWidth {
        for k in 0..<latticeWidth {
          let offset = SIMD3(i, j, k)
          baseLattice.append(baseCell.translated(offset: offset))
        }
      }
    }
    
    func makeCarbonCenters(cells: [Cell]) -> [SIMD3<Float>] {
      var dict: [SIMD3<Float>: Bool] = [:]
      for cell in cells {
        let offset = SIMD3<Float>(cell.offset)
        for atom in cell.atoms {
          dict[atom + offset] = true
        }
      }
      return Array(dict.keys)
    }
    
    // Remove cells from the grid that have already been 100% cleaved, to reduce
    // the compute cost of successive transformations.
    func cleave(cells: [Cell], planes: [Plane]) -> [Cell] {
      cells.compactMap {
        var cell = $0
        cell.cleave(planes: planes)
        if cell.atoms.count == 0 {
          return nil
        } else {
          return cell
        }
      }
    }
    
    var allCarbonCenters: [SIMD3<Float>] = []
    
    // Half the hole width in either dimension.
    let holeWidthX: Float = 2.0
    let holdWidthYZ: Float = 3.0
    
    do {
      var cells = baseLattice
      let blockOrigin = SIMD3<Float>(SIMD3(repeating: latticeWidth / 2))
      
      let innerBounds: [SIMD3<Float>] = [
        SIMD3(0, 2, 2),
        SIMD3(0, 4, -4),
        SIMD3(0, -2, -2),
        SIMD3(0, -4, 4),
      ]
      let thickness: Float = 0.5
      let outerBounds = innerBounds.map {
        $0 + thickness * SIMD3<Float>(
          (sign(Float($0.x))),
          (sign(Float($0.y))),
          (sign(Float($0.z))))
      }
      
      cells = cleave(cells: cells, planes: innerBounds.map {
        Plane(blockOrigin + $0, normal: SIMD3(0 - $0))
      })
      for bound in outerBounds {
        cells = cleave(cells: cells, planes: [
          Plane(blockOrigin + bound, normal: SIMD3(bound))
        ])
      }
      
      
      
      // Make a remover, then translate it several times across a diagonal line.
      // Repeat in the alternate direction to carve out pyramids, and once more
      // on the back.
      var outer100Removers: [[Plane]] = []
      var hole100Removers_first: [[Plane]] = []
      var hole100Removers_second: [[Plane]] = []
      for flippedX in [false, true] {
        for flippedYZ in [false, true] {
          let planeOrigin: SIMD3<Int> = SIMD3(
            flippedX ? 1 : latticeWidth - 1,
            latticeWidth / 2,
            latticeWidth / 2
          )
          let base100Remover: [Plane] = [
            Plane(
              planeOrigin,
              normal: [
                flippedX ? -1 : 1,
                flippedYZ ? 1 : 1,
                flippedYZ ? -1 : 1,
              ]),
            Plane(
              planeOrigin,
              normal: [
                flippedX ? -1 : 1,
                flippedYZ ? -1 : -1,
                flippedYZ ? 1 : -1,
              ]),
          ]
          
          for translationYZ_doubled in -16...16 {
            let translationYZ = Float(translationYZ_doubled) / 2
            var delta: SIMD3<Float>
            if flippedYZ {
              delta = SIMD3(0, -translationYZ, translationYZ)
            } else {
              delta = SIMD3(0, translationYZ, translationYZ)
            }
            var remover = base100Remover
            remover[0].origin += SIMD3(delta)
            remover[1].origin += SIMD3(delta)
            outer100Removers.append(remover)
            
            var newOrigin0_first = __tg_rint(remover[0].origin * 2) / 2
            var newOrigin1_first = __tg_rint(remover[1].origin * 2) / 2
            var newOrigin0_second: SIMD3<Float> = newOrigin0_first
            var newOrigin1_second: SIMD3<Float> = newOrigin1_first
            if newOrigin0_first.x == 1 {
              newOrigin0_first.x = Float(latticeWidth / 2) * 0.5 + holeWidthX
              newOrigin1_first.x = Float(latticeWidth / 2) * 0.5 + holeWidthX
              newOrigin0_second.x = Float(latticeWidth / 2) * 1.5 + holeWidthX
              newOrigin1_second.x = Float(latticeWidth / 2) * 1.5 + holeWidthX
            } else if newOrigin0_first.x == Float(latticeWidth - 1) {
              newOrigin0_first.x = Float(latticeWidth / 2) * 0.5 - holeWidthX
              newOrigin1_first.x = Float(latticeWidth / 2) * 0.5 - holeWidthX
              newOrigin0_second.x = Float(latticeWidth / 2) * 1.5 - holeWidthX
              newOrigin1_second.x = Float(latticeWidth / 2) * 1.5 - holeWidthX
            }
            newOrigin0_first.x += 0.5
            newOrigin1_first.x += 0.5
            newOrigin0_second.x -= 0.5
            newOrigin1_second.x -= 0.5
            
            remover[0] = Plane(newOrigin0_first, normal: remover[0].normal)
            remover[1] = Plane(newOrigin1_first, normal: remover[1].normal)
            hole100Removers_first.append(remover)
            
            remover[0] = Plane(newOrigin0_second, normal: remover[0].normal)
            remover[1] = Plane(newOrigin1_second, normal: remover[1].normal)
            hole100Removers_second.append(remover)
          }
        }
      }
      for remover in outer100Removers {
        cells = cleave(cells: cells, planes: remover)
      }
      
      for half in [0, 1] {
        let holeBounds: [SIMD3<Float>] = [
          SIMD3(Float(-holeWidthX), 0, 0),
          SIMD3(Float(+holeWidthX), 0, 0),
          SIMD3(0, Float(+holdWidthYZ), Float(-holdWidthYZ)),
          SIMD3(0, Float(-holdWidthYZ), Float(+holdWidthYZ)),
        ]
        var holePlanes: [Plane]
        if half == 0 {
          holePlanes = holeBounds.map {
            Plane(
              SIMD3(blockOrigin.x * 0.5, blockOrigin.y, blockOrigin.z) + $0,
              normal: SIMD3(0 - $0))
          }
        } else {
          holePlanes = holeBounds.map {
            Plane(
              SIMD3(blockOrigin.x * 1.5, blockOrigin.y, blockOrigin.z) + $0,
              normal: SIMD3(0 - $0))
          }
        }
        
        var holeRemovers: [[Plane]]
        if half == 0 {
          holeRemovers = hole100Removers_first
        } else {
          holeRemovers = hole100Removers_second
        }
        
        for remover in holeRemovers {
          var planes = remover + holePlanes
          let divider = (half == 0)
          ? Float(latticeWidth / 4)
          : Float(latticeWidth * 3 / 4)
          
          if planes[0].origin.x > divider {
            planes.append(
              Plane([divider - 1, 0, 0], normal: [1, 0, 0]))
          } else {
            planes.append(
              Plane([divider + 1, 0, 0], normal: [-1, 0, 0]))
          }
          cells = cleave(cells: cells, planes: planes)
        }
      }
      
      allCarbonCenters += makeCarbonCenters(cells: cells)
    }
    
    let allAtoms = allCarbonCenters.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    }
    print(allAtoms.count)
    self.provider = ArrayAtomProvider(allAtoms)
    
//    let diamondoid = Diamondoid(atoms: allAtoms)
//    print(diamondoid.atoms.count)
//    self.provider = ArrayAtomProvider(diamondoid.atoms)
//
//    let simulator = MM4(diamondoid: diamondoid, fsPerFrame: 20)
//    simulator.simulate(ps: 10)
//    provider = simulator.provider
  }
}

#if false
func makeTetrahedron() {
  var cells = baseLattice
  cells = cleave(cells: cells, planes: [
    Plane(SIMD3(0, latticeWidth, latticeWidth), normal: SIMD3(1, 1, 1)),
  ])
  cells = cleave(cells: cells, planes: [
    Plane(SIMD3(0, latticeWidth, latticeWidth), normal: SIMD3(-1, 1, -1)),
  ])
  cells = cleave(cells: cells, planes: [
    Plane(SIMD3(0, 0, 0), normal: SIMD3(-1, -1, 1)),
  ])
  cells = cleave(cells: cells, planes: [
    Plane(SIMD3(0, 0, 0), normal: SIMD3(1, -1, -1)),
  ])
  allCarbonCenters += makeCarbonCenters(cells: cells)
}
#endif


