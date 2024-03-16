// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

// Create a test of whether the Windows workspace works correctly. Then,
// create a performance test that can prove the AMD 7900 XTX simulates
// faster than the M1 Max.
//
// Upload both of these to GitHub, along with expected values for outputs of
// the simulations. Attach the second monitor to the Mac while creating these
// tests. Then, switch contexts to just focusing on Windows.
//
// The next logical step would be serializing MD simulations as uncompressed
// binary data. Is the serialization bandwidth a bottleneck in reasonable types
// of simulations?
func createGeometry() -> [Entity] {
  let minimizationTest = MinimizationTest()
  return minimizationTest.topology.atoms
}

struct MinimizationTest {
  var topology = Topology()
  
  init() {
    createLattice()
    createBulkAtomBonds()
    createHydrogens()
    minimize()
  }
  
  mutating func createLattice() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 10 * h + 3 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 1.4 * l }
        Plane { l }
        Replace { .empty }
      }
      
      Volume {
        Concave {
          Convex {
            Origin { 0.1 * l }
            Plane { -l }
          }
          Convex {
            Origin { 0.5 * h2k }
            Plane { h2k }
          }
          Convex {
            Origin { 2.5 * h2k }
            Plane { -h2k }
          }
          Convex {
            Origin { 0.5 * h }
            Plane { h }
          }
          Convex {
            Origin { 9.5 * h }
            Plane { -h }
          }
        }
        Replace { .atom(.phosphorus) }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func createBulkAtomBonds() {
    let radius = Element.carbon.covalentRadius * 2.2
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(radius))
    var insertedBonds: [SIMD2<UInt32>] = []
    
    for i in topology.atoms.indices {
      let match = matches[i]
      if match.count > 5 {
        fatalError("Unexpected situation: match count > 5")
      } else if match.count > 2 {
        for j in match where i < j {
          insertedBonds.append(SIMD2(UInt32(i), j))
        }
      } else {
        fatalError("Pathological atoms should be removed.")
      }
    }
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func createHydrogens() {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    
    for atomID in topology.atoms.indices {
      for orbital in orbitals[atomID] {
        let atom = topology.atoms[atomID]
        if atom.atomicNumber == 15 {
          continue
        }
        let carbon = atom
        
        let chBondLength = Element.carbon.covalentRadius +
        Element.hydrogen.covalentRadius
        let hydrogenPosition = carbon.position + chBondLength * orbital
        let hydrogen = Entity(
          position: hydrogenPosition, type: .atom(.hydrogen))
        
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func minimize() {
    // Initialize the parameters.
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    // Validate that the charges are correct.
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let charge = parameters.atoms.parameters[atomID].charge
      func compare(expected: Float) -> Float {
        (charge - expected).magnitude
      }
      
      switch atom.atomicNumber {
      case 1:
        guard compare(expected: 0) < 1e-3 else {
          fatalError("Hydrogen had unexpected charge.")
        }
      case 6:
        guard compare(expected: 0.0) < 1e-3
                || compare(expected: 0.10444193) < 1e-3
                || compare(expected: 0.20902362) < 1e-3
                || compare(expected: 0.31366998) < 1e-3 else {
          fatalError("Carbon had unexpected charge.")
        }
      case 15:
        guard compare(expected: -0.31334317) < 1e-3 else {
          fatalError("Phosphorus had unexpected charge.")
        }
      default:
        fatalError("Unexpected atomic number.")
      }
    }
    
    // Set up the simulator.
    
  }
}
