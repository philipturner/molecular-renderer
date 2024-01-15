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
    print("-", atomicNumber, params.charge, params.hydrogenReductionFactor, params.epsilon, params.radius, parameters.atoms.centerTypes[i] as Any)
  }
  
//  print()
//  print("bonds:")
//  for i in parameters.bonds.indices.indices {
//    let bond = parameters.bonds.indices[i]
//    let params = parameters.bonds.parameters[i]
//    let extendedParams = parameters.bonds.extendedParameters[i]
//    print("-", parameters.atoms.atomicNumbers[Int(bond[0])], parameters.atoms.atomicNumbers[Int(bond[1])], params.potentialWellDepth, params.equilibriumLength, params.stretchingStiffness, extendedParams?.dipoleMoment as Any)
//  }
//
//  print()
//  print("angles:")
//  for i in parameters.angles.indices.indices {
//    let angle = parameters.angles.indices[i]
//    let params = parameters.angles.parameters[i]
//    let extendedParams = parameters.angles.extendedParameters[i]
//    print("-", parameters.atoms.atomicNumbers[Int(angle[0])], parameters.atoms.atomicNumbers[Int(angle[1])], parameters.atoms.atomicNumbers[Int(angle[2])], params.equilibriumAngle, params.bendingStiffness, params.stretchBendStiffness, extendedParams as Any)
//  }
  
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
  for i in parameters.bonds.indices.indices {
    let bond = parameters.bonds.indices[i]
    let delta = forceField.positions[Int(bond[0])] - forceField.positions[Int(bond[1])]
    let length = (delta * delta).sum().squareRoot()
    print("-", parameters.atoms.atomicNumbers[Int(bond[0])], parameters.atoms.atomicNumbers[Int(bond[1])], 10 * length)
  }
  
  print()
  print("angles:")
  for i in parameters.angles.indices.indices {
    let angle = parameters.angles.indices[i]
    var delta1 = forceField.positions[Int(angle[0])] - forceField.positions[Int(angle[1])]
    var delta2 = forceField.positions[Int(angle[2])] - forceField.positions[Int(angle[1])]
    delta1 /= (delta1 * delta1).sum().squareRoot()
    delta2 /= (delta2 * delta2).sum().squareRoot()
    let dotProduct = (delta1 * delta2).sum()
    let angleMeasure = Float.acos(dotProduct) * 180 / .pi
    print("-", parameters.atoms.atomicNumbers[Int(angle[0])], parameters.atoms.atomicNumbers[Int(angle[1])], parameters.atoms.atomicNumbers[Int(angle[2])], angleMeasure)
  }
  
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
  transform(optimized1.map(\.position), shift: SIMD3(-0.35, -0.5, -0.35))
  transform(optimized2.map(\.position), shift: SIMD3(0.35, -0.5, 0.35))
  
  // Copy the table from Google Sheets, this source file w/ raw data, and a
  // screenshot into HardwareCatalog/Simulation.
  return output
}

/*
 MM4Parameters:
 
 atoms:
 - 6 0.0 0.94 (default: 0.037, hydrogen: 0.024) (default: 1.96, hydrogen: 3.41) Optional(MM4.MM4CenterType.secondary)
 - 6 0.0 0.94 (default: 0.037, hydrogen: 0.024) (default: 1.96, hydrogen: 3.41) Optional(MM4.MM4CenterType.secondary)
 - 6 0.0 0.94 (default: 0.037, hydrogen: 0.024) (default: 1.96, hydrogen: 3.41) Optional(MM4.MM4CenterType.secondary)
 - 6 0.0 0.94 (default: 0.037, hydrogen: 0.024) (default: 1.96, hydrogen: 3.41) Optional(MM4.MM4CenterType.tertiary)
 - 6 -0.07768444 0.94 (default: 0.037, hydrogen: 0.024) (default: 1.96, hydrogen: 3.41) Optional(MM4.MM4CenterType.secondary)
 - 6 0.0 0.94 (default: 0.037, hydrogen: 0.024) (default: 1.96, hydrogen: 3.41) Optional(MM4.MM4CenterType.tertiary)
 - 6 -0.07768444 0.94 (default: 0.037, hydrogen: 0.024) (default: 1.96, hydrogen: 3.41) Optional(MM4.MM4CenterType.secondary)
 - 6 0.0 0.94 (default: 0.037, hydrogen: 0.024) (default: 1.96, hydrogen: 3.41) Optional(MM4.MM4CenterType.tertiary)
 - 6 -0.07768444 0.94 (default: 0.037, hydrogen: 0.024) (default: 1.96, hydrogen: 3.41) Optional(MM4.MM4CenterType.secondary)
 - 14 0.23305333 0.923 (default: 0.14, hydrogen: 0.048785247) (default: 2.29, hydrogen: 3.9299998) Optional(MM4.MM4CenterType.tertiary)
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil
 - 1 0.0 0.94 (default: 0.017, hydrogen: -1.0) (default: 1.64, hydrogen: -1.0) nil

 bonds:
 - 6 6 1.13 1.5306 4.55 nil
 - 6 6 1.13 1.5306 4.55 nil
 - 6 6 1.13 1.5306 4.55 nil
 - 6 6 1.13 1.5306 4.55 nil
 - 6 6 1.13 1.5306 4.55 nil
 - 6 6 1.13 1.5306 4.55 nil
 - 6 6 1.13 1.5359999 4.55 nil
 - 6 14 0.812 1.876 3.05 Optional(-0.7)
 - 6 6 1.13 1.5359999 4.55 nil
 - 6 14 0.812 1.876 3.05 Optional(-0.7)
 - 6 6 1.13 1.5359999 4.55 nil
 - 6 14 0.812 1.876 3.05 Optional(-0.7)
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.74 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.74 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.74 nil
 - 6 1 0.854 1.112 4.67 nil
 - 6 1 0.854 1.112 4.67 nil
 - 14 1 0.777 1.483 2.65 nil

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
 OpenMM:
 
 bonds:
 - 6 6 0.15472588
 - 6 6 0.1547131
 - 6 6 0.15472381
 - 6 6 0.15471596
 - 6 6 0.15471248
 - 6 6 0.15471436
 - 6 6 0.15502365
 - 6 14 0.18696809
 - 6 6 0.15502153
 - 6 14 0.18696742
 - 6 6 0.15502508
 - 6 14 0.18696918
 - 6 1 0.11140085
 - 6 1 0.111419655
 - 6 1 0.11142027
 - 6 1 0.11139951
 - 6 1 0.11140765
 - 6 1 0.11142132
 - 6 1 0.11158862
 - 6 1 0.11129242
 - 6 1 0.11129525
 - 6 1 0.111587346
 - 6 1 0.111296736
 - 6 1 0.111293
 - 6 1 0.11159266
 - 6 1 0.11129322
 - 6 1 0.11129263
 - 14 1 0.14820552

 angles:
 - 6 6 6 113.13446
 - 6 6 1 109.62672
 - 6 6 1 109.025764
 - 6 6 1 109.63155
 - 6 6 1 109.030495
 - 1 6 1 106.14908
 - 6 6 6 113.13373
 - 6 6 1 109.02602
 - 6 6 1 109.628456
 - 6 6 1 109.0291
 - 6 6 1 109.63144
 - 1 6 1 106.14937
 - 6 6 6 113.139656
 - 6 6 1 109.627426
 - 6 6 1 109.02997
 - 6 6 1 109.62613
 - 6 6 1 109.0295
 - 1 6 1 106.144806
 - 6 6 6 109.992805
 - 6 6 6 111.13989
 - 6 6 1 108.226616
 - 6 6 6 111.14463
 - 6 6 1 108.23162
 - 6 6 1 107.99261
 - 6 6 14 106.77816
 - 6 6 1 110.841576
 - 6 6 1 110.8379
 - 14 6 1 110.36456
 - 14 6 1 110.36321
 - 1 6 1 107.68193
 - 6 6 6 109.99113
 - 6 6 6 111.13984
 - 6 6 1 108.22666
 - 6 6 6 111.14465
 - 6 6 1 108.23179
 - 6 6 1 107.994194
 - 6 6 14 106.7793
 - 6 6 1 110.83774
 - 6 6 1 110.84179
 - 14 6 1 110.36307
 - 14 6 1 110.36455
 - 1 6 1 107.680916
 - 6 6 6 109.997055
 - 6 6 6 111.14368
 - 6 6 1 108.22761
 - 6 6 6 111.14239
 - 6 6 1 108.22682
 - 6 6 1 107.99033
 - 6 6 14 106.77642
 - 6 6 1 110.83978
 - 6 6 1 110.84065
 - 14 6 1 110.36366
 - 14 6 1 110.363976
 - 1 6 1 107.682846
 - 6 14 6 103.94687
 - 6 14 6 103.94582
 - 6 14 1 114.55231
 - 6 14 6 103.94578
 - 6 14 1 114.55283
 - 6 14 1 114.551796
 */

/*
 GFN2-xTB:

Bond Distances (Angstroems)
---------------------------
C1-C6=1.5301         C1-C8=1.5301         C1-H11=1.0931        C1-H12=1.0940        C2-C4=1.5301         C2-C8=1.5301
C2-H13=1.0940        C2-H14=1.0931        C3-C4=1.5301         C3-C6=1.5301         C3-H15=1.0931        C3-H16=1.0940
C4-C2=1.5301         C4-C3=1.5301         C4-C5=1.5312         C4-H17=1.0990        C5-C4=1.5312         C5-Si10=1.8956
C5-H18=1.0906        C5-H19=1.0906        C6-C1=1.5301         C6-C3=1.5301         C6-C7=1.5312         C6-H20=1.0990
C7-C6=1.5312         C7-Si10=1.8956       C7-H21=1.0906        C7-H22=1.0906        C8-C1=1.5301         C8-C2=1.5301
C8-C9=1.5312         C8-H23=1.0990        C9-C8=1.5312         C9-Si10=1.8956       C9-H24=1.0906        C9-H25=1.0906
Si10-C5=1.8956       Si10-C7=1.8956       Si10-C9=1.8956       Si10-H26=1.4662      H11-C1=1.0931        H12-C1=1.0940
H13-C2=1.0940        H14-C2=1.0931        H15-C3=1.0931        H16-C3=1.0940        H17-C4=1.0990        H18-C5=1.0906
H19-C5=1.0906        H20-C6=1.0990        H21-C7=1.0906        H22-C7=1.0906        H23-C8=1.0990        H24-C9=1.0906
H25-C9=1.0906        H26-Si10=1.4662
C  H  Rav=1.0934 sigma=0.0031  Rmin=1.0906  Rmax=1.0990    15
C  C  Rav=1.5305 sigma=0.0005  Rmin=1.5301  Rmax=1.5312     9
Si H  Rav=1.4662 sigma=0.0000  Rmin=1.4662  Rmax=1.4662     1
Si C  Rav=1.8956 sigma=0.0000  Rmin=1.8956  Rmax=1.8956     3

selected bond angles (degree)
--------------------
C8-C1-C6=113.33                H11-C1-C6=109.40               H11-C1-C8=109.40               H12-C1-C6=108.52
H12-C1-C8=108.52               H12-C1-H11=107.48              C8-C2-C4=113.33                H13-C2-C4=108.52
H13-C2-C8=108.52               H14-C2-C4=109.40               H14-C2-C8=109.40               H14-C2-H13=107.48
C6-C3-C4=113.33                H15-C3-C4=109.40               H15-C3-C6=109.40               H16-C3-C4=108.52
H16-C3-C6=108.52               H16-C3-H15=107.48              C3-C4-C2=109.83                C5-C4-C2=111.60
C5-C4-C3=111.60                H17-C4-C2=107.66               H17-C4-C3=107.66               H17-C4-C5=108.32
Si10-C5-C4=106.92              H18-C5-C4=109.35               H18-C5-Si10=112.22             H19-C5-C4=109.34
H19-C5-Si10=112.22             H19-C5-H18=106.76              C3-C6-C1=109.83                C7-C6-C1=111.60
C7-C6-C3=111.60                H20-C6-C1=107.66               H20-C6-C3=107.66               H20-C6-C7=108.32
Si10-C7-C6=106.92              H21-C7-C6=109.34               H21-C7-Si10=112.22             H22-C7-C6=109.35
H22-C7-Si10=112.22             H22-C7-H21=106.76              C2-C8-C1=109.83                C9-C8-C1=111.60
C9-C8-C2=111.60                H23-C8-C1=107.66               H23-C8-C2=107.66               H23-C8-C9=108.32
Si10-C9-C8=106.92              H24-C9-C8=109.35               H24-C9-Si10=112.22             H25-C9-C8=109.35
H25-C9-Si10=112.22             H25-C9-H24=106.76              C7-Si10-C5=102.64              C9-Si10-C5=102.64
C9-Si10-C7=102.64              H26-Si10-C5=115.66             H26-Si10-C7=115.66             H26-Si10-C9=115.66

   #   Z          covCN         q      C6AA      α(0)
   1   6 c        3.810    -0.063    21.695     6.630
   2   6 c        3.810    -0.063    21.695     6.630
   3   6 c        3.810    -0.063    21.695     6.630
   4   6 c        3.893    -0.015    20.795     6.483
   5   6 c        3.704    -0.158    23.725     6.964
   6   6 c        3.893    -0.015    20.795     6.483
   7   6 c        3.704    -0.158    23.725     6.964
   8   6 c        3.893    -0.015    20.795     6.483
   9   6 c        3.704    -0.158    23.725     6.964
  10  14 si       3.672     0.491    97.556    18.927
  11   1 h        0.924     0.023     2.684     2.562
  12   1 h        0.924     0.024     2.679     2.560
  13   1 h        0.924     0.024     2.679     2.560
  14   1 h        0.924     0.023     2.684     2.562
  15   1 h        0.924     0.023     2.684     2.562
  16   1 h        0.924     0.024     2.679     2.560
  17   1 h        0.923     0.016     2.796     2.615
  18   1 h        0.924     0.021     2.721     2.580
  19   1 h        0.924     0.021     2.721     2.580
  20   1 h        0.923     0.016     2.796     2.615
  21   1 h        0.924     0.021     2.721     2.580
  22   1 h        0.924     0.021     2.721     2.580
  23   1 h        0.923     0.016     2.796     2.615
  24   1 h        0.924     0.021     2.721     2.580
  25   1 h        0.924     0.021     2.721     2.580
  26   1 h        0.918    -0.098     5.484     3.663

    molecular mass/u    :      152.3091738
 center of mass at/Å    :        8.1548190       8.1548190       6.3713236
moments of inertia/u·Å² :        0.3390916E+03   0.3721462E+03   0.3721470E+03
rotational constants/cm⁻¹ :        0.4971409E-01   0.4529841E-01   0.4529832E-01

* 28 selected distances

   #   Z          #   Z                                           value/Å
   2   6 c        4   6 c                                       1.5301304
   3   6 c        4   6 c                                       1.5301302
   4   6 c        5   6 c                                       1.5311668
   1   6 c        6   6 c                                       1.5301304
   3   6 c        6   6 c                                       1.5301302
   6   6 c        7   6 c                                       1.5311668
   1   6 c        8   6 c                                       1.5301312
   2   6 c        8   6 c                                       1.5301312
   8   6 c        9   6 c                                       1.5311649
   5   6 c       10  14 si                                      1.8956361
   7   6 c       10  14 si                                      1.8956361
   9   6 c       10  14 si                                      1.8956405 (max)
   1   6 c       11   1 h                                       1.0931111
   1   6 c       12   1 h                                       1.0940073
   2   6 c       13   1 h                                       1.0940073
   2   6 c       14   1 h                                       1.0931111
   3   6 c       15   1 h                                       1.0931114
   3   6 c       16   1 h                                       1.0940077
   4   6 c       17   1 h                                       1.0989940
   5   6 c       18   1 h                                       1.0905603
   5   6 c       19   1 h                                       1.0905614
   6   6 c       20   1 h                                       1.0989940
   7   6 c       21   1 h                                       1.0905614
   7   6 c       22   1 h                                       1.0905603 (min)
   8   6 c       23   1 h                                       1.0989922
   9   6 c       24   1 h                                       1.0905611
   9   6 c       25   1 h                                       1.0905611
  10  14 si      26   1 h                                       1.4661755

* 4 distinct bonds (by element types)

 Z      Z             #   av. dist./Å        max./Å        min./Å
 1 H    6 C          15     1.0934468     1.0989940     1.0905603
 6 C    6 C           9     1.5304758     1.5311668     1.5301302
 1 H   14 Si          1     1.4661755     1.4661755     1.4661755
 6 C   14 Si          3     1.8956376     1.8956405     1.8956361

 */

/*
 GFN-FF:
 
 -------------------------------------------------
|           Force Field Initialization            |
 -------------------------------------------------

atom   neighbors  erfCN metchar sp-hybrid imet pi  qest     coordinates
1  c       4    3.49   0.00         3    0    0  -0.039   15.166000   11.796000   11.796000
2  c       4    3.49   0.00         3    0    0  -0.039   11.796000   15.166000   11.796000
3  c       4    3.49   0.00         3    0    0  -0.039   15.166000   15.166000    8.426000
4  c       4    3.64   0.00         3    0    0  -0.023   13.481000   16.852000   10.111000
5  c       4    3.49   0.00         3    0    0  -0.055   15.166000   18.537000   11.796000
6  c       4    3.64   0.00         3    0    0  -0.023   16.852000   13.481000   10.111000
7  c       4    3.49   0.00         3    0    0  -0.055   18.537000   15.166000   11.796000
8  c       4    3.64   0.00         3    0    0  -0.023   13.481000   13.481000   13.481000
9  c       4    3.49   0.00         3    0    0  -0.055   15.166000   15.166000   15.166000
10  si      4    3.94   0.17         3    0    0   0.063   16.852000   16.852000   13.481000
11  h       1    0.97   0.01         0    0    0   0.020   16.380000   10.583000   13.009000
12  h       1    0.97   0.01         0    0    0   0.020   13.953000   10.583000   10.583000
13  h       1    0.97   0.01         0    0    0   0.020   10.583000   13.953000   10.583000
14  h       1    0.97   0.01         0    0    0   0.020   10.583000   16.380000   13.009000
15  h       1    0.97   0.01         0    0    0   0.020   16.380000   16.380000    7.213000
16  h       1    0.97   0.01         0    0    0   0.020   13.953000   13.953000    7.213000
17  h       1    0.97   0.01         0    0    0   0.018   12.268000   18.065000    8.898000
18  h       1    0.98   0.01         0    0    0   0.020   13.953000   19.750000   13.009000
19  h       1    0.98   0.01         0    0    0   0.020   16.380000   19.750000   10.583000
20  h       1    0.97   0.01         0    0    0   0.018   18.065000   12.268000    8.898000
21  h       1    0.98   0.01         0    0    0   0.020   19.750000   16.380000   10.583000
22  h       1    0.98   0.01         0    0    0   0.020   19.750000   13.953000   13.009000
23  h       1    0.97   0.01         0    0    0   0.018   12.268000   12.268000   14.695000
24  h       1    0.98   0.01         0    0    0   0.020   16.380000   13.953000   16.380000
25  h       1    0.98   0.01         0    0    0   0.020   13.953000   16.380000   16.380000
26  h       1    0.95   0.01         0    0    0  -0.008   18.470000   18.470000   15.099000

Bond Distances (Angstroems)
---------------------------
C1-C6=1.5578         C1-C8=1.5578         C1-H11=1.0964        C1-H12=1.0966        C2-C4=1.5578         C2-C8=1.5578
C2-H13=1.0966        C2-H14=1.0964        C3-C4=1.5578         C3-C6=1.5578         C3-H15=1.0964        C3-H16=1.0966
C4-C2=1.5578         C4-C3=1.5578         C4-C5=1.5400         C4-H17=1.1063        C5-C4=1.5400         C5-Si10=1.8747
C5-H18=1.0918        C5-H19=1.0918        C6-C1=1.5578         C6-C3=1.5578         C6-C7=1.5400         C6-H20=1.1063
C7-C6=1.5400         C7-Si10=1.8747       C7-H21=1.0918        C7-H22=1.0918        C8-C1=1.5578         C8-C2=1.5578
C8-C9=1.5400         C8-H23=1.1063        C9-C8=1.5400         C9-Si10=1.8747       C9-H24=1.0918        C9-H25=1.0918
Si10-C5=1.8747       Si10-C7=1.8747       Si10-C9=1.8747       Si10-H26=1.4795      H11-C1=1.0964        H12-C1=1.0966
H13-C2=1.0966        H14-C2=1.0964        H15-C3=1.0964        H16-C3=1.0966        H17-C4=1.1063        H18-C5=1.0918
H19-C5=1.0918        H20-C6=1.1063        H21-C7=1.0918        H22-C7=1.0918        H23-C8=1.1063        H24-C9=1.0918
H25-C9=1.0918        H26-Si10=1.4795
C  H  Rav=1.0966 sigma=0.0053  Rmin=1.0918  Rmax=1.1063    15
C  C  Rav=1.5519 sigma=0.0084  Rmin=1.5400  Rmax=1.5578     9
Si H  Rav=1.4795 sigma=0.0000  Rmin=1.4795  Rmax=1.4795     1
Si C  Rav=1.8747 sigma=0.0000  Rmin=1.8747  Rmax=1.8747     3

selected bond angles (degree)
--------------------
C8-C1-C6=112.82                H11-C1-C6=109.29               H11-C1-C8=109.29               H12-C1-C6=109.63
H12-C1-C8=109.63               H12-C1-H11=105.95              C8-C2-C4=112.82                H13-C2-C4=109.63
H13-C2-C8=109.63               H14-C2-C4=109.29               H14-C2-C8=109.29               H14-C2-H13=105.95
C6-C3-C4=112.82                H15-C3-C4=109.29               H15-C3-C6=109.29               H16-C3-C4=109.63
H16-C3-C6=109.63               H16-C3-H15=105.95              C3-C4-C2=109.26                C5-C4-C2=111.69
C5-C4-C3=111.69                H17-C4-C2=108.10               H17-C4-C3=108.10               H17-C4-C5=107.88
Si10-C5-C4=106.85              H18-C5-C4=112.01               H18-C5-Si10=108.77             H19-C5-C4=112.01
H19-C5-Si10=108.77             H19-C5-H18=108.33              C3-C6-C1=109.26                C7-C6-C1=111.69
C7-C6-C3=111.69                H20-C6-C1=108.10               H20-C6-C3=108.10               H20-C6-C7=107.88
Si10-C7-C6=106.85              H21-C7-C6=112.01               H21-C7-Si10=108.77             H22-C7-C6=112.01
H22-C7-Si10=108.77             H22-C7-H21=108.33              C2-C8-C1=109.26                C9-C8-C1=111.69
C9-C8-C2=111.69                H23-C8-C1=108.10               H23-C8-C2=108.10               H23-C8-C9=107.88
Si10-C9-C8=106.85              H24-C9-C8=112.01               H24-C9-Si10=108.77             H25-C9-C8=112.01
H25-C9-Si10=108.77             H25-C9-H24=108.33              C7-Si10-C5=103.94              C9-Si10-C5=103.93
C9-Si10-C7=103.93              H26-Si10-C5=114.56             H26-Si10-C7=114.56             H26-Si10-C9=114.56

    molecular mass/u    :      152.3091738
 center of mass at/Å    :        8.1451842       8.1451842       6.3616781
moments of inertia/u·Å² :        0.3433300E+03   0.3756797E+03   0.3756874E+03
rotational constants/cm⁻¹ :        0.4910037E-01   0.4487236E-01   0.4487144E-01

* 22 selected distances

   #   Z          #   Z                                           value/Å
   4   6 c        5   6 c                                       1.5399920
   6   6 c        7   6 c                                       1.5399920
   8   6 c        9   6 c                                       1.5399963
   5   6 c       10  14 si                                      1.8746603
   7   6 c       10  14 si                                      1.8746603
   9   6 c       10  14 si                                      1.8746640 (max)
   1   6 c       11   1 h                                       1.0964458
   1   6 c       12   1 h                                       1.0966435
   2   6 c       13   1 h                                       1.0966435
   2   6 c       14   1 h                                       1.0964458
   3   6 c       15   1 h                                       1.0964461
   3   6 c       16   1 h                                       1.0966435
   4   6 c       17   1 h                                       1.1063421
   5   6 c       18   1 h                                       1.0917523 (min)
   5   6 c       19   1 h                                       1.0917541
   6   6 c       20   1 h                                       1.1063421
   7   6 c       21   1 h                                       1.0917541
   7   6 c       22   1 h                                       1.0917523
   8   6 c       23   1 h                                       1.1063397
   9   6 c       24   1 h                                       1.0917543
   9   6 c       25   1 h                                       1.0917543
  10  14 si      26   1 h                                       1.4795304

* 4 distinct bonds (by element types)

 Z      Z             #   av. dist./Å        max./Å        min./Å
 1 H    6 C          15     1.0965875     1.1063421     1.0917523
 6 C    6 C           3     1.5399934     1.5399963     1.5399920
 1 H   14 Si          1     1.4795304     1.4795304     1.4795304
 6 C   14 Si          3     1.8746616     1.8746640     1.8746603

 */
