// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
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
  
  let ccBondLength = 2 * Element.carbon.covalentRadius
  let matches = topology.match(
    topology.atoms, algorithm: .absoluteRadius(1.5 * ccBondLength))
  
  var insertedBonds: [SIMD2<UInt32>] = []
  for i in topology.atoms.indices {
    for j in matches[i] where i < j {
      insertedBonds.append(SIMD2(UInt32(i), UInt32(j)))
    }
  }
  topology.insert(bonds: insertedBonds)
  
  let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  var removedAtoms: [UInt32] = []
  for i in topology.atoms.indices {
    if atomsToAtomsMap[i].count <= 1 {
      removedAtoms.append(UInt32(i))
    }
  }
  topology.remove(atoms: removedAtoms)
  
  let orbitals = topology.nonbondingOrbitals()
  let chBondLength = Float(1.1120) / 10
  let hSiBondLength = Float(1.483) / 10
  
  var insertedAtoms: [Entity] = []
  insertedBonds = []
  for i in topology.atoms.indices {
    let carbon = topology.atoms[i]
    for orbital in orbitals[i] {
      let bondLength = (carbon.atomicNumber == 6) ? chBondLength : hSiBondLength
      let position = carbon.position + bondLength * orbital
      let hydrogen = Entity(position: position, type: .atom(.hydrogen))
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
      insertedAtoms.append(hydrogen)
      insertedBonds.append(bond)
    }
  }
  topology.insert(atoms: insertedAtoms)
  topology.insert(bonds: insertedBonds)
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  print()
  print("atoms:")
  for i in parameters.atoms.indices {
    let atomicNumber = parameters.atoms.atomicNumbers[i]
    let params = parameters.atoms.parameters[i]
    print("-", atomicNumber, params.charge, params.hydrogenReductionFactor, params.epsilon, params.radius, parameters.atoms.centerTypes[i])
  }
  
  print()
  print("bonds:")
  for i in parameters.bonds.indices.indices {
    let bond = parameters.bonds.indices[i]
    let params = parameters.bonds.parameters[i]
    let extendedParams = parameters.bonds.extendedParameters[i]
    print("-", parameters.atoms.atomicNumbers[Int(bond[0])], parameters.atoms.atomicNumbers[Int(bond[1])], params.potentialWellDepth, params.equilibriumLength, params.stretchingStiffness, extendedParams?.dipoleMoment as Any)
  }
  
  print()
  print("angles:")
  for i in parameters.angles.indices.indices {
    let angle = parameters.angles.indices[i]
    let params = parameters.angles.parameters[i]
    let extendedParams = parameters.angles.extendedParameters[i]
    print("-", parameters.atoms.atomicNumbers[Int(angle[0])], parameters.atoms.atomicNumbers[Int(angle[1])], parameters.atoms.atomicNumbers[Int(angle[2])], params.equilibriumAngle, params.bendingStiffness, params.stretchBendStiffness, extendedParams as Any)
  }
  
  return topology.atoms
}

/*
 Before the fix to the algorithm for computing angle type:
 
 angles:
 - 6 6 6 111.8 0.74 0.14 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 1 6 1 107.7 0.54 0.0 nil
 - 6 6 6 111.8 0.74 0.14 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 1 6 1 107.7 0.54 0.0 nil
 - 6 6 6 111.8 0.74 0.14 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 1 6 1 107.7 0.54 0.0 nil
 - 6 6 6 110.4 0.74 0.14 nil
 - 6 6 6 110.4 0.74 0.14 nil
 - 6 6 1 108.9 0.59 0.1 nil
 - 6 6 6 110.4 0.74 0.14 nil
 - 6 6 1 108.9 0.59 0.1 nil
 - 6 6 1 108.9 0.59 0.1 nil
 - 6 6 14 111.5 0.4 0.14 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 14 6 1 110.0 0.54 0.1 nil
 - 14 6 1 110.0 0.54 0.1 nil
 - 1 6 1 107.7 0.54 0.0 nil
 - 6 6 6 110.4 0.74 0.14 nil
 - 6 6 6 110.4 0.74 0.14 nil
 - 6 6 1 108.9 0.59 0.1 nil
 - 6 6 6 110.4 0.74 0.14 nil
 - 6 6 1 108.9 0.59 0.1 nil
 - 6 6 1 108.9 0.59 0.1 nil
 - 6 6 14 111.5 0.4 0.14 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 14 6 1 110.0 0.54 0.1 nil
 - 14 6 1 110.0 0.54 0.1 nil
 - 1 6 1 107.7 0.54 0.0 nil
 - 6 6 6 110.4 0.74 0.14 nil
 - 6 6 6 110.4 0.74 0.14 nil
 - 6 6 1 108.9 0.59 0.1 nil
 - 6 6 6 110.4 0.74 0.14 nil
 - 6 6 1 108.9 0.59 0.1 nil
 - 6 6 1 108.9 0.59 0.1 nil
 - 6 6 14 111.5 0.4 0.14 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 6 6 1 109.47 0.56 0.1 nil
 - 14 6 1 110.0 0.54 0.1 nil
 - 14 6 1 110.0 0.54 0.1 nil
 - 1 6 1 107.7 0.54 0.0 nil
 - 6 14 6 110.4 0.48 0.06 nil
 - 6 14 6 110.4 0.48 0.06 nil
 - 6 14 1 109.3 0.4 0.1 nil
 - 6 14 6 110.4 0.48 0.06 nil
 - 6 14 1 109.3 0.4 0.1 nil
 - 6 14 1 109.3 0.4 0.1 nil
 */

/*
 After the fix to the algorithm for computing angle type:
 */
