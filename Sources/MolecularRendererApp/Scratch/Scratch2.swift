//
//  Scratch2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/29/23.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

struct CBNTripodLeg {
  var topology: Topology
  
  init() {
    self.topology = Topology()
    
    // Call the compiler passes here, instead of doing them post-initialization.
    // The final compilation pass (rescaling with xTB data) will eventually be
    // moved from the main function into this file. The preconditions will be
    // changed into XCTAssert invocations during the unit test.
    
    var bondRecord: [SIMD2<UInt8>: Int]
    var expectedRecord: [SIMD2<UInt8>: Int]
    
    compilationPass0()
    
    compilationPass1()
    bondRecord = createBondRecord()
    precondition(topology.atoms.count == 10)
    precondition(topology.bonds.count == 10)
    precondition(bondRecord.keys.count == 3)
    expectedRecord = [
      SIMD2(6, 6): 6,
      SIMD2(6, 7): 1,
      SIMD2(6, 9): 3,
    ]
    for (key, value) in expectedRecord {
      precondition(bondRecord[key] == value)
    }
    
    compilationPass2()
    bondRecord = createBondRecord()
    precondition(topology.atoms.count == 15)
    precondition(topology.bonds.count == 15)
    precondition(bondRecord.keys.count == 4)
    expectedRecord = [
      SIMD2(1, 6): 4,
      SIMD2(6, 6): 7,
      SIMD2(6, 7): 1,
      SIMD2(6, 9): 3,
    ]
    for (key, value) in expectedRecord {
      precondition(bondRecord[key] == value)
    }
    
    compilationPass3()
    bondRecord = createBondRecord()
    precondition(topology.atoms.count == 20)
    precondition(topology.bonds.count == 20)
    precondition(bondRecord.keys.count == 7)
    expectedRecord = [
      SIMD2(1, 6): 4,
      SIMD2(1, 7): 1,
      SIMD2(1, 14): 3,
      SIMD2(6, 6): 7,
      SIMD2(6, 7): 1,
      SIMD2(6, 9): 3,
      SIMD2(7, 14): 1,
    ]
    for (key, value) in expectedRecord {
      precondition(bondRecord[key] == value)
    }
  }
  
  mutating func compilationPass0() {
    let atoms = createLattice()
    topology.insert(atoms: atoms)
  }
  
  mutating func compilationPass1() {
    // Graphene's covalent bond length is 1.42 Å.
    let covalentBondLength: Float = 1.42 / 10
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(covalentBondLength * 1.01))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func compilationPass2() {
    // MM4 alkene paper:
    // - sp2 C-H bond length is 1.103 Å.
    // - sp2 C-C bond length is 1.335 Å.
    // - Alternative bond length for benzene is 1.39 Å.
    // - https://chem.libretexts.org/Courses/University_of_Illinois_Springfield/UIS%3A_CHE_267_-_Organic_Chemistry_I_(Morsch)/Chapters/Chapter_13%3A_Benzene_and_Aromatic_Compounds/13.02_The_Structure_of_Benzene
    //
    // MM3 Tinker parameters:
    // - sp2 C-N bond length is 1.3690 Å.
    // - sp2 C-F bond length is 1.3535 Å.
    //
    // MM4 C-C bond length seems off from the bond length in graphene. That's
    // likely because the bonds between carbons have sp3 character. However, the
    // cited bonds to N and F do not have an ambiguity in hybridization
    // character. The are what happens when a carbon with **any** sp2 bonds
    // connects to N or F. Therefore, these bond lengths from typical alkenes
    // should transfer directly to aromatic hydrocarbons.
    let chBondLength: Float = 1.103 / 10
    let cnBondLength: Float = 1.3690 / 10
    let cfBondLength: Float = 1.3535 / 10
    
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp2)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      let atom = topology.atoms[i]
      if let orbital = orbitals[i].first {
        if orbital.x < 0 {
          // Add a hydrogen to the left.
          let position = atom.position + orbital * chBondLength
          let hydrogen = Entity(position: position, type: .atom(.hydrogen))
          let hydrogenID = topology.atoms.count + insertedAtoms.count
          let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
          insertedAtoms.append(hydrogen)
          insertedBonds.append(bond)
        } else {
          // Add a methyl group to the right.
          //
          // MM4 alkene paper:
          // - sp2 C - sp3 C bond length is 1.501 Å.
          let ccBondLength: Float = 1.501 / 10
          let carbonPosition = atom.position + orbital * ccBondLength
          
          var methane = createMethaneAnalogue(.carbon)
          methane.remove(at: 1)
          for i in methane.indices {
            methane[i].position += carbonPosition
          }
          let carbonID = topology.atoms.count + insertedAtoms.count
          let carbonBond = SIMD2(UInt32(i), UInt32(carbonID))
          insertedAtoms.append(methane[0])
          insertedBonds.append(carbonBond)
          
          for j in 1...3 {
            let hydrogenID = topology.atoms.count + insertedAtoms.count
            let bond = SIMD2(UInt32(carbonID), UInt32(hydrogenID))
            insertedAtoms.append(methane[j])
            insertedBonds.append(bond)
          }
        }
        continue
      }
      guard atom.atomicNumber == 7 || atom.atomicNumber == 9 else {
        continue
      }
      
      let neighbors = atomsToAtomsMap[i]
      precondition(neighbors.count == 1)
      let neighbor = topology.atoms[Int(neighbors.first!)]
      var delta = atom.position - neighbor.position
      delta /= (delta * delta).sum().squareRoot()
      
      let bondLength = (atom.atomicNumber == 7) ? cnBondLength : cfBondLength
      let position = neighbor.position + delta * bondLength
      topology.atoms[i].position = position
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func compilationPass3() {
    // MM4 amine paper:
    // - sp3 N-H bond length is 1.0340 Å.
    //
    // N-Si bond length is estimated by summing covalent radii.
    let nhBondLength: Float = 1.0340 / 10
    let nsiBondLength =
    Element.nitrogen.covalentRadius + Element.silicon.covalentRadius
    
    var nitrogenID: Int = -1
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      let atom = topology.atoms[i]
      guard atom.atomicNumber == 7 else {
        continue
      }
      nitrogenID = i
      
      let rotation1 = Quaternion<Float>(
        angle: 109.47 * .pi / 180, axis: [1, 0, 0])
      let rotation2 = Quaternion<Float>(
        angle: -120 * .pi / 180, axis: [0, 1, 0])
      let orbital0 = SIMD3<Float>(0, 1, 0)
      let orbital1 = rotation1.act(on: orbital0)
      let orbital2 = rotation2.act(on: orbital1)
      
      // Add a hydrogen to the left.
      do {
        let position = atom.position + orbital2 * nhBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
      
      // Add a silyl group to the front.
      do {
        let siliconPosition = atom.position + orbital1 * nsiBondLength
        var silane = createMethaneAnalogue(.silicon)
        silane.remove(at: 3)
        for i in silane.indices {
          silane[i].position += siliconPosition
        }
        let carbonID = topology.atoms.count + insertedAtoms.count
        let carbonBond = SIMD2(UInt32(i), UInt32(carbonID))
        insertedAtoms.append(silane[0])
        insertedBonds.append(carbonBond)
        
        for j in 1...3 {
          let hydrogenID = topology.atoms.count + insertedAtoms.count
          let bond = SIMD2(UInt32(carbonID), UInt32(hydrogenID))
          insertedAtoms.append(silane[j])
          insertedBonds.append(bond)
        }
      }
    }
    precondition(nitrogenID != -1)
    
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
    
    // Shift the entire molecule according to the nitrogen's position.
    let nitrogen = topology.atoms[nitrogenID]
    let translation = SIMD3<Float>.zero - nitrogen.position
    for i in topology.atoms.indices {
      topology.atoms[i].position += translation
    }
  }
}

extension CBNTripodLeg {
  // Create a prototypical methane/silane geometry to insert into the
  // structure.
  func createMethaneAnalogue(_ element: Element) -> [Entity] {
    // MM4 forcefield:
    // - sp3 C-H bond length is 1.1120 Å.
    // - sp3 Si-H bond length is 1.483 Å.
    let chBondLength: Float = 1.1120 / 10
    let sihBondLength: Float = 1.483 / 10
    
    // carbon   0 -> center
    // hydrogen 1 -> bottom left  (x < 0)
    // hydrogen 2 -> bottom right (x > 0)
    // hydrogen 3 -> upper back  (z < 0)
    // hydrogen 4 -> upper front (z > 0)
    let smallComponent = Float(1.0 / 3).squareRoot()
    let largeComponent = Float(2.0 / 3).squareRoot()
    var orbitals: [SIMD3<Float>] = [
      SIMD3(-largeComponent, -smallComponent, 0),
      SIMD3( largeComponent, -smallComponent, 0),
      SIMD3(0, smallComponent, -largeComponent),
      SIMD3(0, smallComponent,  largeComponent),
    ]
    
    // Tilt the methyl group to match the sp2 orbital.
    if element == .carbon {
      let targetOrbital = SIMD3<Float>(
        -Float(3.0 / 4).squareRoot(), -Float(1.0 / 4).squareRoot(), 0)
      let rotation = Quaternion(from: orbitals[0], to: targetOrbital)
      orbitals = orbitals.map(rotation.act(on:))
    }
    
    var output: [Entity] = []
    output.append(Entity(position: .zero, type: .atom(element)))
    for orbital in orbitals {
      let bondLength = (element == .carbon) ? chBondLength : sihBondLength
      let position = orbital * bondLength
      let hydrogen = Entity(position: position, type: .atom(.hydrogen))
      output.append(hydrogen)
    }
    return output
  }
  
  // Check that all bonds are correctly assigned.
  func createBondRecord() -> [SIMD2<UInt8>: Int] {
    let bondsToAtomsMap = topology.map(.bonds, to: .atoms)
    var bondRecord: [SIMD2<UInt8>: Int] = [:]
    for atomList in bondsToAtomsMap {
      var atomicNumbers = atomList.map {
        topology.atoms[Int($0)].atomicNumber
      }
      atomicNumbers.sort()
      
      let key = SIMD2(atomicNumbers[0], atomicNumbers[1])
      var value = bondRecord[key] ?? 0
      value += 1
      bondRecord[key] = value
    }
    return bondRecord
  }
  
  // Create a lattice with the benzene and immediately connected atoms. Rescale
  // to match the geometry of graphene.
  func createLattice() -> [Entity] {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 4 * h + 3 * h2k + 1 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 0.25 * l }
          Plane { l }
        }
        Replace { .empty }
        
        Origin { 1.5 * h + 1 * h2k }
        
        Volume {
          Convex {
            Origin { 0.5 * h2k }
            Plane { h2k }
          }
          Convex {
            Origin { 0.5 * (-k) }
            Plane { -k }
          }
          Convex {
            Origin { -0.5 * h }
            Origin { 0.5 * (-k-h) }
            Plane { -k - h }
          }
          Replace { .atom(.fluorine) }
        }
        Volume {
          Convex {
            Origin { -0.5 * h2k }
            Plane { -h2k }
          }
          Replace { .atom(.nitrogen) }
        }
        
        Volume {
          Convex {
            Origin { 0.25 * (2 * h + k) }
            Plane { 2 * h + k }
          }
          Convex {
            Origin { -0.75 * h }
            Origin { 0.25 * (k - h) }
            Plane { k - h }
          }
          Concave {
            Convex {
              Origin { -0.5 * h2k }
              Plane { -h2k }
            }
            Convex {
              Convex {
                Origin { 0.75 * (-k) }
                Plane { -k }
              }
              Convex {
                Origin { -1.5 * h }
                Origin { 0.75 * (-k - h) }
                Plane { -k - h }
              }
            }
          }
          Replace { .empty }
        }
      }
    }
    
    var atoms = lattice.atoms
    
    do {
      var grapheneHexagonScale: Float
      
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
      
      for atomID in atoms.indices {
        // Flatten the sp3 sheet into an sp2 sheet.
        atoms[atomID].position.z = 0
        
        // Resize the hexagon side length, so it matches graphene.
        atoms[atomID].position.x *= grapheneHexagonScale
        atoms[atomID].position.y *= grapheneHexagonScale
      }
    }
    
    return atoms
  }
}
