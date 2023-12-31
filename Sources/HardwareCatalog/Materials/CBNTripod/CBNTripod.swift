//
//  CBNTripod.swift
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

extension CBNTripod {
  /*
   tripod.rotateLegs(slantAngleDegrees: 5, swingAngleDegrees: 0)
   tripod.passivateNHGroups(.hydrogen)
   
   -------------------------------------------------
  | TOTAL ENERGY             -125.933557622227 Eh   |
  | GRADIENT NORM               0.000591510435 Eh/α |
  | HOMO-LUMO GAP               3.107226292213 eV   |
   -------------------------------------------------
   */
  static let xtbOptimizedStructure1: [Entity] = [
    Entity(position: SIMD3( 0.0001, -0.2330, -0.1473), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1275, -0.2330,  0.0735), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1275, -0.2330,  0.0736), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0000, -0.1935,  0.1512), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0000, -0.0427,  0.1778), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1311, -0.1934, -0.0756), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1540, -0.0425, -0.0890), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1310, -0.1935, -0.0757), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1540, -0.0426, -0.0890), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0000,  0.0420,  0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3( 0.0003, -0.3403, -0.1618), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0001, -0.1867, -0.2464), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2134, -0.1867,  0.1231), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1403, -0.3404,  0.0807), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1401, -0.3403,  0.0810), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2134, -0.1867,  0.1232), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0883, -0.0134,  0.2344), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0879, -0.0134,  0.2350), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1589, -0.0132, -0.1937), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2475, -0.0132, -0.0414), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2472, -0.0133, -0.0408), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1596, -0.0133, -0.1937), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000,  0.2352,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0000,  0.3550, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0111, -0.6310,  0.3850), type: .atom(.nitrogen)),
    Entity(position: SIMD3(-0.0020, -0.4949,  0.3960), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0004, -0.4302,  0.5195), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0022, -0.5054,  0.6319), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.0019, -0.4817,  0.1663), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.0000, -0.2727,  0.2835), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0016, -0.4124,  0.2830), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0024, -0.2933,  0.5279), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0017, -0.2174,  0.4119), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0033, -0.0843,  0.4342), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.0044, -0.2438,  0.6236), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0110, -0.6715,  0.2955), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0125, -0.6850,  0.4665), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3390, -0.6310, -0.1829), type: .atom(.nitrogen)),
    Entity(position: SIMD3( 0.3440, -0.4949, -0.1963), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.4497, -0.4302, -0.2601), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.5462, -0.5054, -0.3178), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.1451, -0.4816, -0.0816), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.2456, -0.2726, -0.1417), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2459, -0.4123, -0.1402), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.4561, -0.2933, -0.2660), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3559, -0.2173, -0.2074), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3745, -0.0842, -0.2200), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.5379, -0.2438, -0.3156), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2505, -0.6714, -0.1573), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3978, -0.6850, -0.2441), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3280, -0.6310, -0.2019), type: .atom(.nitrogen)),
    Entity(position: SIMD3(-0.3420, -0.4949, -0.1996), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4502, -0.4302, -0.2592), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5485, -0.5054, -0.3138), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.1431, -0.4816, -0.0848), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.2455, -0.2726, -0.1418), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2443, -0.4123, -0.1428), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4584, -0.2933, -0.2619), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3576, -0.2174, -0.2045), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3777, -0.0842, -0.2144), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.5423, -0.2438, -0.3079), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2616, -0.6714, -0.1380), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4104, -0.6850, -0.2222), type: .atom(.hydrogen)),
  ]
  
  /*
   tripod.rotateLegs(slantAngleDegrees: 62, swingAngleDegrees: 5)
   tripod.passivateNHGroups(.hydrogen)
   
   -------------------------------------------------
  | TOTAL ENERGY             -125.942547079100 Eh   |
  | GRADIENT NORM               0.000397306008 Eh/α |
  | HOMO-LUMO GAP               3.175291378364 eV   |
   -------------------------------------------------
   */
  static let xtbOptimizedStructure2: [Entity] = [
    Entity(position: SIMD3( 0.0027, -0.2608, -0.1439), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1260, -0.2607,  0.0696), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1233, -0.2607,  0.0743), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0032, -0.2166,  0.1503), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0095, -0.0653,  0.1776), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1318, -0.2166, -0.0723), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1586, -0.0653, -0.0806), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1285, -0.2166, -0.0779), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1491, -0.0653, -0.0970), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0000,  0.0203, -0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3( 0.0055, -0.3700, -0.1462), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0031, -0.2241, -0.2462), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2148, -0.2240,  0.1204), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1294, -0.3700,  0.0683), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1238, -0.3699,  0.0779), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2117, -0.2240,  0.1258), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0731, -0.0330,  0.2405), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1020, -0.0418,  0.2303), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1717, -0.0330, -0.1836), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2505, -0.0418, -0.0268), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2448, -0.0330, -0.0570), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1485, -0.0418, -0.2035), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000,  0.2136, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0000,  0.3334, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1943, -0.4982,  0.5202), type: .atom(.nitrogen)),
    Entity(position: SIMD3(-0.0905, -0.4243,  0.4710), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0240, -0.3986,  0.5463), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0351, -0.4558,  0.6684), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.2109, -0.3969,  0.2771), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.0014, -0.2836,  0.2885), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0968, -0.3652,  0.3437), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1242, -0.3174,  0.4988), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1108, -0.2614,  0.3733), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2123, -0.1802,  0.3358), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.2118, -0.2969,  0.5580), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2644, -0.5300,  0.4556), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1767, -0.5547,  0.6014), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5476, -0.4982, -0.0919), type: .atom(.nitrogen)),
    Entity(position: SIMD3( 0.4532, -0.4243, -0.1572), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.4611, -0.3986, -0.2939), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.5613, -0.4558, -0.3646), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.3454, -0.3969,  0.0441), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.2492, -0.2836, -0.1455), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3461, -0.3653, -0.0880), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3699, -0.3174, -0.3570), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2679, -0.2614, -0.2826), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1846, -0.1803, -0.3517), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.3774, -0.2969, -0.4624), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5268, -0.5300,  0.0011), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.6092, -0.5547, -0.1477), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3534, -0.4983, -0.4283), type: .atom(.nitrogen)),
    Entity(position: SIMD3(-0.3627, -0.4243, -0.3139), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4851, -0.3986, -0.2524), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5964, -0.4558, -0.3038), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.1345, -0.3970, -0.3212), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.2506, -0.2836, -0.1431), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2493, -0.3653, -0.2557), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4941, -0.3174, -0.1419), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3787, -0.2614, -0.0907), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3969, -0.1802,  0.0160), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.5892, -0.2969, -0.0956), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2624, -0.5301, -0.4568), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4325, -0.5547, -0.4537), type: .atom(.hydrogen)),
  ]
}
