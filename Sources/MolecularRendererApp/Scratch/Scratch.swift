// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

// Create a test of whether the Windows workspace works correctly. Upload this
// to GitHub, with expected values for results of the minimization.
//
// Next, serialize an MD simulation as uncompressed binary data. Validate that
// it deserializes correctly, but do not measure performance. Run a skeleton
// workflow that serializes a simulation on AMD, then loads on Apple.
//
// Finally, archive this somewhere in HardwareCatalog/Serialization. Add a
// brief README that explains why you are transferring data between computers.
// What computers were used, and which one is more powerful?
func createGeometry() -> [Entity] {
  var minimizationTest = MinimizationTest()
  
  // Display the distance matrix.
  print()
  print("Distance Matrix (Before)")
  var distanceMatrix = minimizationTest.createDistanceMatrix()
  let expectedDistanceMatrixBefore: [Float] = [
    0.0, 2.5222497, 1.0206546, 2.7209334, 1.3901006,
    2.5222497, 0.0, 2.7209334, 1.0206546, 1.3901006,
    1.0206546, 2.7209334, 0.0, 2.5222497, 1.3346491,
    2.7209334, 1.0206546, 2.5222497, 0.0, 1.3346491,
    1.3901006, 1.3901006, 1.3346491, 1.3346491, 0.0,
  ]
  for entryID in distanceMatrix.indices {
    let actual = distanceMatrix[entryID]
    let expected = expectedDistanceMatrixBefore[entryID]
    let residual = (actual - expected).magnitude
    print(actual, expected, "|", residual)
  }
  
  minimizationTest.minimize()
  
  // Display the distance matrix.
  print()
  print("Distance Matrix (After)")
  distanceMatrix = minimizationTest.createDistanceMatrix()
  let expectedDistanceMatrixAfter: [Float] = [
    0.0, 2.438077, 1.014804, 2.6170511, 1.383236,
    2.438077, 0.0, 2.6170506, 1.0148034, 1.3832368,
    1.014804, 2.6170506, 0.0, 2.3867698, 1.3189905,
    2.6170511, 1.0148034, 2.3867698, 0.0, 1.318992,
    1.383236, 1.3832368, 1.3189905, 1.318992, 0.0,
  ]
  for entryID in distanceMatrix.indices {
    let actual = distanceMatrix[entryID]
    let expected = expectedDistanceMatrixAfter[entryID]
    let residual = (actual - expected).magnitude
    print(actual, expected, "|", residual)
  }
  
  return minimizationTest.topology.atoms
}

struct MinimizationTest {
  var topology = Topology()
  var markerAtomIndices: [UInt32] = []
  
  init() {
    createLattice()
    createBulkAtomBonds()
    createHydrogens()
    createMarkers()
  }
  
  mutating func createLattice() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 10 * h + 3 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 0.95 * l }
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
  
  mutating func createMarkers() {
    // Gather the distribution of nucleus positions.
    var boundingBoxMin: SIMD3<Float> = .zero
    var boundingBoxMax: SIMD3<Float> = .zero
    boundingBoxMin = .init(repeating: .greatestFiniteMagnitude)
    boundingBoxMax = .init(repeating: -.greatestFiniteMagnitude)
    for atomID in topology.atoms.indices {
      // Exclude hydrogens from the search.
      let atom = topology.atoms[atomID]
      guard atom.atomicNumber != 1 else {
        continue
      }
      boundingBoxMin.replace(
        with: atom.position, where: atom.position .< boundingBoxMin)
      boundingBoxMax.replace(
        with: atom.position, where: atom.position .> boundingBoxMax)
    }
    
    // Define the points where markers ought to be placed.
    var targetPoints: [SIMD3<Float>] = []
    targetPoints.append(
      SIMD3(boundingBoxMin.x, boundingBoxMin.y, boundingBoxMax.z))
    targetPoints.append(
      SIMD3(boundingBoxMax.x, boundingBoxMin.y, boundingBoxMax.z))
    targetPoints.append(
      SIMD3(boundingBoxMin.x, boundingBoxMax.y, boundingBoxMax.z))
    targetPoints.append(
      SIMD3(boundingBoxMax.x, boundingBoxMax.y, boundingBoxMax.z))
    
    let center = (boundingBoxMin + boundingBoxMax) / 2
    targetPoints.append(SIMD3(center.x, center.y, boundingBoxMax.z))
    
    // Identity the closest atom to each target point.
    var candidateDistances = [Float](
      repeating: .greatestFiniteMagnitude, count: targetPoints.count)
    var candidateIndices = [UInt32](repeating: .max, count: targetPoints.count)
    for atomID in topology.atoms.indices {
      // Exclude hydrogens from the search.
      let atom = topology.atoms[atomID]
      guard atom.atomicNumber != 1 else {
        continue
      }
      
      // Loop over the array of target points.
      for targetPointID in targetPoints.indices {
        let targetPoint = targetPoints[targetPointID]
        let delta = atom.position - targetPoint
        
        let distance = (delta * delta).sum().squareRoot()
        let candidateDistance = candidateDistances[targetPointID]
        if distance < candidateDistance {
          candidateDistances[targetPointID] = distance
          candidateIndices[targetPointID] = UInt32(atomID)
        }
      }
    }
    
    // Store the marker indices to an instance property.
    markerAtomIndices = candidateIndices
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
    
    // Sort the topology for better simulation performance.
    topology.sort()
  }
  
  func createDistanceMatrix() -> [Float] {
    let markerCount = markerAtomIndices.count
    var distanceMatrix = [Float](
      repeating: -1, count: markerCount * markerCount)
    
    // Iterate over the markers in an O(n^2) loop.
    for lhsIDIndex in markerAtomIndices.indices {
      for rhsIDIndex in markerAtomIndices.indices {
        let lhsID = markerAtomIndices[lhsIDIndex]
        let rhsID = markerAtomIndices[rhsIDIndex]
        
        // Compute the distance between two atoms.
        let lhsAtom = topology.atoms[Int(lhsID)]
        let rhsAtom = topology.atoms[Int(rhsID)]
        let delta = lhsAtom.position - rhsAtom.position
        let distance = (delta * delta).sum().squareRoot()
        
        // Store the distance to the matrix.
        let address = lhsIDIndex * markerCount + rhsIDIndex
        distanceMatrix[address] = distance
      }
    }
    
    // Return the completed matrix.
    return distanceMatrix
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
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = parameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    
    // Minimize the atoms.
    forceField.positions = topology.atoms.map(\.position)
    forceField.minimize()
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position = forceField.positions[atomID]
      topology.atoms[atomID] = atom
    }
  }
}
