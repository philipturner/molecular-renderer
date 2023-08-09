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
    
    func centerAtOrigin(_ centers: [SIMD3<Float>]) -> [SIMD3<Float>] {
      var averagePosition = centers.reduce(SIMD3<Float>.zero, +)
      averagePosition /= Float(centers.count)
      return centers.map { $0 - averagePosition }
    }
    
    let start = CACurrentMediaTime()
    var allAtoms: [MRAtom] = []
    var allDiamondoids: [Diamondoid] = []
    
    // Make a housing, where a solid diamond slab can fit inside it.
    do {
      let latticeWidth: Int = 18
      let widthX = Float(14)
      let thickness: Float = 3.0
      let width = Float(latticeWidth)
      let baseLattice = makeBaseLattice(width: latticeWidth)
      
      var bases: [[SIMD3<Float>]] = []
      let zDir = Float(-1)
      do {
        var cells = baseLattice
        
        cells = cleave(cells: cells, planes: [
          Plane([0, 0, width / 2], normal: [0, -1, +1]),
        ])
        cells = cleave(cells: cells, planes: [
          Plane([0, 0, width / 2], normal: [0, -1, -1])
        ])
        cells = cleave(cells: cells, planes: [
          Plane([0, width, width / 2], normal: [0, +1, +1]),
        ])
        cells = cleave(cells: cells, planes: [
          Plane([0, width, width / 2], normal: [0, +1, -1]),
        ])
        cells = cleave(cells: cells, planes: [
          Plane([0, width, width / 2 * 2], normal: [0, -1, +1])
        ])
        cells = cleave(cells: cells, planes: [
          Plane([0, width / 2, width / 2], normal: [0, -1, -1])
        ])
        
        do {
          // Add some circular supports on the corners for improved stiffness.
          let cornerPlanes = [
            Plane([0, width - 4.75, width / 2], normal: [0, -1, +1]),
            Plane([0, width - 3.75, 0], normal: [0, -1, 0]),
            Plane([0, width - 4.75, width / 2], normal: [0, -1, -1]),
          ]
          
          let topPlanes1 = [
            Plane([0, width - 2.5, 0], normal: [0, +1, 0]),
            Plane([0, width - 0.5, width / 2], normal: [0, +1, +1]),
            Plane([0, width - 0.5, width / 2], normal: [0, +1, -1]),
          ]
          
          let topPlanes2 = [
            Plane([0, width - 1.75, 0], normal: [0, +1, 0]),
            Plane([0, width - 1.00, width / 2], normal: [0, +1, +1]),
            Plane([0, width - 1.00, width / 2], normal: [0, +1, -1]),
          ]
          
          for i in 0..<2 {
            cells = cleave(cells: cells, planes: [
              topPlanes1[0],
              topPlanes1[i + 1],
            ])
          }
          
          for i in 0..<2 {
            cells = cleave(cells: cells, planes: [
              topPlanes2[0],
              topPlanes2[i + 1],
            ])
          }
          
          for i in 0..<2 {
            cells = cleave(cells: cells, planes: [
              Plane(
                [0,
                 width - thickness,
                 width / 2],
                normal: [0, -1, +1]),
              Plane(
                [0,
                 width - thickness,
                 width / 2],
                normal: [0, -1, -1]),
              cornerPlanes[i],
              cornerPlanes[i + 1],
            ])
          }
          cells = cleave(cells: cells, planes: [
            Plane(
              [19.5,
               width - thickness,
               width / 2],
              normal: [+1, +1, -1]),
          ])
          cells = cleave(cells: cells, planes: [
            Plane(
              [19.5,
               width,
               width / 2],
              normal: [+1, -1, +1]),
            Plane(
              [20,
               width,
               width / 2],
              normal: [+1, -1, -1]),
          ])
          cells = cleave(cells: cells, planes: [
            Plane(
              [19,
               width - thickness,
               width / 2],
              normal: [+1, +1, +1]),
          ])
        }
        
        // Make part of the hole appear on the other side. That way, the hole's
        // boundary isn't just limited by the halfway mark.
        do {
          let holePlanes = [
            Plane([10, width - 3, width / 2 - 1.5], normal: [-1, +1, -1]),
            Plane([10, width - 3, width / 2 - 1.5], normal: [-1, -1, +1]),
          ]
          
          cells = cleave(cells: cells, planes: [
            Plane([9, 0, 0], normal: [-1, 0, 0]),
            Plane([0, width - 2, width / 2 - 1.5], normal: [0, -1, -1]),
            Plane([0, width - 3, width / 2 - 1.5], normal: [0, +1, -1]),
            Plane([9, width - 4, width / 2 - 1.5], normal: [-1, -1, -1]),
          ])
          cells = cleave(cells: cells, planes: [
            Plane([10, 0, 0], normal: [-1, 0, 0]),
            Plane([0, width - 3, width / 2 - 1.5], normal: [0, -1, -1]),
            Plane([0, width - 4, width / 2 - 1.5], normal: [0, +1, -1]),
            Plane([9, width - 4, width / 2 - 1.5], normal: [-1, -1, -1]),
          ])
          for i in 0..<2 {
            cells = cleave(cells: cells, planes: [
              Plane([11, 0, 0], normal: [-1, 0, 0]),
              Plane([0, width - 4, width / 2 - 1.5], normal: [0, -1, -1]),
              Plane([9, width - 4, width / 2 - 1.5], normal: [-1, -1, -1]),
              holePlanes[i]
            ])
          }
        }
        do {
          let baseX: Float = 2
          
          let holePlanes = [
            Plane(
              [baseX + 1, width - 3, width / 2 + 1.5], normal: [-1, +1, +1]),
            Plane(
              [baseX + 1, width - 3, width / 2 + 1.5], normal: [-1, -1, -1]),
          ]
          
          cells = cleave(cells: cells, planes: [
            Plane([baseX, 0, 0], normal: [-1, 0, 0]),
            Plane([0, width - 2, width / 2 + 1.5], normal: [0, -1, +1]),
            Plane([0, width - 3, width / 2 + 1.5], normal: [0, +1, +1]),
            Plane([baseX, width - 4, width / 2 + 1.5], normal: [-1, -1, +1]),
          ])
          cells = cleave(cells: cells, planes: [
            Plane([baseX + 1, 0, 0], normal: [-1, 0, 0]),
            Plane([0, width - 3, width / 2 + 1.5], normal: [0, -1, +1]),
            Plane([0, width - 4, width / 2 + 1.5], normal: [0, +1, +1]),
            Plane([baseX, width - 4, width / 2 + 1.5], normal: [-1, -1, +1]),
          ])
          for i in 0..<2 {
            cells = cleave(cells: cells, planes: [
              Plane([baseX + 1.75, 0, 0], normal: [-1, 0, 0]),
              Plane([0, width - 4, width / 2 + 1.5], normal: [0, -1, +1]),
              Plane([baseX, width - 4, width / 2 + 1.5], normal: [-1, -1, +1]),
              holePlanes[i]
            ])
          }
          
          // Remove a lone atom that's sticking out with 3 dangling bonds.
          cells = cleave(cells: cells, planes: [
            Plane([0, 0, width / 2 + 2.25], normal: [0, 0, +1]),
            Plane([baseX + 0.25, 0, 0], normal: [-1, 0, 0]),
          ])
        }
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
            flipY ? width / 2 - ($0.y - width / 2) : $0.y,
            flipZ ? width / 2 - ($0.z - width / 2) : $0.z)
          if flipYZ {
            let origin = SIMD3<Float>(0, 0, width)
            var delta = output - origin
            let deltaY = delta.y
            let deltaZ = delta.z
            delta.y = -deltaZ
            delta.z = -deltaY
            output = origin + delta
          }
          for _ in 0..<rotateYZClockwise {
            let oldY = output.y
            let oldZ = output.z - width / 2
            output.y = oldZ + 0 + width / 2
            output.z = -oldY + width / 2 + width / 2
          }
          return output
        }
      }
      
//      allAtoms += generateAtoms(bases[0])
      
      var frontCenters = bases[0]
      frontCenters += rotate(bases[0], flipYZ: true)
      frontCenters += rotate(frontCenters, rotateYZClockwise: 2)
      frontCenters = rotate(frontCenters, flipX: true, flipZ: true)
//      allAtoms += generateAtoms(frontCenters)
      
      let backCenters = rotate(frontCenters, flipX: true, flipZ: true)
      var thisCenters = backCenters + frontCenters
      thisCenters = centerAtOrigin(thisCenters)
      let thisAtoms = generateAtoms(thisCenters)
//      allAtoms += thisAtoms
      
      var diamondoid = Diamondoid(atoms: thisAtoms)
//      diamondoid.fixHydrogens(tolerance: 0.08) { _ in true }
      allAtoms += diamondoid.atoms
      allDiamondoids.append(diamondoid)
    }
    
    // Make a diamond slab that is superlubricant.
    do {
      // Adjustable parameters.
      let latticeWidth: Int = 12 // 16
      let widthZ = Float(4)
      let thickness: Float = 1
      let shortening: Float = 4 // 2
      let width = Float(latticeWidth)
      let baseLattice = makeBaseLattice(width: latticeWidth)
      
      var cells = baseLattice
      cells = cleave(cells: cells, planes: [
        Plane(
          [width / 2, width / 2 - thickness, widthZ / 2],
          normal: [1, -1, 0])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width / 2, width / 2 + thickness, widthZ / 2],
          normal: [-1, 1, 0])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - thickness, width, 0],
          normal: [1, 1, 0])
      ])
      
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - thickness, width, widthZ - 3 * thickness / 2],
          normal: [-1, 1, 1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - thickness, width, thickness / 2],
          normal: [-1, 1, -1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width - thickness, widthZ - 3 * thickness / 2],
          normal: [1, -1, 1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width - thickness, thickness / 2],
          normal: [1, -1, -1]),
      ])
      
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width, widthZ - 5 * thickness / 2],
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
      
      let baseCenters = thisCenters
      thisCenters += baseCenters.map {
        $0 + SIMD3(1, -1, 0)
      }
      let rotation1 = simd_quatf(angle: -.pi / 4, axis: [0, 0, 1])
      let rotation2 = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])
      for i in thisCenters.indices {
        var center = thisCenters[i]
        
        let origin1 = SIMD3<Float>(0, width / 2, widthZ / 2)
        var delta = center - origin1
        delta = simd_act(rotation1, delta)
        center = delta + origin1
        
        let origin2 = SIMD3<Float>(0, width / 2, widthZ / 2)
        delta = center - origin2
        delta = simd_act(rotation2, delta)
        center = delta + origin2
        
//        // This time, find the center of mass of the housing diamondoid. Use
//        // that to move the atoms of the rod into the correct position, after
//        // transforming from lattice space to nanometers.
//        thisCenters[i] = center + SIMD3(13, 3.75, 0.75)
      }
      thisCenters = centerAtOrigin(thisCenters)
      let thisAtoms = generateAtoms(thisCenters)
//      allAtoms += thisAtoms
      
//      var diamondoid = Diamondoid(atoms: thisAtoms)
//      diamondoid.fixHydrogens(tolerance: 0.08) { _ in true }
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
    
    // 20 fs/frame @ 3-10 ps
    // 100 fs/frame @ 50 ps
    // 500 fs/frame @ 250 ps
//    let simulator = MM4(diamondoids: allDiamondoids, fsPerFrame: 20)
//    simulator.simulate(ps: 3)
//    provider = simulator.provider
  }
}
