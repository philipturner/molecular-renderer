//
//  ConvergentAssemblyArchitecture4.swift
//  HardwareCatalog
//
//  Created by Philip Turner on 12/17/23.
//

import Foundation
import HDL
import MolecularRenderer
import Numerics

// MARK: - Very Complex Code for Solving Implicit Boundary Conditions

extension Quadrant {
  static func beltHeightMap(_ x: Float) -> Float? {
    if x > 15 {
      return nil
    }
    
    let arguments: [(SIMD3<Float>, SIMD2<Float>)] = [
      (SIMD3(-59.8, 5, 0.333), SIMD2(-100, 100)),
      (SIMD3(-27.3, 5, 0.5), SIMD2(-100, -27.3)),
      (SIMD3(-25.3, 5.6, 0.1), SIMD2(-27.3, -23.3)),
      (SIMD3(-23.3, 5, 0.5), SIMD2(-23.3, -21.3)),
      (SIMD3(-21.3, 4, 0.333), SIMD2(-21.3, 100)),
    ]
    
    var output: Float = 1.5
    for (argument, range) in arguments {
      if x < range[0] || x > range[1] {
        continue
      }
      let distance = abs(x - argument[0])
      let elevation = argument[1] - distance * argument[2]
      output = max(output, elevation)
    }
    return output - 23.5
  }
  
  static func createBeltLinks() -> [Diamondoid] {
    let lattice = createBeltLink()
    var masterBeltLink = Diamondoid(lattice: lattice)
    
    do {
      let beltLink = masterBeltLink
      let beltLinkBox = beltLink.createBoundingBox()
      let beltLinkMiddle = (beltLinkBox.0 + beltLinkBox.1) / 2
      
      var atoms = createBuildPlate(
        product: createBeltLinkProduct(), sideHydrogens: false)
      atoms = atoms.map {
        var copy = $0
        copy.origin += beltLinkMiddle
        copy.origin += SIMD3(1.5, 1.7, 0)
        return copy
      }
      masterBeltLink.atoms += atoms
      precondition(atoms.contains(where: { $0.element == 79 }))
      precondition(masterBeltLink.atoms .contains(where: { $0.element == 79 }))
    }
    
    masterBeltLink.atoms.append(
      MRAtom(origin: [5.5, 0.5, 6], element: 7))
    masterBeltLink.atoms.append(
      MRAtom(origin: [Float(5.5) - 3.8, 0.5, 5.8], element: 14))
    
    // originally x=-45, y=2-23.5, z=-20.8
    masterBeltLink.translate(offset: [-65, Float(5.5) - 23.5, -20.8])
    var output = [masterBeltLink]
    var masterCopy = masterBeltLink
    masterCopy.atoms.removeAll(where: {
      $0.element != 1 && $0.element != 6 && $0.element != 79
    })
    precondition(masterCopy.atoms .contains(where: { $0.element == 79 }))
    let masterBoundingBox = createBeltLinkBoundingBox(masterCopy)
    
    // Before: 823 ms
    // After: ??? ms
    let numLinks = 20
    var angles = [Float](repeating: 0, count: numLinks)
    for i in 1..<numLinks {
      let firstSulfur = masterBeltLink.atoms.last(where: { $0.element == 14 })!
      let lastNitrogen = output.last!.atoms.last(where: { $0.element == 7 })!
      var translation = lastNitrogen.origin - firstSulfur.origin
      translation.z = 0
      
      var copy = masterBeltLink
      copy.translate(offset: translation)
      
      var boundingBox = masterBoundingBox
      boundingBox.0 += translation
      boundingBox.1 += translation
      boundingBox.0.z = -18
      boundingBox.1.z = -18
      
      // Fail early if the bounding box is beyond the finish line.
      do {
        var centerX: Float = .zero
        centerX += boundingBox.0.x
        centerX += boundingBox.1.x
        centerX /= 2
        if Self.beltHeightMap(centerX) == nil {
          angles[i] = -100
          break
        }
      }
      
      var testPoints: [SIMD3<Float>] = []
      for i in 0...50 {
        let progress = Float(i) / 50
        var output = boundingBox.0
        output.x += (boundingBox.1.x - boundingBox.0.x) * progress
        testPoints.append(output)
      }
      for xValue in [boundingBox.0.x, boundingBox.1.x] {
        for i in 1...20 {
          let progress = Float(i) / 20
          var output = boundingBox.0
          output.x = xValue
          output.y += (boundingBox.1.y - boundingBox.0.y) * progress
          testPoints.append(output)
        }
      }
      for point in testPoints {
        let atom = MRAtom(origin: point, element: 14)
        copy.atoms.append(atom)
      }
      
      typealias Matrix = (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
      func makeMatrix(angle: Float) -> Matrix {
        let radians = angle * .pi / 180
        if abs(radians) < 1e-3 {
          return([1, 0, 0], [0, 1, 0], [0, 0, 1])
        } else {
          let quaternion = Quaternion<Float>(angle: radians, axis: [0, 0, 1])
          return (
            quaternion.act(on: [1, 0, 0]),
            quaternion.act(on: [0, 1, 0]),
            quaternion.act(on: [0, 0, 1]))
        }
      }
      @inline(__always)
      func rotate(_ point: SIMD3<Float>, _ matrix: Matrix) -> SIMD3<Float> {
        matrix.0 * point.x +
        matrix.1 * point.y +
        matrix.2 * point.z
      }
      
      // Use this pivot to flip the sign of the favored rotation direction.
      let nitrogenX = lastNitrogen.origin.x
      var lastSecureAngle = angles[i]
      var secureAngleExists = false
      for _ in 0..<50 {
        let rotationMatrix = makeMatrix(angle: angles[i])
        var anyRepelled: Bool = false
        var anyAttracted: Bool = false
        var leverageRepel: Float = 0
        var leverageAttract: Float = 0
        for point in testPoints {
          let leverage = point.x - nitrogenX
          
          var delta = point - lastNitrogen.origin
          delta = rotate(delta, rotationMatrix)
          let transformed = lastNitrogen.origin + delta
          let currentHeight = transformed.y
          let surfaceHeight =
          Self.beltHeightMap(transformed.x) ?? Self.beltHeightMap(14)!
          if surfaceHeight > currentHeight {
            anyRepelled = true
            leverageRepel += (surfaceHeight - currentHeight) * leverage
          } else {
            anyAttracted = true
            leverageAttract += (currentHeight - surfaceHeight) * leverage
          }
        }
        
        guard anyRepelled || anyAttracted else {
          fatalError("No points repelled or attracted.")
        }
        var angleChange: Float
        if anyRepelled {
          angleChange = (leverageRepel > 0) ? 1 : -1
        } else {
          lastSecureAngle = angles[i]
          secureAngleExists = true
          angleChange = (leverageAttract < 0) ? 1 : -1
        }
        
        var newAngle = angles[i] + angleChange
        newAngle = max(-80, min(newAngle, 80))
        angles[i] = newAngle
      }
      if secureAngleExists {
        angles[i] = lastSecureAngle
      }
      let rotationMatrix = makeMatrix(angle: angles[i])
      
      // Move slightly outward from the window.
      var translationZ: Float = -0.1 * Float(i)
      if lastNitrogen.origin.z + translationZ < -18 {
        translationZ = -18 - lastNitrogen.origin.z
      } else {
      }
      copy.transform {
        var delta = $0.origin - lastNitrogen.origin
        delta = rotate(delta, rotationMatrix)
        $0.origin = lastNitrogen.origin + delta
        $0.origin.z += translationZ
      }
      output.append(copy)
    }
    
    for i in output.indices {
      output[i].atoms.removeAll(where: {
        $0.element != 1 && $0.element != 6 &&
        $0.element != 79 && $0.element != 16
      })
    }
    return output
  }
}

// MARK: - NOR Gate

extension ServoArm {
  static func createNORGate() -> [Diamondoid] {
    let boardLattice = createNORGateBoard()
    var boardDiamondoid = Diamondoid(lattice: boardLattice)
    boardDiamondoid.fixHydrogens(tolerance: 0.08)
    
    let h = SIMD3<Float>(1, 0, 0) * 0.252
    let k = SIMD3<Float>(-0.5, 0.866925, 0) * 0.252
    let l = SIMD3<Float>(0, 0, 1) * 0.412
    
    let rod1Lattice = createNORGateRod()
    var rod1Diamondoid = Diamondoid(lattice: rod1Lattice)
    var rod2Diamondoid = rod1Diamondoid
    var rod3Diamondoid = rod1Diamondoid
    
    rod1Diamondoid.translate(offset: -rod1Diamondoid.createCenterOfMass())
    rod1Diamondoid.translate(offset: 4.25 * l)
    rod1Diamondoid.translate(offset: 6 * k)
    rod1Diamondoid.translate(offset: 4 * (k + 2 * h))
    rod1Diamondoid.translate(offset: 4 * (k + 2 * h))
    
    rod2Diamondoid.translate(offset: -rod2Diamondoid.createCenterOfMass())
    rod2Diamondoid.translate(offset: 4.25 * l)
    rod2Diamondoid.translate(offset: 6 * k)
    rod2Diamondoid.translate(offset: 4 * (k + 2 * h))
    rod2Diamondoid.translate(offset: 5.1 * (h + 2 * k))
    rod2Diamondoid.translate(offset: 4 * (k + 2 * h))
    
    rod3Diamondoid.translate(offset: -rod3Diamondoid.createCenterOfMass())
    rod3Diamondoid.rotate(angle: Quaternion<Float>(
      angle: 4 * .pi / 3, axis: [0, 0, 1]))
    rod3Diamondoid.translate(offset: 4.25 * l)
    rod3Diamondoid.translate(offset: 12 * h)
    rod3Diamondoid.translate(offset: 1 * (h + 2 * k))
    
    return [
      boardDiamondoid, rod1Diamondoid, rod2Diamondoid, rod3Diamondoid
    ]
  }
}

func createNORGateBoard() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 25 * h + 17 * h2k + 6 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 0.25 * l }
        Plane { -l }
      }
      Concave {
        Origin { 12 * h + 8 * h2k + 2.2 * l }
        
        // Cut a plane separating the back of the board from some open void.
        Plane { l }
        
        // Right hand side part that prevents the input rods from escaping
        // into the void.
        Concave {
          Convex {
            Origin { 6 * h }
            Concave {
              Plane { -h }
              Convex {
                Origin { -2 * h + 4 * h2k }
                Plane { k - h }
                Plane { (-k - h) - h }
              }
              Convex {
                Origin { -2 * h + 9 * h2k }
                Plane { (-k - h) - h }
              }
            }
            Origin { 2 * h }
            Plane { h }
            Plane { -k }
          }
        }
        
        Convex {
          Origin { 10 * k }
          Plane { -k }
          Origin { 2 * k }
          Plane { k }
          Origin { 3 * h }
          Plane { h }
        }
        
        Convex {
          Concave {
            Origin { -2.5 * h }
            Plane { h }
            Origin { 5 * h }
            Plane { -h }
          }
          Convex {
            Convex {
              Origin { 8 * h }
              Plane { h }
            }
            Concave {
              Origin { -2.5 * k }
              Plane { k }
              Origin { 5 * k }
              Plane { -k }
            }
            Concave {
              Origin { 7.5 * k }
              Origin { -2.5 * k }
              Plane { k }
              Origin { 5 * k }
              Plane { -k }
            }
          }
          
          Concave {
            Convex {
              Origin { -4.5 * h }
              Plane { -h }
              Origin { 9 * h }
              Plane { h }
            }
            Convex {
              Origin { -4.5 * k }
              Plane { -k }
              Origin { 9.5 * k }
              Plane { k }
            }
            
            // Fix up some artifacts on the joint between two lines.
            Convex {
              Convex {
                Origin { -3.5 * (k - h) }
                Plane { -(k - h) }
                Origin { 7 * (k - h) }
                Plane { k - h }
              }
              Convex {
                Origin { -3.5 * (k + h) }
                Plane { -(k + h) }
                Origin { 7 * (k + h) }
                Plane { k + h }
              }
            }
          }
        }
        Replace { .empty }
      }
    }
    
    Volume {
      Origin { 5.2 * l }
      Plane { l }
      Replace { .empty }
    }
  }
}

func createNORGateRod() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 15 * h + 14 * h2k + 3 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 5 * k }
        Plane { -k }
      }
      Convex {
        Origin { 6.5 * k }
        Plane { k }
      }
      Convex {
        Origin { 2.2 * l }
        Plane { l }
      }
      Convex {
        Origin { 6 * (h + k) }
        Plane { -(h + k) }
      }
      Replace { .empty }
    }
  }
}

// MARK: - Tripods

extension RobotArm {
  static func createTripods(index: Int) -> [[MRAtom]] {
    let methylene = createMethyleneTripod()
    let hAbst = createHAbstTripod()
    let hDon = createHDonTripod()
    switch index {
    case 0:
      return createTripodPair(hAbst, methylene)
    case 1:
      return createTripodPair(methylene, hDon)
    case 2:
      return createTripodPair(hAbst, hDon)
    default:
      fatalError("Unrecognized index.")
    }
  }
  
  static func createTripodPair(
    _ tripod1: [MRAtom], _ tripod2: [MRAtom]
  ) -> [[MRAtom]] {
    var tripods = [tripod1, tripod2]
    
    // Create a hexagonal prism out of gold.
    let goldLattice = Lattice<Cubic> { h, k, l in
      Bounds { 8 * h + 8 * k + 8 * l }
      Material { .elemental(.gold) }
      
      Volume {
        Origin { 4 * h + 4 * k + 4 * l }
        for sign in [Float(1), -1] {
          Convex {
            Origin { sign * 1.0 * (h + k + l) }
            Plane { sign * (h + k + l) }
          }
        }
        var directions: [SIMD3<Float>] = []
        directions.append(h + k - 2 * l)
        directions.append(h + l - 2 * k)
        directions.append(k + l - 2 * h)
        directions += directions.map(-)
        for direction in directions {
          Convex {
            Origin { 0.75 * direction }
            Plane { direction }
          }
        }
        
        Replace { .empty }
      }
    }
    var goldAtoms = goldLattice.entities.map(MRAtom.init)
    var basisVector1: SIMD3<Float> = [1, 1, 1]
    var basisVector2: SIMD3<Float> = [1, 0, -1]
    var basisVector3 = cross_platform_cross(basisVector1, basisVector2)
    basisVector1 = cross_platform_normalize(basisVector1)
    basisVector2 = cross_platform_normalize(basisVector2)
    basisVector3 = cross_platform_normalize(basisVector3)
    for i in goldAtoms.indices {
      var origin = goldAtoms[i].origin
      let dot1 = (origin * basisVector1).sum()
      let dot2 = (origin * basisVector2).sum()
      let dot3 = (origin * basisVector3).sum()
      origin = SIMD3(dot2, dot1, dot3)
      goldAtoms[i].origin = origin
    }
    
    var goldCenterOfMass: SIMD3<Float> = .zero
    var goldMaxY: Float = -.greatestFiniteMagnitude
    for atom in goldAtoms {
      goldMaxY = max(goldMaxY, atom.origin.y)
      goldCenterOfMass += atom.origin
    }
    goldCenterOfMass /= Float(goldAtoms.count)
    for i in goldAtoms.indices {
      var translation = -goldCenterOfMass
      translation.y = -0.2 - goldMaxY
      goldAtoms[i].origin += translation
    }
    
    for i in tripods.indices {
      var tripod = tripods[i]
      var minY: Float = .greatestFiniteMagnitude
      var centerOfMass: SIMD3<Float> = .zero
      for atom in tripod where atom.element == 16 {
        minY = min(minY, atom.origin.y)
        centerOfMass += atom.origin
      }
      centerOfMass /= 3
      
      var translation = -centerOfMass
      translation.y = 0.1 - minY
      for i in tripod.indices {
        tripod[i].origin += translation
      }
      tripod += goldAtoms
      
      let angle = Float(-150) * .pi / 180
      let rotation = Quaternion<Float>(angle: angle, axis: [0, 0, 1])
      for i in tripod.indices {
        var origin = tripod[i].origin
        origin = rotation.act(on: origin)
        tripod[i].origin = origin
        tripod[i].origin.x -= 1.5 + 0.5 * 1 - 0.85 * 0.25
      }
      
      if i == 0 {
        for i in tripod.indices {
          tripod[i].origin.x = -tripod[i].origin.x
        }
      }
      tripods[i] = tripod
    }
    
    return tripods
  }
}

// MARK: - Build Plates

// Hexagonal prism of gold.
func createBuildPlateGold() -> [MRAtom] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 8 * h + 8 * k + 8 * l }
    Material { .elemental(.gold) }
    
    Volume {
      Origin { 4 * h + 4 * k + 4 * l }
      for sign in [Float(1), -1] {
        Convex {
          Origin { sign * 0.25 * (h + k + l) }
          Plane { sign * (h + k + l) }
        }
      }
      var directions: [SIMD3<Float>] = []
      directions.append(h + k - 2 * l)
      directions.append(h + l - 2 * k)
      directions.append(k + l - 2 * h)
      directions += directions.map(-)
      for direction in directions {
        Convex {
          Origin { 1 * direction }
          Plane { direction }
        }
      }
      
      Replace { .empty }
    }
  }
  var goldAtoms = lattice.entities.map(MRAtom.init)
  var basisVector1: SIMD3<Float> = [1, 1, 1]
  var basisVector2: SIMD3<Float> = [1, 0, -1]
  var basisVector3 = cross_platform_cross(basisVector1, basisVector2)
  basisVector1 = cross_platform_normalize(basisVector1)
  basisVector2 = cross_platform_normalize(basisVector2)
  basisVector3 = cross_platform_normalize(basisVector3)
  for i in goldAtoms.indices {
    var origin = goldAtoms[i].origin
    let dot1 = (origin * basisVector1).sum()
    let dot2 = (origin * basisVector2).sum()
    let dot3 = (origin * basisVector3).sum()
    origin = SIMD3(dot2, dot1, dot3)
    goldAtoms[i].origin = origin
  }
  
  var goldCenterOfMass: SIMD3<Float> = .zero
  var goldMaxY: Float = -.greatestFiniteMagnitude
  for atom in goldAtoms {
    goldMaxY = max(goldMaxY, atom.origin.y)
    goldCenterOfMass += atom.origin
  }
  goldCenterOfMass /= Float(goldAtoms.count)
  for i in goldAtoms.indices {
    var translation = -goldCenterOfMass
    translation.y = -0.2 - goldMaxY
    goldAtoms[i].origin += translation
  }
  return goldAtoms
}

// Rectangular segment of graphene, with sulfurs to connect to gold.
func createBuildPlateCarbon(sideHydrogens: Bool) -> [MRAtom] {
  let carbonLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 4 * h + 3 * h2k + 1 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      // Move the player position from the origin to (0, 0, 0.25).
      Origin { 0.25 * l }
      
      // Create a plane pointing from the origin to positive `l`.
      Plane { l }
      
      // Remove all atoms on the positive side of the plane.
      Replace { .empty }
    }
  }
  
  var grapheneHexagonScale: Float
  do {
    // Convert graphene lattice constant from Å to nm.
    let grapheneConstant: Float = 2.45 / 10
    
    // Retrieve lonsdaleite lattice constant in nm.
    let lonsdaleiteConstant = Constant(.hexagon) { .elemental(.carbon) }
    
    // Each hexagon's current side length is the value of
    // `lonsdaleiteConstant`. Dividing by this constant, changes the hexagon
    // so its sides are all 1 nm.
    grapheneHexagonScale = 1 / lonsdaleiteConstant
    
    // Multiply by the graphene constant. This second transformation stretches
    // the hexagon, so its sides are all 0.245 nm.
    grapheneHexagonScale *= grapheneConstant
  }

  var carbons: [Entity] = carbonLattice.entities
  var centerOfMass: SIMD3<Float> = .zero
  for atomID in carbons.indices {
    // Flatten the sp3 sheet into an sp2 sheet.
    carbons[atomID].position.z = 0
    
    // Resize the hexagon side length, so it matches graphene.
    carbons[atomID].position.x *= grapheneHexagonScale
    carbons[atomID].position.y *= grapheneHexagonScale
    
    var position = carbons[atomID].position
    position = SIMD3(position.x, position.z, position.y)
    centerOfMass += position
    carbons[atomID].position = position
  }
  centerOfMass /= Float(carbons.count)
  for i in carbons.indices {
    carbons[i].position -= centerOfMass
    carbons[i].position.y = 0.2
  }
  
  var hydrogens: [MRAtom] = []
  var sulfurs: [MRAtom] = []
  for sideLeft in [false, true] {
    for i in 0..<6 {
      var position = SIMD3<Float>(
        sideLeft ? -0.62 : 0.62,
        0.2,
        Float(i) * 0.22 - 0.55)
      position.z += (i % 2 == 0) ? -0.01 : 0.01
      if i == 0 || i == 5 {
        let sign = (i == 0) ? Float(-1) : Float(1)
        position.z += sign * 0.050
        position.y -= 0.100
        sulfurs.append(MRAtom(origin: position, element: 16))
      } else if sideHydrogens {
        hydrogens.append(MRAtom(origin: position, element: 1))
      }
    }
  }
  for sideTop in [false, true] {
    for i in 0..<4 {
      let position = SIMD3<Float>(
        (Float(i) - 1.5) * 0.24,
        0.2,
        sideTop ? -0.7 : 0.7)
      hydrogens.append(MRAtom(origin: position, element: 1))
    }
  }
  
  return carbons.map(MRAtom.init) + hydrogens + sulfurs
}

func createBuildPlate(product: [MRAtom], sideHydrogens: Bool) -> [MRAtom] {
  var output: [MRAtom] = []
  output += createBuildPlateGold()
  output += createBuildPlateCarbon(sideHydrogens: sideHydrogens)
  output += product
  return output
}

func createBeltLinkBoundingBox(_ beltLink: Diamondoid) -> (
  SIMD3<Float>, SIMD3<Float>
) {
  var copy = beltLink
  let goldAtom = copy.atoms.first(where: { $0.element == 79 })!
  copy.atoms.removeAll(where: { $0.origin.y > goldAtom.origin.y - 1e-3 })
  precondition(!copy.atoms.contains(where: { $0.element == 79 }))
  return copy.createBoundingBox()
}

func createBeltLinkProduct() -> [MRAtom] {
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
      Bounds { 4 * h + 3 * h2k + 2 * l }
      Material { .elemental(.carbon) }
  }
  var diamondoid = Diamondoid(lattice: lattice)
  diamondoid.setCenterOfMass(.zero)
  let boundingBox = diamondoid.createBoundingBox()
  var output = diamondoid.atoms
  output.removeAll(where: { atom -> Bool in
    let isHydrogen = atom.element == 1
    let isLow = atom.origin.x < (boundingBox.0.x + 0.2)
    let isHigh = atom.origin.x > (boundingBox.1.x - 0.2)
    let isBack = atom.origin.z < (boundingBox.0.z + 0.2)
    return isHydrogen && (isLow || isHigh || isBack)
  })
  output = output.map { atom -> MRAtom in
    var copy = atom
    copy.origin = SIMD3(copy.origin.x, copy.origin.z, copy.origin.y)
    copy.origin.y += 0.75
    return copy
  }
  
  return output
}

// MARK: - Welding Stand

func createWeldingStand() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 25 * h + 5 * h2k + 18 * l }
    Material { .elemental(.carbon) }
    
    func createEncounterVolume() {
      Convex {
        Plane { -h }
        Plane { -h2k }
        Plane { -l }
        Origin  { 11.5 * h + 5 * h2k + 15.00 * l }
        Plane { h }
        Plane { h2k }
        Plane { l }
      }
    }
    
    Volume {
      Origin { 8 * h + 0 * l }
      Concave {
        Convex {
          Origin { 4.5 * h + 0.25 * l }
          createEncounterVolume()
        }
      }
      for direction in [l, -l] {
        Convex {
          Origin { -0.125 * l }
          Origin { 6 * l + 8 * direction }
          Plane { direction }
        }
      }
      Replace { .empty }
    }
  }
}

func createWeldingStandScene() -> [MRAtom] {
  var output: [MRAtom] = []
  
  let boardLattice = createNORGateBoard()
  var boardDiamondoid = Diamondoid(lattice: boardLattice)
  boardDiamondoid.fixHydrogens(tolerance: 0.08)
  boardDiamondoid.setCenterOfMass(.zero)
  boardDiamondoid.atoms.removeAll(where: { atom -> Bool in
    let zone1 = atom.origin.x < 0.250
    let zone2 = atom.origin.y < -2.00
    return zone1 || zone2
  })
  boardDiamondoid.transform {
    $0.origin = SIMD3($0.origin.x, $0.origin.z, -$0.origin.y)
    $0.origin += SIMD3(5, 5, -10)
  }
  var product: [MRAtom] = createBeltLinkProduct()
  for i in product.indices {
    product[i].origin += SIMD3(4.730, 3.930, -13.050)
  }
  boardDiamondoid.atoms += product
  
  let stand = createWeldingStand()
  var standDiamondoid = Diamondoid(lattice: stand)
  standDiamondoid.translate(offset: [2.2, 1.1, -13.7])
  boardDiamondoid.atoms += standDiamondoid.atoms
  
  var gold = createBuildPlateGold()
  for i in gold.indices {
    gold[i].origin += SIMD3(6.8, 3.95, -12.3)
  }
  boardDiamondoid.atoms += gold
  for i in gold.indices {
    gold[i].origin += SIMD3(0, 0, 3)
  }
  boardDiamondoid.atoms += gold
  
  boardDiamondoid.transform {
    $0.origin += SIMD3(6.5, 0.55, -6.55)
  }
  output += boardDiamondoid.atoms
  
  return output
}

func createStage1BuildPlate(index: Int) -> [MRAtom] {
  var product: [MRAtom] = []
  if index > 0 {
    product = createBeltLinkProduct()
    if index <= 3 {
      product.removeAll(where: { $0.y < 0.8 })
    }
    if index % 3 == 1 {
      product.removeAll(where: { $0.y > 0.8 && $0.z < 0.2 })
    }
    if index % 3 == 2 {
      product.removeAll(where: { $0.y > 0.8 && $0.z < -0.2 })
    }
    if index <= 3 {
      var distance = Constant(.hexagon) { .elemental(.carbon) }
      distance *= Float(3).squareRoot()
      for i in product.indices {
        product[i].origin.y -= distance
      }
    }
  }
  
  return createBuildPlate(
    product: product, sideHydrogens: index < 3)
}
