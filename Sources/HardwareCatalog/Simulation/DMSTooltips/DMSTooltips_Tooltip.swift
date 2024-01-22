//
//  DMSTooltips_Tooltip.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 1/22/24.
//

import Foundation
import HDL
import Numerics

enum TooltipState {
  case charged
  case carbenicRearrangement
  case discharged
}

struct TooltipDescriptor {
  // Required.
  var reactiveSiteLeft: Element?
  
  // Required.
  var reactiveSiteRight: Element?
  
  // Required.
  var state: TooltipState?
  
  init() { }
}

struct Tooltip {
  var topology = Topology()
  var reactiveSiteAtoms: [Int] = []
  var constrainedAtoms: [Int] = []
  
  init(descriptor: TooltipDescriptor) {
    compilationPass0()
    compilationPass1()
    
    guard let reactiveSiteLeft = descriptor.reactiveSiteLeft,
          let reactiveSiteRight = descriptor.reactiveSiteRight else {
      fatalError("Reactive sites not specified.")
    }
    compilationPass2(
      reactiveSiteLeft: reactiveSiteLeft, reactiveSiteRight: reactiveSiteRight)
    compilationPass3()
    
    guard let state = descriptor.state else {
      fatalError("Tooltip state not specified.")
    }
    let orbitals = topology.nonbondingOrbitals()
    if reactiveSiteLeft == .lead, reactiveSiteRight == .lead {
      injectLeadStructure()
    }
    compilationPass4(orbitals: orbitals, state: state)
  }
  
  // Create the lattice.
  mutating func compilationPass0() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 4 * h + 4 * k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 2 * h + 2 * k + 2 * l }
        Origin { 0.25 * (h + k - l) }
        
        // Remove the front plane.
        Convex {
          Origin { 0.25 * (h + k + l) }
          Plane { h + k + l }
        }
        
        func triangleCut(sign: Float) {
          Convex {
            Origin { 0.25 * sign * (h - k - l) }
            Plane { sign * (h - k / 2 - l / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (k - l - h) }
            Plane { sign * (k - l / 2 - h / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (l - h - k) }
            Plane { sign * (l - h / 2 - k / 2) }
          }
        }
        
        // Remove three sides forming a triangle.
        triangleCut(sign: +1)
        
        // Remove their opposites.
        triangleCut(sign: -1)
        
        // Remove the back plane.
        Convex {
          Origin { -0.25 * (h + k + l) }
          Plane { -(h + k + l) }
        }
        
        Replace { .empty }
        
        Volume {
          Origin { 0.20 * (h + k + l) }
          Plane { h + k + l }
          Replace { .atom(.silicon) }
        }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  // Place all of the center atoms.
  mutating func compilationPass1() {
    // Center the adamantane at (0, 0, 0).
    var accumulator: SIMD3<Float> = .zero
    for atom in topology.atoms {
      accumulator += atom.position
    }
    accumulator /= Float(topology.atoms.count)
    
    // Rotate the adamantane and make the three bridge carbons flush.
    let rotation1 = Quaternion<Float>(angle: .pi / 4, axis: [0, 1, 0])
    let rotation2 = Quaternion<Float>(angle: 35.26 * .pi / 180, axis: [0, 0, 1])
    var maxX: Float = -.greatestFiniteMagnitude
    for i in topology.atoms.indices {
      var position = topology.atoms[i].position
      position -= accumulator
      position = rotation1.act(on: position)
      position = rotation2.act(on: position)
      topology.atoms[i].position = position
      maxX = max(maxX, position.x)
    }
    for i in topology.atoms.indices {
      topology.atoms[i].position.x -= maxX
      topology.atoms[i].position.x -= Element.carbon.covalentRadius
    }
    
    // Create the second half.
    topology.insert(atoms: topology.atoms.map {
      var copy = $0
      copy.position.x = -copy.position.x
      return copy
    })
  }
  
  // Recognize the reactive site atoms.
  mutating func compilationPass2(
    reactiveSiteLeft: Element,
    reactiveSiteRight: Element
  ) {
    for i in topology.atoms.indices {
      if topology.atoms[i].atomicNumber != 6 {
        reactiveSiteAtoms.append(i)
        
        if reactiveSiteAtoms.count == 1 {
          topology.atoms[i].atomicNumber = reactiveSiteLeft.rawValue
        } else if reactiveSiteAtoms.count == 2 {
          topology.atoms[i].atomicNumber = reactiveSiteRight.rawValue
        }
      }
    }
  }
  
  // Form the bond topology.
  mutating func compilationPass3() {
    let matchRadius = 2 * Element.carbon.covalentRadius
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(1.1 * matchRadius))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        if reactiveSiteAtoms == [i, Int(j)] {
          continue
        }
        insertedBonds.append(SIMD2(UInt32(i), UInt32(j)))
      }
    }
    topology.insert(bonds: insertedBonds)
    
    let orbitals = topology.nonbondingOrbitals()
    let chBondLength = Element.carbon.covalentRadius +
    Element.hydrogen.covalentRadius
    
    var insertedAtoms: [Entity] = []
    insertedBonds = []
    for i in topology.atoms.indices {
      if reactiveSiteAtoms.contains(i) {
        continue
      }
      let carbon = topology.atoms[i]
      for orbital in orbitals[i] {
        let position = carbon.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Adjust the initial structure so that xTB accepts it.
  mutating func injectLeadStructure() {
    topology.atoms = [
      Entity(position: SIMD3(-0.0772, -0.1298, -0.0000), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.2868, -0.0701,  0.1265), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.2868, -0.0701, -0.1265), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.3584, -0.0212,  0.0000), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.3790,  0.1300,  0.0000), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.1339, -0.0621, -0.1253), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.0731,  0.0749, -0.1435), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.1339, -0.0621,  0.1253), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.0731,  0.0749,  0.1435), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.1755,  0.2479, -0.0000), type: .atom(.lead)),
      Entity(position: SIMD3( 0.0772, -0.1298, -0.0000), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.2868, -0.0701,  0.1265), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.2868, -0.0701, -0.1265), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.3584, -0.0212,  0.0000), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.3790,  0.1300,  0.0000), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.1339, -0.0621, -0.1253), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.0731,  0.0749, -0.1435), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.1339, -0.0621,  0.1253), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.0731,  0.0749,  0.1435), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.1755,  0.2479, -0.0000), type: .atom(.lead)),
      Entity(position: SIMD3(-0.1128, -0.2335, -0.0000), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.3250, -0.0147,  0.2125), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.3129, -0.1753,  0.1414), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.3250, -0.0147, -0.2125), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.3129, -0.1753, -0.1414), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.4578, -0.0686,  0.0000), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.4396,  0.1563,  0.0870), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.4396,  0.1563, -0.0870), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.1009, -0.1228, -0.2114), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.1158,  0.1281, -0.2292), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.1009, -0.1228,  0.2114), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.1158,  0.1281,  0.2292), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.1128, -0.2335, -0.0000), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.3129, -0.1753,  0.1414), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.3250, -0.0147,  0.2125), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.3129, -0.1753, -0.1414), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.3250, -0.0147, -0.2125), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.4578, -0.0686,  0.0000), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.4396,  0.1563, -0.0870), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.4396,  0.1563,  0.0870), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.1009, -0.1228, -0.2114), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.1158,  0.1281, -0.2292), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.1009, -0.1228,  0.2114), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.1158,  0.1281,  0.2292), type: .atom(.hydrogen)),
    ]
    
    for i in topology.atoms.indices {
      if topology.atoms[i].atomicNumber == 6 {
        constrainedAtoms.append(i)
      }
    }
  }
  
  // Add the feedstocks if the tooltip is charged.
  mutating func compilationPass4(
    orbitals: [Topology.OrbitalStorage], state: TooltipState
  ) {
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in reactiveSiteAtoms {
      let orbital = orbitals[i][0]
      let centerAtom = topology.atoms[i]
      var position = centerAtom.position + orbital * 0.2
      if state == .carbenicRearrangement {
        position.x = 0
      } else if centerAtom.atomicNumber == 82 {
        position.x /= position.x.magnitude
        position.x *= 0.061
      }
      
      let element = Element(rawValue: centerAtom.atomicNumber)!
      var bondLength = element.covalentRadius
      if state == .carbenicRearrangement {
        bondLength += 0.067
      } else {
        bondLength += 0.061
      }
      if centerAtom.atomicNumber == 82 {
        bondLength = 0.2595
      }
      
      let deltaX = min(bondLength, position.x - centerAtom.position.x)
      let deltaY = (bondLength * bondLength - deltaX * deltaX).squareRoot()
      position.y = centerAtom.position.y + deltaY
      
      let carbon = Entity(position: position, type: .atom(.carbon))
      let carbonID = topology.atoms.count + insertedAtoms.count
      let bond = SIMD2(UInt32(i), UInt32(carbonID))
      insertedAtoms.append(carbon)
      insertedBonds.append(bond)
    }
    
    let averageY = (insertedAtoms[0].position.y + insertedAtoms[1].position.y) / 2
    insertedAtoms[0].position.y = averageY
    insertedAtoms[1].position.y = averageY
    
    switch state {
    case .charged:
      insertedBonds.append(SIMD2(UInt32(topology.atoms.count),
                                 UInt32(topology.atoms.count + 1)))
    case .carbenicRearrangement:
      insertedBonds.removeLast()
      insertedAtoms.removeLast()
      
      var position = insertedAtoms[0].position
      position.y += 0.133
      let carbon = Entity(position: position, type: .atom(.carbon))
      insertedAtoms.append(carbon)
      insertedBonds.append(SIMD2(UInt32(topology.atoms.count),
                                 UInt32(topology.atoms.count + 1)))
      
      let carbenicBond = SIMD2(UInt32(reactiveSiteAtoms[1]),
                               UInt32(topology.atoms.count))
      insertedBonds.append(carbenicBond)
    case .discharged:
      insertedAtoms.removeAll()
      insertedBonds.removeAll()
      
      let reactiveSiteBond = SIMD2(UInt32(reactiveSiteAtoms[0]),
                                   UInt32(reactiveSiteAtoms[1]))
      insertedBonds.append(reactiveSiteBond)
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
}
