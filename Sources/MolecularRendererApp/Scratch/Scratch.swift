// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// Recreate C2DonationNH using CBN's benzene geometry, attached to a silicon
// surface. This will be a challenging test of the compiler and how nonbonding
// orbitals can be used to attach atoms. It may also be interesting to see how
// this compiler can facilitate deformation/animation of individual atoms.
//
// In addition, experience using xTB for more advanced analysis:
// - derive structural parameters from simulation data (C-N bond length)
// - perform energy minimizations of the strain from germanium instead of
//   manually adjusting nearby carbons
// - potentially using minimized structures in the middle of the compilation
//   process (e.g. the strained germ-adamantane to more accurately place
//   remaining functional groups)

// TODO:
// - minimize the leg structure in GFN2-xTB
//   - change the NH into NH2 groups
//   - add hydrogens where it will attach to the adamantane
//   - use this information to refine the C-N and C-F bond lengths
// - minimize the adamantane in isolation using GFN2-xTB
// - minimize the entire tripod using GFN-FF
//   - change the NH into NH2 groups
//   - don't add positional constraints, see whether benzenes stay in position
// - minimize the tripod and surface structure using GFN-FF with positional
//   constraint on the silicon atoms
//   - use germanium markers in the Lattice<Cubic> to mark binding sites on the
//     surface of the hexagonal prism

func createCBNTripod() -> [MRAtom] {
  // Branch this off into the function that creates leg atoms, making it
  // "createLegTopology()". The unit test will query the results of compilation
  // at every intermediate stage of making the leg topology. This in addition
  // to the assertions when compiling other components of the geometry.
  var topology = Topology()
  topology.atoms = createLegAtoms()
  
  do {
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
  
  do {
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
        let position = atom.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
        
        // Only add the left hydrogen.
        if orbital.x < 0 {
          insertedAtoms.append(hydrogen)
          insertedBonds.append(bond)
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
  
  do {
    // MM4 forcefield:
    // - sp3 C-H bond length is 1.1120 Å.
    // - sp3 Si-H bond length is 1.483 Å.
    //
    // MM4 alkene paper:
    // - sp2 C - sp3 C bond length is 1.501 Å.
    //
    // MM4 amine paper:
    // - sp3 N-H bond length is 1.0340 Å.
    //
    // N-Si bond length is estimated by summing covalent radii.
    let chBondLength: Float = 1.1120 / 10
    let sihBondLength: Float = 1.483 / 10
    let ccBondLength: Float = 1.501 / 10
    let nhBondLength: Float = 1.0340 / 10
    let nsiBondLength =
    Element.nitrogen.covalentRadius + Element.silicon.covalentRadius
    
    // Create a prototypical methane/silane geometry to insert into the
    // structure.
    func createMethaneAnalogue(_ element: Element) -> [Entity] {
      return []
    }
    
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
        angle: 120 * .pi / 180, axis: [0, 1, 0])
      let orbital0 = SIMD3<Float>(0, 1, 0)
      let orbital1 = rotation1.act(on: orbital0)
      let orbital2 = rotation2.act(on: orbital1)
      
      // Add one hydrogen.
      do {
        let position = atom.position + orbital2 * nhBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
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
    
    // print(exportToXTB(topology.atoms.map(MRAtom.init))
  }
  
  do {
    
  }
  
  do {
    // Report, then later import from xTB, bond lengths in the molecule. The end
    // result is a structure ready for programmatic linking to the other stuff.
    //
    // We can't use the raw atom positions directly because that is too severe
    // a loss of information. The minimized molecule is asymmetric and may be
    // tilted off-axis by the simulator.
    //
    // Start by scaling the benzene ring according to the new bond lengths.
    // Then, adjust the other atoms' positions relative to the ring. Propagate
    // changes all the way to the methyl and silyl groups, except remove the
    // hydrogens from those groups.
  }
  
  return topology.atoms.map(MRAtom.init)
}

func createLegAtoms() -> [Entity] {
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
