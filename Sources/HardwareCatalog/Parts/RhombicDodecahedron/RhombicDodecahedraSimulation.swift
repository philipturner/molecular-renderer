//
//  RhombicDodecahedra.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/6/23.
//

import Foundation
import MolecularRenderer

#if false

struct RhombicDocedahedra {
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
    
    var allAtoms: [MRAtom] = []
    var allDiamondoids: [Diamondoid] = []
    
    do {
      let latticeWidth: Int = 5
      let width = Float(latticeWidth)
      
      var cells = makeBaseLattice(width: latticeWidth)
      cells = cleave(cells: cells, planes: [
        Plane([-width / 2, width, 0], normal: [1, 1, 0])
      ])
      cells = cleave(cells: cells, planes: [
        Plane([width / 2, 0, width / 2], normal: [1, 0, 1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane([width / 2, 0, width / 2], normal: [1, 0, -1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane([0, width / 2, width / 2], normal: [0, 1, 1])
      ])
      cells = cleave(cells: cells, planes: [
        Plane([0, width / 2, width / 2], normal: [0, 1, -1])
      ])
      
//      let thickness: Float = 0.5
//      cells = cleave(cells: cells, planes: [
//        Plane([-width / 2 - thickness, width - thickness, 0],
//              normal: -[1, 1, 0]),
//        Plane([width / 2 - thickness, 0, width / 2 - thickness],
//              normal: -[1, 0, 1]),
//        Plane([width / 2 - thickness, 0, width / 2 + thickness],
//              normal: -[1, 0, -1]),
//        Plane([0, width / 2 - thickness, width / 2 - thickness],
//              normal: -[0, 1, 1]),
//        Plane([0, width / 2 - thickness, width / 2 + thickness],
//              normal: -[0, 1, -1])
//      ])
      
      var centers = makeCarbonCenters(cells: cells)
      centers = centers.map {
        SIMD3($0.x, $0.y, $0.z - width / 2)
      }
      centers += centers.map {
        SIMD3(-$0.x, -$0.y, $0.z)
      }
      centers += centers.map {
        SIMD3(-$0.x, $0.y, -$0.z)
      }
      
      centers = centerAtOrigin(centers)
      let atoms = generateAtoms(centers)
      allAtoms += atoms
      
      var baseDiamondoid = Diamondoid(atoms: atoms)
      baseDiamondoid.minimize()
      
      let separation: Float = 3.45 * 0.357
      let object_lattice: SIMD3<Int> = [2, 2, 2]
      for x in 0..<object_lattice.x {
        for y in 0..<object_lattice.y {
          for z in 0..<object_lattice.z {
            var copy = baseDiamondoid
            let vectorX: SIMD3<Float> = [1, 0, 1]
            let vectorY: SIMD3<Float> = [0, 2, 0]
            let vectorZ: SIMD3<Float> = [1, 0, -1]
            copy.translate(offset: (
              vectorX * Float(x) + vectorY * Float(y) + vectorZ * Float(z)
            ) * separation)
            allDiamondoids.append(copy)
            
            copy.translate(offset: (
              vectorX + vectorY + vectorZ
            ) * separation / 2)
            allDiamondoids.append(copy)
          }
        }
      }
      
      var projectile = baseDiamondoid
      projectile.translate(offset: [
        (Float(object_lattice.x * 2) - 1) * separation / 2,
        (Float(object_lattice.y * 2) + 2) * separation,
        0
      ])
      
      let speedInMetersPerSecond: Float = 100
      projectile.linearVelocity = [
        0, -speedInMetersPerSecond / 1000, 0
      ]
      allDiamondoids.append(projectile)
    }
    
    print(allDiamondoids[0].atoms.count)
    print(allDiamondoids.reduce(0) { $0 + $1.atoms.count })
    self.provider = ArrayAtomProvider(allDiamondoids.flatMap { $0.atoms })
    
    let simulator = _Old_MM4(
      diamondoids: allDiamondoids, fsPerFrame: 20) // 20, 100
    simulator.simulate(ps: 10) // 10, 80
    provider = simulator.provider
  }
}

#endif
