//
//  CBNTripod.swift
//  HDLTests
//
//  Created by Philip Turner on 12/29/23.
//

import Foundation
import HDL
import Numerics
import QuaternionModule

// This data structure holds objects wrapping the individual components. At the
// end, it stitches them all together into one topology. The data structure
// establishes a practice of creating functions for exporting [Entity], similar
// to the convention from the nanofactory animation. However, there is also an
// alternative way to acquire the final geometry: a Topology.
//
// There should be different functions that change the topology in different
// ways, or export different structures. One might replace the silicons
// attached to the NH groups with hydrogens, so the tripod can be simulated as
// a standalone structure.
struct CBNTripod {
  var cage: CBNTripodCage
  var legs: [CBNTripodLeg] = []
  
  // Indices of the atoms corresponding to each cage-leg bond.
  var cagePivotIDs: [Int] = []
  var legPivotIDs: [Int] = []
  
  // Indices of the atoms corresponding to each surface-leg bond.
  var legSiliconIDs: [Int] = []
  var legNitrogenIDs: [Int] = []
  
  init() {
    self.cage = CBNTripodCage()
    
    let leg = CBNTripodLeg()
    for legID in 0..<3 {
      var output = leg
      let angleDegrees1 = Float(90)
      let angleDegrees2 = Float(legID) / 3 * 360
      let rotation1 = Quaternion<Float>(
        angle: angleDegrees1 * .pi / 180, axis: [0, 1, 0])
      let rotation2 = Quaternion<Float>(
        angle: angleDegrees2 * .pi / 180, axis: [0, 1, 0])
      
      for i in output.topology.atoms.indices {
        var atom = output.topology.atoms[i]
        atom.position = rotation1.act(on: atom.position)
        atom.position += SIMD3(0, -0.62, 0.4)
        atom.position = rotation2.act(on: atom.position)
        output.topology.atoms[i] = atom
      }
      legs.append(output)
    }
    precondition(createAtoms().count == 75)
    
    attachLegs()
    precondition(createAtoms().count == 63)
  }
  
  // Add a function to irreversibly replace the silicon atoms with hydrogen
  // atoms. In practice, you might make a copy of the tripod data structure.
  // Mutate the copy, simulate it, and transfer data back to the original.
  
  func createAtoms() -> [Entity] {
    var output: [Entity] = []
    output += cage.topology.atoms
    for leg in legs {
      output += leg.topology.atoms
    }
    return output
  }
}

extension CBNTripod {
  private mutating func attachLegs() {
    // Connect the legs to the cage and delete their methyl carbons.
    var carbonylCarbonIDs: [UInt32] = []
    var cageCarbonIDs: [UInt32] = []
    for legID in legs.indices {
      var topology = legs[legID].topology
      let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
      
      var methylCarbonID: Int = -1
      var benzeneCarbonID: Int = -1
      for i in topology.atoms.indices {
        let atom = topology.atoms[i]
        let neighbors = atomsToAtomsMap[i]
        if atom.atomicNumber == 6 && neighbors.count == 1 {
          methylCarbonID = i
          benzeneCarbonID = Int(neighbors.first!)
          break
        }
      }
      precondition(methylCarbonID >= 0)
      precondition(benzeneCarbonID >= 0)
      
      var methylCarbon = topology.atoms[methylCarbonID]
      var benzeneCarbon = topology.atoms[benzeneCarbonID]
      let matches = cage.topology.match(
        [methylCarbon, benzeneCarbon], algorithm: .absoluteRadius(0.020))
      
      // Snap the leg into position on the adamantane cage.
      let cageCarbonID = Int(matches[0].first!)
      let cageCarbon = cage.topology.atoms[cageCarbonID]
      let translation = cageCarbon.position - methylCarbon.position
      for i in topology.atoms.indices {
        var atom = topology.atoms[i]
        atom.position += translation
        topology.atoms[i] = atom
      }
      
      // Update the methyl and benzene carbons with their new positions.
      methylCarbon = topology.atoms[methylCarbonID]
      benzeneCarbon = topology.atoms[benzeneCarbonID]
      
      // Fetch the carbonyl carbon and append the IDs to the list.
      let carbonylCarbonID = Int(matches[1].first!)
      let carbonylCarbon = cage.topology.atoms[carbonylCarbonID]
      carbonylCarbonIDs.append(UInt32(carbonylCarbonID))
      cageCarbonIDs.append(UInt32(cageCarbonID))
      
      // Rotate the leg down and under, so its open orbital aligns with the
      // carbonyl group's sp2 C - sp3 C orbital.
      var orbitalCage = carbonylCarbon.position - cageCarbon.position
      var orbitalLeg = benzeneCarbon.position - methylCarbon.position
      orbitalCage /= (orbitalCage * orbitalCage).sum().squareRoot()
      orbitalLeg /= (orbitalLeg * orbitalLeg).sum().squareRoot()
      
      // ~0.27-0.28° rotation for all 3 legs.
      let rotation = Quaternion<Float>(from: orbitalLeg, to: orbitalCage)
      for i in topology.atoms.indices {
        if i == methylCarbonID {
          continue
        }
        var atom = topology.atoms[i]
        var delta = atom.position - methylCarbon.position
        delta = rotation.act(on: delta)
        atom.position = methylCarbon.position + delta
        topology.atoms[i] = atom
      }
      
      // Replace the benzene carbon with a germanium marker that survives the
      // atom removal.
      topology.atoms[benzeneCarbonID].atomicNumber = 32
      topology.remove(atoms: [UInt32(methylCarbonID)])
      
      var nitrogenID: Int = -1
      var siliconID: Int = -1
      var germaniumID: Int = -1
      for i in topology.atoms.indices {
        switch topology.atoms[i].atomicNumber {
        case 7: nitrogenID = i
        case 14: siliconID = i
        case 32: germaniumID = i
        default: break
        }
      }
      precondition(nitrogenID >= 0)
      precondition(siliconID >= 0)
      precondition(germaniumID >= 0)
      topology.atoms[germaniumID].atomicNumber = 6
      
      // Update the leg's topology and initialize its pivot ID.
      legs[legID].topology = topology
      self.legNitrogenIDs.append(nitrogenID)
      self.legSiliconIDs.append(siliconID)
      self.legPivotIDs.append(germaniumID)
    }
    
    // Delete the carbonyl groups from the adamantane cage.
    do {
      precondition(carbonylCarbonIDs.count == 3)
      precondition(cageCarbonIDs.count == 3)
      var topology = cage.topology
      let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
      
      // Replace the cage carbons with silicon markers while they are removed.
      // Since the order of the atoms does not change, they still correspond to
      // the same atoms, even after the indices contract.
      var removedAtoms: [UInt32] = []
      for legID in 0..<3 {
        let carbonylCarbonID = Int(carbonylCarbonIDs[legID])
        let cageCarbonID = Int(cageCarbonIDs[legID])
        topology.atoms[cageCarbonID].atomicNumber = 14
        
        let atom = topology.atoms[carbonylCarbonID]
        precondition(atom.atomicNumber == 6)
        
        let neighbors = atomsToAtomsMap[carbonylCarbonID]
        for neighborID in neighbors {
          let neighbor = topology.atoms[Int(neighborID)]
          if neighbor.atomicNumber == 14 {
            continue
          }
          if neighbor.atomicNumber == 6 {
            fatalError("This should never happen.")
          }
          removedAtoms.append(neighborID)
        }
        removedAtoms.append(UInt32(carbonylCarbonID))
      }
      
      // Initialize the cage's pivot IDs.
      topology.remove(atoms: removedAtoms)
      for i in topology.atoms.indices {
        guard topology.atoms[i].atomicNumber == 14 else {
          continue
        }
        topology.atoms[i].atomicNumber = 6
        cagePivotIDs.append(i)
      }
      precondition(cagePivotIDs.count == 3)
      
      // Update the cage's topology.
      cage.topology = topology
    }
  }
  
  // It looks like this function has a bug. When it adjusts the silicon
  // positions in an already energy-minimized leg, it doesn't preserve the
  // sp2 orbital shape and alignment with the carbon atom. It's not a major
  // issue, because the resulting orbital looks like sp3. This might be the
  // required hybridization for the structure to be stable when binding to
  // silicon.
  mutating func rotateLegs(
    slantAngleDegrees: Float,
    swingAngleDegrees: Float
  ) {
    // Rotate the legs.
    for legID in 0..<3 {
      var topology = legs[legID].topology
      
      let cagePivotID = cagePivotIDs[legID]
      let legPivotID = legPivotIDs[legID]
      let cagePivot = cage.topology.atoms[cagePivotID]
      let legPivot = topology.atoms[legPivotID]
      var orbital = legPivot.position - cagePivot.position
      orbital /= (orbital * orbital).sum().squareRoot()
      
      func cross<T: Real & SIMDScalar>(
        _ x: SIMD3<T>, _ y: SIMD3<T>
      ) -> SIMD3<T> {
        // Source: https://en.wikipedia.org/wiki/Cross_product#Computing
        let s1 = x[1] * y[2] - x[2] * y[1]
        let s2 = x[2] * y[0] - x[0] * y[2]
        let s3 = x[0] * y[1] - x[1] * y[0]
        return SIMD3(s1, s2, s3)
      }
      let swingPerp = cross(SIMD3<Float>(0, 1, 0), -orbital)
      var swingAxis = cross(-orbital, swingPerp)
      swingAxis /= (swingAxis * swingAxis).sum().squareRoot()
      
      let slantRotation = Quaternion<Float>(
        angle: -slantAngleDegrees * .pi / 180, axis: orbital)
      let swingRotation = Quaternion<Float>(
        angle: swingAngleDegrees * .pi / 180, axis: swingAxis)
      
      for i in topology.atoms.indices {
        if i == legPivotID {
          continue
        }
        var atom = topology.atoms[i]
        var delta = atom.position - legPivot.position
        delta = slantRotation.act(on: delta)
        delta = swingRotation.act(on: delta)
        atom.position = legPivot.position + delta
        topology.atoms[i] = atom
      }
      
      legs[legID].topology = topology
    }
    
    // Straighten the NH groups so the bond to silicon is as close to vertical
    // as possible.
    for legID in 0..<3 {
      var topology = legs[legID].topology
      
      let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
      var hydrogenID: Int = -1
      var carbonID: Int = -1
      let nitrogenID = legNitrogenIDs[legID]
      let siliconID = legSiliconIDs[legID]
      
      let neighbors = atomsToAtomsMap[nitrogenID]
      for neighborID in neighbors {
        let atom = topology.atoms[Int(neighborID)]
        switch atom.atomicNumber {
        case 1: hydrogenID = Int(neighborID)
        case 6: carbonID = Int(neighborID)
        case 14: break
        default: fatalError("This should never happen.")
        }
      }
      
      var hydrogen = topology.atoms[Int(hydrogenID)]
      let carbon = topology.atoms[Int(carbonID)]
      let nitrogen = topology.atoms[Int(nitrogenID)]
      var silicon = topology.atoms[Int(siliconID)]
      var nitrogenOrbital = nitrogen.position - carbon.position
      nitrogenOrbital /=
      (nitrogenOrbital * nitrogenOrbital).sum().squareRoot()
      
      func evaluateDotProduct(_ angleDegrees: Float)  -> Float {
        let rotation = Quaternion<Float>(
          angle: angleDegrees * .pi / 180, axis: nitrogenOrbital)
        var siliconDelta = silicon.position - nitrogen.position
        siliconDelta = rotation.act(on: siliconDelta)
        siliconDelta /= (siliconDelta * siliconDelta).sum().squareRoot()
        
        let desiredOrbital = SIMD3<Float>(0, -1, 0)
        return (siliconDelta * desiredOrbital).sum()
      }
      
//      print()
      var angleDegrees: Float = 0
      for resolution in [Float(10), 3, 1, 0.3, 0.1] {
        var trials: Int = 0
        while true {
          let center = evaluateDotProduct(angleDegrees)
          let left = evaluateDotProduct(angleDegrees - resolution)
          let right = evaluateDotProduct(angleDegrees + resolution)
//          print(resolution, "-", left, center, right, "-", angleDegrees)
          
          if left == center && center == right {
            break
          } else if center > left, center > right {
            break
          } else if left > right {
            angleDegrees -= resolution
          } else if right > left {
            angleDegrees += resolution
          } else {
            fatalError("Unexpected situation.")
          }
          
          trials += 1
          if trials >= 10 {
            break
          }
        }
      }
      
      let rotation = Quaternion<Float>(
        angle: angleDegrees * .pi / 180, axis: nitrogenOrbital)
      
      var hydrogenDelta = hydrogen.position - nitrogen.position
      hydrogenDelta = rotation.act(on: hydrogenDelta)
      hydrogen.position = nitrogen.position + hydrogenDelta
      
      var siliconDelta = silicon.position - nitrogen.position
      siliconDelta = rotation.act(on: siliconDelta)
      silicon.position = nitrogen.position + siliconDelta
      
      topology.atoms[Int(hydrogenID)] = hydrogen
      topology.atoms[Int(siliconID)] = silicon
      legs[legID].topology = topology
    }
  }
  
  mutating func passivateNHGroups(_ element: Element) {
    // From 'CBNTripodLeg.compilationPass3()':
    let nhBondLength: Float = 1.0088 / 10 // xTB
    let nSiBondLength: Float = 1.7450 / 10 // xTB
    
    for legID in 0..<3 {
      var topology = legs[legID].topology
      let nitrogenID = legNitrogenIDs[legID]
      let siliconID = legSiliconIDs[legID]
      
      let nitrogen = topology.atoms[Int(nitrogenID)]
      var silicon = topology.atoms[Int(siliconID)]
      
      var nSiDelta = silicon.position - nitrogen.position
      nSiDelta /= (nSiDelta * nSiDelta).sum().squareRoot()
      switch element {
      case .hydrogen:
        silicon.position = nitrogen.position + nSiDelta * nhBondLength
        silicon.atomicNumber = 1
      case .silicon:
        silicon.position = nitrogen.position + nSiDelta * nSiBondLength
        silicon.atomicNumber = 14
      default:
        fatalError("Unexpected element.")
      }
      
      topology.atoms[siliconID] = silicon
      legs[legID].topology = topology
    }
  }
}
