// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let tooltipLHS: Element = .germanium
  let tooltipRHS: Element = .germanium
  let tooltipState: TooltipState = .discharged
  
  enum TooltipState {
    case charged
    case carbenicRearrangement
    case discharged
  }
  
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
  
  var topology = Topology()
  topology.insert(atoms: lattice.atoms)
  
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
  
  var reactiveSiteAtoms: [Int] = []
  for i in topology.atoms.indices {
    if topology.atoms[i].atomicNumber != 6 {
      reactiveSiteAtoms.append(i)
      
      if reactiveSiteAtoms.count == 1 {
        topology.atoms[i].atomicNumber = tooltipLHS.rawValue
      } else if reactiveSiteAtoms.count == 2 {
        topology.atoms[i].atomicNumber = tooltipRHS.rawValue
      }
    }
  }
  
  // Add the hydrogens.
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
  
  var orbitals = topology.nonbondingOrbitals()
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
  
  // Add the feedstocks if the tooltip is charged.
  orbitals = topology.nonbondingOrbitals()
  insertedAtoms = []
  insertedBonds = []
  for i in reactiveSiteAtoms {
    let orbital = orbitals[i][0]
    let centerAtom = topology.atoms[i]
    var position = centerAtom.position + orbital * 0.2
    if tooltipState == .carbenicRearrangement {
      position.x = 0
    }
    
    let element = Element(rawValue: centerAtom.atomicNumber)!
    var bondLength = element.covalentRadius
    if tooltipState == .carbenicRearrangement {
      bondLength += 0.067
    } else {
      bondLength += 0.061
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
  
  switch tooltipState {
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
  
  let process = XTBProcess(path: "/Users/philipturner/Documents/OpenMM/xtb/cpu0")
  process.writeFile(name: "xtb.inp", process.encodeSettings())
  process.writeFile(name: "coord", try! process.encodeAtoms(topology.atoms))
  process.run(arguments: ["coord", "--input", "xtb.inp", "--opt", "--gfnff"])
  let preconditioned = try! process.decodeAtoms(process.readFile(name: "xtbopt.coord"))
  
  process.writeFile(name: "coord", try! process.encodeAtoms(preconditioned))
  process.run(arguments: ["coord", "--input", "xtb.inp", "--opt"])
  let optimized = try! process.decodeAtoms(process.readFile(name: "xtbopt.coord"))
  
  return optimized
}
