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
    Material { .checkerboard(.carbon, .germanium) }
    
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
      
//      Volume {
//        Origin { 0.3 * l }
//        Plane { l }
//        Replace { .atom(.germanium) }
//      }
    }
  }
  
  var topology = Topology()
  topology.insert(atoms: lattice.atoms)
  let matches = topology.match(topology.atoms, algorithm: .covalentBondLength(1.1))
  
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
  let hGeBondLength = Float(1.529) / 10
  
  var insertedAtoms: [Entity] = []
  insertedBonds = []
  for i in topology.atoms.indices {
    let carbon = topology.atoms[i]
    for orbital in orbitals[i] {
//      if carbon.atomicNumber == 16 {
//        continue
//      }
//      precondition(carbon.atomicNumber == 6)
      let bondLength = (carbon.atomicNumber == 6) ? chBondLength : hGeBondLength
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
  var parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  print()
  print("atoms:")
  for i in parameters.atoms.indices {
    let atomicNumber = parameters.atoms.atomicNumbers[i]
    let params = parameters.atoms.parameters[i]
    print("-", atomicNumber, params.charge, params.hydrogenReductionFactor, params.epsilon, params.radius, parameters.atoms.centerTypes[i] as Any)
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
  
  // MARK: - xTB
  
  let process = XTBProcess(path: "/Users/philipturner/Documents/OpenMM/xtb/cpu0")
  process.writeFile(name: "xtb.inp", process.encodeSettings())
  process.writeFile(name: "coord", try! process.encodeAtoms(topology.atoms))
  process.run(arguments: ["coord", "--input", "xtb.inp", "--opt"])
  let optimized1 = try! process.decodeAtoms(process.readFile(name: "xtbopt.coord"))
  
  process.run(arguments: ["coord", "--input", "xtb.inp", "--opt", "--gfnff"])
  let optimized2 = try! process.decodeAtoms(process.readFile(name: "xtbopt.coord"))
  
  // MARK: - OpenMM
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  forceField.minimize()
  
  print()
  print("bonds:")
  var bondSum: Float = .zero
  var bondSize: Int = .zero
  var bondSum2: Float = .zero
  var bondSize2: Int = .zero
  var bondSum3: Float = .zero
  var bondSize3: Int = .zero
  var bondSum4: Float = .zero
  var bondSize4: Int = .zero
  var bondSum5: Float = .zero
  var bondSize5: Int = .zero
  
  for i in parameters.bonds.indices.indices {
    let bond = parameters.bonds.indices[i]
    let delta = forceField.positions[Int(bond[0])] - forceField.positions[Int(bond[1])]
    let length = (delta * delta).sum().squareRoot()
    print("-", parameters.atoms.atomicNumbers[Int(bond[0])], parameters.atoms.atomicNumbers[Int(bond[1])], 10 * length)
    
    if parameters.atoms.atomicNumbers[Int(bond[0])] == 32,
       parameters.atoms.atomicNumbers[Int(bond[1])] == 6 {
      bondSum += 10 * length
      bondSize += 1
    }
    if parameters.atoms.atomicNumbers[Int(bond[0])] == 6,
       parameters.atoms.atomicNumbers[Int(bond[1])] == 32 {
      bondSum += 10 * length
      bondSize += 1
    }
    if parameters.atoms.atomicNumbers[Int(bond[0])] == 6,
       parameters.atoms.atomicNumbers[Int(bond[1])] == 1 {
      bondSum2 += 10 * length
      bondSize2 += 1
    }
    if parameters.atoms.atomicNumbers[Int(bond[0])] == 32,
       parameters.atoms.atomicNumbers[Int(bond[1])] == 1 {
      bondSum3 += 10 * length
      bondSize3 += 1
    }
  }
  
  print()
  print("sum:")
  print(bondSum / Float(bondSize))
  print(bondSum2 / Float(bondSize2))
  print(bondSum3 / Float(bondSize3))
  print(bondSum4 / Float(bondSize4))
  print(bondSum5 / Float(bondSize5))
  
  print()
  print("angles:")
  var angleSum: Float = .zero
  var angleSize: Int = .zero
  var angleSum2: Float = .zero
  var angleSize2: Int = .zero
  var angleSum3: Float = .zero
  var angleSize3: Int = .zero
  var angleSum4: Float = .zero
  var angleSize4: Int = .zero
  var angleSum5: Float = .zero
  var angleSize5: Int = .zero
  
  for i in parameters.angles.indices.indices {
    let angle = parameters.angles.indices[i]
    var delta1 = forceField.positions[Int(angle[0])] - forceField.positions[Int(angle[1])]
    var delta2 = forceField.positions[Int(angle[2])] - forceField.positions[Int(angle[1])]
    delta1 /= (delta1 * delta1).sum().squareRoot()
    delta2 /= (delta2 * delta2).sum().squareRoot()
    let dotProduct = (delta1 * delta2).sum()
    let angleMeasure = Float.acos(dotProduct) * 180 / .pi
    print("-", parameters.atoms.atomicNumbers[Int(angle[0])], parameters.atoms.atomicNumbers[Int(angle[1])], parameters.atoms.atomicNumbers[Int(angle[2])], angleMeasure)
    
    if parameters.atoms.atomicNumbers[Int(angle[0])] == 32,
       parameters.atoms.atomicNumbers[Int(angle[1])] == 6,
       parameters.atoms.atomicNumbers[Int(angle[2])] == 32 {
      angleSum += angleMeasure
      angleSize += 1
    }
    if parameters.atoms.atomicNumbers[Int(angle[0])] == 6,
       parameters.atoms.atomicNumbers[Int(angle[1])] == 32,
       parameters.atoms.atomicNumbers[Int(angle[2])] == 6 {
      angleSum2 += angleMeasure
      angleSize2 += 1
    }
    if parameters.atoms.atomicNumbers[Int(angle[0])] == 32,
       parameters.atoms.atomicNumbers[Int(angle[1])] == 6,
       parameters.atoms.atomicNumbers[Int(angle[2])] == 1 {
      angleSum3 += angleMeasure
      angleSize3 += 1
    }
    if parameters.atoms.atomicNumbers[Int(angle[0])] == 6,
       parameters.atoms.atomicNumbers[Int(angle[1])] == 32,
       parameters.atoms.atomicNumbers[Int(angle[2])] == 1 {
      angleSum4 += angleMeasure
      angleSize4 += 1
    }
    if parameters.atoms.atomicNumbers[Int(angle[0])] == 1,
       parameters.atoms.atomicNumbers[Int(angle[1])] == 32,
       parameters.atoms.atomicNumbers[Int(angle[2])] == 1 {
      angleSum5 += angleMeasure
      angleSize5 += 1
    }
  }
  
  print()
  print("sum:")
  print(angleSum / Float(angleSize))
  print(angleSum2 / Float(angleSize2))
  print(angleSum3 / Float(angleSize3))
  print(angleSum4 / Float(angleSize4))
  print(angleSum5 / Float(angleSize5))
  
  // MARK: - Output
  
  var output: [Entity] = []
  func transform(_ positions: [SIMD3<Float>], shift: SIMD3<Float>) {
    for i in topology.atoms.indices {
      var atom = topology.atoms[i]
      atom.position = positions[i] + shift
      output.append(atom)
    }
  }
  transform(topology.atoms.map(\.position), shift: SIMD3(-0.35, 0.5, -0.35))
  transform(forceField.positions, shift: SIMD3(0.35, 0.5, 0.35))
  transform(optimized1.map(\.position), shift: SIMD3(-0.35, -0.6, -0.35))
  transform(optimized2.map(\.position), shift: SIMD3(0.35, -0.6, 0.35))
  
  // Copy the table from Google Sheets, this source file w/ raw data, and a
  // screenshot into HardwareCatalog/Simulation.
  return output
}
