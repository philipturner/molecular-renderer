//
//  VdwOscillator.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/6/23.
//

import Foundation
import MolecularRenderer
import QuartzCore
import simd

// Experiment with two oscillators side-by-side, the first non-superlubricating
// and the second superlubricating. At the time of creation, the MM4 simulator
// lacked a thermostat, so simulations couldn't last more than a few 100 ps.

struct VdwOscillator {
  var provider: any MRAtomProvider
  
  init() {
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
    
    func generateAtoms(
      _ latticePoints: [SIMD3<Float>]
    ) -> [MRAtom] {
      var hashMap: [SIMD3<Float>: Bool] = [:]
      for point in latticePoints {
        hashMap[point] = true
      }
      let allPoints = Array(hashMap.keys)
      return allPoints.map {
        MRAtom(origin: $0 * 0.357, element: 6)
      }
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
    
    func makeBaseLattice(width: Int) -> [Cell] {
      var output: [Cell] = []
      let baseCell = Cell()
      for i in 0..<width {
        for j in 0..<width {
          for k in 0..<width {
            let offset = SIMD3(i, j, k)
            output.append(baseCell.translated(offset: offset))
          }
        }
      }
      return output
    }
    
    let start = CACurrentMediaTime()
    var allAtoms: [MRAtom] = []
    var allDiamondoids: [Diamondoid] = []
    
    // Make a housing, where a solid diamond slab can fit inside it.
    do {
      let latticeWidth: Int = 10
      let thickness: Float = 2.0
      let shortening: Float = 0
      let width = Float(latticeWidth)
      let baseLattice = makeBaseLattice(width: 10)
      
      var bases: [[SIMD3<Float>]] = []
      for zDir in [Float(1), -1] {
        var cells = baseLattice
        cells = cleave(cells: cells, planes: [
          Plane([0, 0, width / 2], normal: [0, -1, -zDir])
        ])
        cells = cleave(cells: cells, planes: [
          Plane([0, 0, width / 2], normal: [0, -1, +zDir])
        ])
        cells = cleave(cells: cells, planes: [
          Plane([0, width, width / 2], normal: [0, +1, -zDir])
        ])
        cells = cleave(cells: cells, planes: [
          Plane([0, width, width / 2], normal: [0, +1, +zDir])
        ])
        cells = cleave(cells: cells, planes: [
          Plane([0, width, width / 2 * (1 - zDir)], normal: [0, -1, -zDir])
        ])
        
        do {
          let xShift: Float = zDir == 1 ? 0 : -1
          
          cells = cleave(cells: cells, planes: [
            Plane(
              [0, width - 1, width / 2],
              normal: [0, -1, +1]),
            Plane(
              [0, width - 1, width / 2],
              normal: [0, -1, -1]),
          ])
          cells = cleave(cells: cells, planes: [
            Plane(
              [width - 0.5 + xShift, width - 1, width / 2],
              normal: [+1, +1, -1]),
          ])
          cells = cleave(cells: cells, planes: [
            Plane(
              [width - 0.5 + xShift, width, width / 2],
              normal: [+1, -1, +1]),
            Plane(
              [0, width - 1, width / 2],
              normal: [0, -1, -1]),
          ])
          cells = cleave(cells: cells, planes: [
            Plane(
              [zDir == 1 ? width - 1.5 : width + xShift, width - 1, width / 2],
              normal: [+1, +1, +1]),
          ])
          cells = cleave(cells: cells, planes: [
            Plane(
              [zDir == 1 ? width - 1.5 : width + xShift, width, width / 2],
              normal: [+1, -1, -1]),
            Plane(
              [0, width - 1, width / 2],
              normal: [0, -1, +1]),
          ])
          cells = cleave(cells: cells, planes: [
            Plane(
              [zDir == 1 ? width - 1.1 : width - 0.5 + xShift, 0, 0],
              normal: [+1, 0, 0]),
          ])
        }
        let holeX: Float = width / 2 + (zDir == 1 ? 1 : 2)
        let holeOffset: Float = 0
        let pos1 = holeOffset + 0.25 - 0.25 * zDir
        let pos2 = holeOffset + 1.25 - 0.25 * zDir
        
        cells = cleave(cells: cells, planes: [
          Plane(
            [pos1, width / 2, width / 2 * (1 + zDir)],
            normal: [1, 1, zDir]),
          Plane(
            [0, width, width / 2 + 2 * zDir],
            normal: [0, -1, zDir]),
          Plane(
            [holeX + 0.5 * zDir, width / 2, width / 2 * (1 + zDir)],
            normal: [-1, 1, zDir]),
        ])
        cells = cleave(cells: cells, planes: [
          Plane(
            [pos2, width / 2, width / 2 * (1 + zDir)],
            normal: [1, -1, -zDir]),
          Plane(
            [0, width, width / 2 + 2 * zDir],
            normal: [0, -1, zDir]),
          Plane(
            [holeX - 1 + 0.5 * zDir, width / 2, width / 2 * (1 + zDir)],
            normal: [-1, -1, -zDir]),
        ])
        bases.append(makeCarbonCenters(cells: cells))
      }
      
      func rotate(
        _ base: [SIMD3<Float>],
        flipX: Bool = false,
        flipY: Bool = false,
        flipZ: Bool = false,
        flipYZ: Bool = false,
        rotateYZClockwise: Int = 0
      ) -> [SIMD3<Float>] {
        base.map {
          var output = SIMD3(
            flipX ? 0 - $0.x : $0.x,
            flipY ? 5 - ($0.y - 5) : $0.y,
            flipZ ? 5 - ($0.z - 5) : $0.z)
          if flipYZ {
            let origin = SIMD3<Float>(0, 0, 10)
            var delta = output - origin
            let deltaY = delta.y
            let deltaZ = delta.z
            delta.y = -deltaZ
            delta.z = -deltaY
            output = origin + delta
          }
          for _ in 0..<rotateYZClockwise {
            let oldY = output.y
            let oldZ = output.z - 5
            output.y = oldZ + 0 + 5
            output.z = -oldY + 5 + 5
          }
          return output
        }
      }
      
      var backCenters = bases[1]
      backCenters += rotate(bases[1], flipYZ: true)
      backCenters += rotate(backCenters, rotateYZClockwise: 2)
      backCenters = rotate(backCenters, flipX: true, flipZ: true)
      
      let frontCenters = rotate(backCenters, flipX: true, flipZ: true)
      let thisCenters = frontCenters + backCenters
      let thisAtoms = generateAtoms(thisCenters)
      allAtoms += thisAtoms
//
//      var diamondoid = Diamondoid(atoms: thisAtoms)
//      diamondoid.fixHydrogens(tolerance: 0.08) { _ in true }
//      allAtoms += diamondoid.atoms
//      allDiamondoids.append(diamondoid)
    }
    
    // Make a diamond slab that isn't superlubricant (attempt 1).
    do {
      // Adjustable parameters.
      let latticeWidth: Int = 10
      let thickness: Float = 1
      let shortening: Float = 2
      let width = Float(latticeWidth)
      let baseLattice = makeBaseLattice(width: latticeWidth)
      
      var cells = baseLattice
      cells = cleave(cells: cells, planes: [
        Plane(
          [width / 2, width / 2 - thickness, width / 2],
          normal: [1, -1, 0])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width / 2, width / 2 + thickness, width / 2],
          normal: [-1, 1, 0])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - thickness, width, 0],
          normal: [1, 1, 0])
      ])
      
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - thickness, width, width - 3 * thickness / 2],
          normal: [-1, 1, 1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - thickness, width, thickness / 2],
          normal: [-1, 1, -1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width - thickness, width - 3 * thickness / 2],
          normal: [1, -1, 1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width - thickness, thickness / 2],
          normal: [1, -1, -1]),
      ])
      
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width, width - 5 * thickness / 2],
          normal: [1, 1, 1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width, 3 * thickness / 2],
          normal: [1, 1, -1])
      ])
      
      var thisCenters = makeCarbonCenters(cells: cells)
      thisCenters = thisCenters.map {
        $0 - SIMD3(shortening, shortening, 0)
      }
      thisCenters += thisCenters.map { center in
        SIMD3(-center.y, -center.x, center.z)
      }
//      
//      let thisAtoms = generateAtoms(thisCenters)
//      allAtoms += thisAtoms
      
//      let diamondoid = Diamondoid(atoms: thisAtoms)
//      allAtoms += diamondoid.atoms
//      allDiamondoids.append(diamondoid)
    }
    
    // Make a diamond slab that isn't superlubricant (attempt 2).
    do {
      // Adjustable parameters.
      
      // Step 1 (easy): reverse the orientation of the inner piece, try to
      // make the interfaces not match.
      
      // Step 2: make the thickness 2 on the left, 2.5 on the right, and
      // reposition the rod to be centered. Close the gap and degrees of
      // freedom.
      
      // Step 3: try the uneven slab surface above, but linking several such
      // pieces in an alternating fashion with something like Kaehler brackets.
      // Or linking them together in a way they won't fall apart.
      let latticeWidth: Int = 10
      let thickness: Float = 2.0
      let shortening: Float = 0
      let width = Float(latticeWidth)
      let baseLattice = makeBaseLattice(width: latticeWidth)
      
      var cells = baseLattice
      cells = cleave(cells: cells, planes: [
        Plane(
          [0, width / 2 + thickness, width / 2],
          normal: [0, 1, 1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [0, width / 2 + thickness, width / 2],
          normal: [0, 1, -1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [0, width / 2 - thickness, width / 2],
          normal: [0, -1, 1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [0, width / 2 - thickness, width / 2],
          normal: [0, -1, -1])
      ])
      
      cells = cleave(cells: cells, planes: [
        Plane(
          [width  - 0.5, width / 2, width / 2],
          normal: [1, 1, 1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - 0.5, width / 2, width / 2],
          normal: [1, -1, 1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - 0.5, width / 2, width / 2],
          normal: [1, 1, -1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width  - 0.5, width / 2, width / 2],
          normal: [1, -1, -1])
      ])
      
      var thisCenters = makeCarbonCenters(cells: cells)
      thisCenters = thisCenters.map {
        $0 - SIMD3(shortening, shortening, 0)
      }
      thisCenters += thisCenters.map { center in
        SIMD3(-center.x, width - center.y, center.z)
      }
      thisCenters = thisCenters.map {
        $0 + SIMD3(10, 0, 0)
      }
      
      // Flip across the XY plane.
      thisCenters = thisCenters.map { center in
        SIMD3(center.x, center.y, width - center.z)
      }
      
      let thisAtoms = generateAtoms(thisCenters)
//      allAtoms += thisAtoms
//      
//      let diamondoid = Diamondoid(atoms: thisAtoms)
//      allAtoms += diamondoid.atoms
//      allDiamondoids.append(diamondoid)
    }
    
    print(allAtoms.count)
    self.provider = ArrayAtomProvider(allAtoms)
    
    let end = CACurrentMediaTime()
    print("""
      Took \(String(format: "%.3f", end - start)) seconds to generate the \
      structure.
      """)

//    let simulator = MM4(diamondoids: allDiamondoids, fsPerFrame: 500)
//    simulator.simulate(ps: 250)
//    provider = simulator.provider
  }
}
