//
//  DiAdamantasilane.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/15/24.
//

import Foundation
import HDL
import MM4
import Numerics

// NOTE: Cached build products for xTB-generated structures are located at:
// https://gist.github.com/philipturner/ffa077dce47ed738c3ead04cc8c9f1a0
//
// First ran through GFN-FF to accelerate convergence. Then ran through xTB to
// maximize accuracy.
//
// Artifacts:
// - xtbOptimizedStructure\(carbonCount)
// - xtbOptimizedCharges\(carbonCount)

func createTopology(carbonCount: Int) -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 4 * h + 4 * k + 4 * l }
    Material { .elemental(.silicon) }
    
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
      
      if carbonCount >= 2 {
        Volume {
          Origin { 0.3 * k }
          Plane { k }
          Replace { .atom(.carbon) }
        }
      }
      
      if carbonCount >= 4 {
        Volume {
          Origin { 0.3 * h }
          Plane { h }
          Replace { .atom(.carbon) }
        }
      }
      
      if carbonCount >= 6 {
        Volume {
          Origin { 0.2 * (-h - k + l) }
          Plane { (-h - k + l)  }
          Replace { .atom(.carbon) }
        }
      }
    }
  }
  
  let atoms = lattice.atoms
  let lastPosition1 = atoms[atoms.count - 2].position
  let lastPosition2 = atoms[atoms.count - 1].position
  
  var axis = lastPosition2 - lastPosition1
  axis /= (axis * axis).sum().squareRoot()
  let midPoint = (lastPosition1 + lastPosition2) / 2
  let rotation = Quaternion<Float>(angle: .pi, axis: axis)
  
  var averagePosition: SIMD3<Float> = .zero
  for atom in atoms {
    averagePosition += atom.position
  }
  averagePosition /= Float(atoms.count)
  
  var stretchingDirection = averagePosition - midPoint
  stretchingDirection /= (
    stretchingDirection * stretchingDirection).sum().squareRoot()
  
  var axisX = -stretchingDirection
  let axisY = axis
  let axisZ = cross_platform_cross(axisX, axisY)
  axisX = cross_platform_cross(axisY, axisZ)
  
  // Generate the actual atoms.
  
  var actualAtoms = Array(atoms[(atoms.count - 2)...])
  
  // Merge the two mirror-image adamantanes and rotate them, so the pair of
  // quaternary silicons points vertically.
  for halfID in 0..<2 {
    for var atom in atoms[..<(atoms.count - 2)] {
      var delta = atom.position - midPoint
      if halfID == 1 {
        delta = rotation.act(on: delta)
        
        let dotPart = (delta * axis).sum()
        delta -= 2 * dotPart * axis
      }
      
      atom.position = midPoint + delta
      actualAtoms.append(atom)
    }
  }
  
  for i in actualAtoms.indices {
    var atom = actualAtoms[i]
    atom.position -= midPoint
    atom.position = SIMD3(
      (atom.position * axisX).sum(),
      (atom.position * axisY).sum(),
      (atom.position * axisZ).sum())
    actualAtoms[i] = atom
  }
  
  // Add the hydrogens.
  
  var topology = Topology()
  topology.insert(atoms: actualAtoms)
  
  let matches = topology.match(topology.atoms)
  
  var insertedBonds: [SIMD2<UInt32>] = []
  for i in topology.atoms.indices {
    for j in matches[i] where i < j {
      insertedBonds.append(SIMD2(UInt32(i), UInt32(j)))
    }
  }
  topology.insert(bonds: insertedBonds)
  
  let orbitals = topology.nonbondingOrbitals()
  var insertedAtoms: [Entity] = []
  insertedBonds = []
  for i in topology.atoms.indices {
    let center = topology.atoms[i]
    guard case .atom(let element) = center.type else {
      fatalError()
    }
    let bondLength = element.covalentRadius + Element.hydrogen.covalentRadius
    for orbital in orbitals[i] {
      let position = center.position + bondLength * orbital
      let hydrogen = Entity(position: position, type: .atom(.hydrogen))
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
      insertedAtoms.append(hydrogen)
      insertedBonds.append(bond)
    }
  }
  topology.insert(atoms: insertedAtoms)
  topology.insert(bonds: insertedBonds)
  
  return topology
}
