//
//  VdwOscillator.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/6/23.
//

import Foundation
import MolecularRenderer
import QuaternionModule

#if false

// Experiment with an attractive force bearing, originally non-superlubricating
// and later superlubricating. At the time of creation, the MM4 simulator
// lacked a thermostat, so (it was hypothesized) simulations couldn't last more
// than a few 100 ps. Recent experiments suggest far longer timescales are
// possible, even with NVE simulations at 4 fs/step.

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
        self.origin = SIMD3(latticeOrigin) + 1e-2 * cross_platform_normalize(normal)
        self.normal = cross_platform_normalize(normal)
      }
      
      init(_ latticeOrigin: SIMD3<Float>, normal: SIMD3<Float>) {
        self.origin = SIMD3(latticeOrigin) + 1e-2 * cross_platform_normalize(normal)
        self.normal = cross_platform_normalize(normal)
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
            let dotProduct = cross_platform_dot(delta, plane.normal)
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
    
    func centerAtOrigin(_ rawCenters: [SIMD3<Float>]) -> [SIMD3<Float>] {
      var hashMap: [SIMD3<Float>: Bool] = [:]
      for point in rawCenters {
        hashMap[point] = true
      }
      let centers = Array(hashMap.keys)
      
      var averagePosition = centers.reduce(SIMD3<Float>.zero, +)
      averagePosition /= Float(centers.count)
      return centers.map { $0 - averagePosition }
    }
    
    let start = cross_platform_media_time()
    var allAtoms: [MRAtom] = []
    var allDiamondoids: [Diamondoid] = []
    
    // Make a housing, where a solid diamond slab can fit inside it.
    do {
      let latticeWidth: Int = 18
      let thickness: Float = 3.0
      let width = Float(latticeWidth)
      let baseLattice = makeBaseLattice(width: latticeWidth)
      
      var bases: [[SIMD3<Float>]] = []
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
        
        do {
          let holeX: Float = 6
          let holePlanes = [
            Plane(
              [holeX + 1, width - 3, width / 2 - 1.5], normal: [-1, +1, -1]),
            Plane(
              [holeX + 1, width - 3, width / 2 - 1.5], normal: [-1, -1, +1]),
          ]
          cells = cleave(cells: cells, planes: [
            Plane([holeX, 0, 0], normal: [-1, 0, 0]),
            Plane([0, width - 2.5, width / 2 - 2], normal: [0, -1, -1]),
            Plane([0, width - 3.75, width / 2 - 1.75], normal: [0, +1, -1]),
            Plane([holeX, width - 4, width / 2 - 1.5], normal: [-1, -1, -1]),
          ])
          for i in 0..<2 {
            cells = cleave(cells: cells, planes: [
              Plane([holeX + 2, 0, 0], normal: [-1, 0, 0]),
              Plane([0, width - 4, width / 2 - 1.5], normal: [0, -1, -1]),
              Plane([holeX, width - 4, width / 2 - 1.5], normal: [-1, -1, -1]),
              holePlanes[i],
            ])
          }
        }
        do {
          let holePlanes = [
            Plane(
              [2, width - 3, width / 2 + 1.5], normal: [-1, +1, +1]),
            Plane(
              [2, width - 3, width / 2 + 1.5], normal: [-1, -1, -1]),
          ]
          for i in 0..<2 {
            cells = cleave(cells: cells, planes: [
              Plane([2.75, 0, 0], normal: [-1, 0, 0]),
              Plane([0, width - 4, width / 2 + 1.5], normal: [0, -1, +1]),
              Plane([0.5, width - 4, width / 2 + 1.5], normal: [-1, -1, +1]),
              holePlanes[i],
            ])
          }
          
          // Remove a lone atom that's sticking out with 3 dangling bonds.
          cells = cleave(cells: cells, planes: [
            Plane([0, 0, width / 2 + 2], normal: [0, 0, +1]),
            Plane([0.25, 0, 0], normal: [-1, 0, 0]),
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
      diamondoid.fixHydrogens(tolerance: 0.08) { _ in true }
      allAtoms += diamondoid.atoms
      allDiamondoids.append(diamondoid)
    }
    
    // Make a diamond slab that is superlubricant.
    do {
      // Adjustable parameters.
      let latticeWidth: Int = 14 // 16
      let widthZP = Float(6)
      let widthZM = Float(6)
      let repetitionDepth: Int = 3
      let shortening: Float = 4 // 2
      let width = Float(latticeWidth)
      let baseLattice = makeBaseLattice(width: latticeWidth)
      
      var cells = baseLattice
      cells = cleave(cells: cells, planes: [
        Plane(
          [width / 2, width / 2 - 1.5, 0],
          normal: [1, -1, 0])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width / 2, width / 2 + 1.5, 0],
          normal: [-1, 1, 0])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - 1, width, 0],
          normal: [1, 1, 0])
      ])
      
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - 1, width, widthZP - 3 * 1 / 2],
          normal: [-1, 1, 1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width - 1, width, 1 / 2],
          normal: [-1, 1, -1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width - 1, widthZP - 3 * 1 / 2],
          normal: [1, -1, 1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width - 1, 1 / 2],
          normal: [1, -1, -1]),
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width, widthZP - 5 * 1 / 2],
          normal: [1, 1, 1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane(
          [width, width, 3 * 1 / 2],
          normal: [1, 1, -1])
      ])
      
      var thisCenters = makeCarbonCenters(cells: cells)
      thisCenters = thisCenters.map {
        $0 - SIMD3(shortening, shortening, 0)
      }
      thisCenters += thisCenters.map { center in
        SIMD3(-center.y, -center.x, center.z)
      }
      thisCenters += thisCenters.map {
        $0 + SIMD3(0, 0, -1)
      }
      
      precondition(
        Int(exactly: widthZM)! % 2 == 0 &&
        Int(exactly: widthZP)! % 2 == 0)
      if widthZM != widthZP {
        precondition(widthZM > widthZP)
        let extraLayers = Int(exactly: widthZM - widthZP)! / 2
        
        let baseCenters = thisCenters
        for i in 0..<extraLayers {
          thisCenters += baseCenters.map {
            $0 + SIMD3(0, 0, Float(-i))
          }
        }
      }
      
      let baseCenters = thisCenters
      for i in 0..<repetitionDepth {
        let delta = SIMD3<Float>(SIMD3<Int>(i, -i, 0))
        thisCenters += baseCenters.map {
          $0 + delta
        }
      }
      thisCenters = centerAtOrigin(thisCenters)

      let thisAtoms = generateAtoms(thisCenters)
//      allAtoms += thisAtoms
//
      var diamondoid = Diamondoid(atoms: thisAtoms)
      diamondoid.fixHydrogens(tolerance: 0.08)
      let removedIndices = diamondoid.findAtoms(where: {
        var compareZ = $0.origin.z
        #if false
        // Skip the absolute value, increasing width by a tiny amount.
        #else
        compareZ = abs(compareZ)
        #endif
        if $0.element == 1 {
          return compareZ > 3.00 * 0.357 - 0.01
        } else {
          return compareZ > 2.75 * 0.357 - 0.01
        }
      })
      diamondoid.removeAtoms(atIndices: removedIndices)
      
      let rotation1 = Quaternion<Float>(angle: -.pi / 4, axis: [0, 0, 1])
      let rotation2 = Quaternion<Float>(angle: -.pi / 4, axis: [1, 0, 0])
      diamondoid.rotate(angle: rotation1)
      diamondoid.rotate(angle: rotation2)
      diamondoid.translate(offset: SIMD3(14 * 0.357, 0, 0))
      
      allAtoms += diamondoid.atoms
      allDiamondoids.append(diamondoid)
    }
    
    print(allAtoms.count)
    self.provider = ArrayAtomProvider(allAtoms)
    
    let end = cross_platform_media_time()
    print("""
      Took \(String(format: "%.3f", end - start)) seconds to generate the \
      structure.
      """)
    
    #if true
    // Minimize the energy of each diamondoid.
    for i in allDiamondoids.indices {
      allDiamondoids[i].minimize()
    }
    
    // 20 fs/frame @ 3-10 ps
    // 100 fs/frame @ 50 ps
    // 500 fs/frame @ 250 ps
    
    // Doing another trial run at 250 ps / 500 fs, with testing how the spinning
    // orbit will look, and testing the graphs. Then go for the full 1 ns.
    let simulator = _Old_MM4(
      diamondoids: allDiamondoids, fsPerFrame: 500) // 200
    simulator.simulate(ps: 1000, trackingState: true) // 150
    provider = simulator.provider
    #endif
  }
}

#endif
