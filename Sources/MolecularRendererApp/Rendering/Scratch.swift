// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

// Make sure to save this with the other code in the GitHub gist.
func adamantaneLattice() -> Lattice<Cubic> {
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
    }
  }
  return lattice
}

func adamantaneDiamondoid() -> Diamondoid {
  let lattice = adamantaneLattice()
  
  let latticeAtoms = lattice.entities.map(MRAtom.init)
  var diamondoid = Diamondoid(atoms: latticeAtoms)
  diamondoid.translate(offset: -diamondoid.createCenterOfMass())
  
  // Remove a sidewall carbon, creating two 5-membered rings.
  do {
    #if true
    // Detect the sidewall carbon farthest in Z.
    var maxZValue: Float = -.greatestFiniteMagnitude
    var maxZIndex: Int = -1
    for (index, atom) in diamondoid.atoms.enumerated() {
      if atom.element == 1 {
        continue
      }
      if atom.origin.z > maxZValue {
        maxZValue = atom.origin.z
        maxZIndex = index
      }
    }
    var removedAtoms = [maxZIndex]
    
    // Detect all hydrogens farther in Z than the removed sidewall.
    for (index, atom) in diamondoid.atoms.enumerated() {
      if atom.element != 1 {
        continue
      }
      if atom.origin.z > maxZValue {
        removedAtoms.append(index)
      }
    }
    
    // Create a new bond between the atoms that are about to become free
    // radicals.
    var neighbors: [Int] = []
    for var bond in diamondoid.bonds {
      guard Int(bond[0]) == maxZIndex ||
              Int(bond[1]) == maxZIndex else {
        continue
      }
      if Int(bond[0]) == maxZIndex {
        bond = SIMD2(bond[1], bond[0])
      }
      
      let atom = diamondoid.atoms[Int(bond[0])]
      if atom.element == 1 {
        continue
      }
      neighbors.append(Int(bond[0]))
    }
    guard neighbors.count == 2 else {
      fatalError("Unrecognized number of neighbors.")
    }
    diamondoid.bonds.append(SIMD2(
      Int32(neighbors[0]),
      Int32(neighbors[1])))
    
    // Remove all bonds containing the removed sidewall.
    diamondoid.bonds.removeAll(where: {
      Int($0[0]) == maxZIndex ||
      Int($0[1]) == maxZIndex
    })
    
    // Remove the atoms one at a time, fixing the bonds with a simple
    // O(n^2) method.
    removedAtoms.sort()
    for atomID in removedAtoms.reversed() {
      for bondID in diamondoid.bonds.indices {
        var bond = diamondoid.bonds[bondID]
        if any(bond .== Int32(atomID)) {
          fatalError("A bond remained that contained a removed atom.")
        }
        let shifted = bond &- 1
        bond.replace(with: shifted, where: bond .>= Int32(atomID))
        diamondoid.bonds[bondID] = bond
      }
      diamondoid.atoms.remove(at: atomID)
    }
    #endif
  }
  
  #if false
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = diamondoid.atoms.map { $0.element }
  paramsDesc.bonds = diamondoid.bonds.map {
    SIMD2<UInt32>(truncatingIfNeeded: $0)
  }
  
  let params = try! MM4Parameters(descriptor: paramsDesc)
  print("atomic numbers (Z):", params.atoms.atomicNumbers)
  print("atomic parameters (r, eps, Hred):", params.atoms.parameters.map {
    ($0.radius.default, $0.epsilon.default, $0.hydrogenReductionFactor)
  })
  print("atom ringTypes:", params.atoms.ringTypes)
  print("rings:", params.rings.indices)
  print()
  print("bond ringTypes:", params.bonds.ringTypes)
  print("bond base parameters (ks, l):", params.bonds.parameters.map { ($0.stretchingStiffness, $0.equilibriumLength) })
  print("bond extended parameters (complex cross-terms):", params.bonds.extendedParameters)
  print()
  print("angle ringTypes:", params.angles.ringTypes)
  print("angle base parameters (kθ, θ, kθθ):",params.angles.parameters.map { ($0.bendingStiffness, $0.equilibriumAngle, $0.bendBendStiffness) })
  print("angle extended parameters (complex cross-terms):", params.angles.extendedParameters)
  print()
  print("torsion ringTypes:", params.torsions.ringTypes)
  print("torsion base parameters (V1, V2, V3, Kts):", params.torsions.parameters.map {
    ($0.V1, $0.Vn, $0.V3, $0.Kts3)
  })
  print("torsion extended parameters (complex cross-terms):", params.torsions.extendedParameters)
  #endif
  
  return diamondoid
}
