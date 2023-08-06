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
  var provider: OpenMM_AtomProvider
//  var provider: ArrayAtomProvider
  
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
    let latticeWidth: Int = 10
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
    
    do {
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
    
    var allAtoms = allCarbonCenters.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    }
//    self.provider = ArrayAtomProvider(allAtoms)
    
    let diamondoid = Diamondoid(atoms: allAtoms)
    print(diamondoid.atoms.count)
    
    let simulator = MM4(diamondoid: diamondoid, fsPerFrame: 20)
    simulator.simulate(ps: 10)
    provider = simulator.provider
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
