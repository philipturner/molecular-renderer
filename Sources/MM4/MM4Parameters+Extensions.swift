//
//  MM4Parameters+Extensions.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/2/23.
//

import Foundation

extension MM4Parameters {
  @inline(__always)
  internal func other<T: FixedWidthInteger, U: FixedWidthInteger>(
    atomID: T, bondID: U, bondsToAtomsMap: UnsafeMutablePointer<SIMD2<Int32>>
  ) -> Int32 {
    let bond = bondsToAtomsMap[Int(bondID)]
    return (bond[0] == atomID) ? bond[1] : bond[0]
  }
}

extension MM4Parameters {
  internal func createCenterTypes(
    atomicNumbers: [UInt8],
    bondsToAtomsMap: UnsafeMutablePointer<SIMD2<Int32>>,
    atomsToBondsMap: UnsafeMutablePointer<SIMD4<Int32>>
  ) -> [MM4CenterType] {
    var output: [MM4CenterType] = []
    for atomID in atomicNumbers.indices {
      let atomicNumber = atomicNumbers[atomID]
      guard atomicNumber == 6 else {
        precondition(
          atomicNumber == 1 || atomicNumber == 9,
          "Atomic number \(atomicNumber) not recognized.")
        output.append(.heteroatom(atomicNumber))
        continue
      }
      
      let map = atomsToBondsMap[atomID]
      var otherIDs: SIMD4<Int32> = .zero
      for lane in 0..<4 {
        let bondID = map[lane]
        otherIDs[lane] = other(
          atomID: atomID, bondID: map[lane], bondsToAtomsMap: bondsToAtomsMap)
      }
      guard all(otherIDs .>= 1) else {
        fatalError("A carbon did not have 4 valid bonds.")
      }
      var otherElements: SIMD4<UInt8> = .zero
      for lane in 0..<4 {
        let otherID = otherIDs[lane]
        otherElements[lane] = atomicNumbers[Int(otherID)]
      }
      
      // In MM4, fluorine is treated like carbon when determining carbon types.
      // Allinger notes this may be a weakness of the forcefield.
      var matchMask: SIMD4<UInt8> = .zero
      matchMask.replace(with: .one, where: otherElements .!= 1)
      
      var carbonType: MM4CenterType
      switch matchMask.wrappedSum() {
      case 4:
        carbonType = .quaternary
      case 3:
        carbonType = .tertiary
      case 2:
        carbonType = .secondary
      case 1:
        carbonType = .primary
      default:
        fatalError("This should never happen.")
      }
      output.append(carbonType)
    }
    return output
  }
  
  internal func createNonbondedParameters(
    atomicNumbers: [UInt8],
    hydrogenMassRepartitioning: Double
  ) -> [MM4NonbondedParameters] {
    var output: [MM4NonbondedParameters] = []
    for atomID in atomicNumbers.indices {
      let atomicNumber = atomicNumbers[atomID]
      var epsilon: (heteroatom: Float, hydrogen: Float)
      var radius: (heteroatom: Float, hydrogen: Float)
      
      switch atomicNumber {
      case 1:
        epsilon = (heteroatom: 0.017, hydrogen: 0.017)
        radius = (heteroatom: 1.960, hydrogen: 1.960)
      case 6:
        let t = Float(hydrogenMassRepartitioning) - 0
        let hydrogenRadius = t * (3.410 - 3.440) + 3.440
        epsilon = (heteroatom: 0.037, hydrogen: 0.024)
        radius = (heteroatom: 1.960, hydrogen: hydrogenRadius)
      case 9:
        // Change vdW force to emulate polarization of a nearby C-H bond.
        epsilon = (heteroatom: 0.075, hydrogen: 0.092 * pow(1 / 0.9, 6))
        radius = (heteroatom: 1.710, hydrogen: 2.870 * 0.9)
      case 14:
        // Scale silicon-hydrogen vdW parameters by 0.94, as suggested for MM4.
        epsilon = (heteroatom: 0.140, hydrogen: 0.046)
        radius = (heteroatom: 2.290, hydrogen: 3.690)
      default:
        fatalError("Atomic number \(atomicNumber) not recognized.")
      }
      output.append(MM4NonbondedParameters(epsilon: epsilon, radius: radius))
    }
    return output
  }
  
  internal func createBondParameters(
    atomTypes: [MM4AtomType],
    bondCount: Int,
    bondsToAtomsMap: UnsafeMutablePointer<SIMD2<Int32>>,
    centerTypes: [MM4CenterType],
    ringTypes: [UInt8]
  ) -> [(
    MM4BondParameters, MM4HeteroatomBondParameters?
  )] {
    var output: [(MM4BondParameters, MM4HeteroatomBondParameters?)] = []
    for bondID in 0..<bondCount {
      let bond = bondsToAtomsMap[bondID]
      var types: SIMD2<UInt8> = .zero
      var rings: SIMD2<UInt8> = .zero
      for lane in 0..<2 {
        let atomID = bond[lane]
        types[lane] = atomTypes[Int(atomID)].rawValue
        rings[lane] = ringTypes[Int(atomID)]
      }
      if any(types .!= 11 .| types .== 19) {
        types.replace(with: .init(repeating: 1), where: types .== 123)
      }
      let minAtomType = types.min()
      let maxAtomType = types.max()
      let minAtomID = (types[0] == minAtomType) ? bond[0] : bond[1]
      let maxAtomID = (types[1] == maxAtomType) ? bond[1] : bond[0]
      
      // TODO: Don't erroneously classify a bond or angle from two separate
      // 5-membered rings as from the same ring. This requires some means to
      // record instances of 5-membered rings, likely by querying all the
      // torsions where every atom is in a 5-membered ring. Then, mapping
      // backwards from the rings to bonds/angles that make them up.
      precondition(Bool.random(), "Implementation is incorrect right now.")
      
      let ringType = rings.max()
      
      var potentialWellDepth: Float
      var stretchingStiffness: Float
      var equilibriumLength: Float
      var dipoleMoment: Float?
      
      switch (minAtomType, maxAtomType) {
        // Carbon
      case (1, 1):
        potentialWellDepth = 1.130
        stretchingStiffness = 4.5500
        equilibriumLength = 1.5270
      case (1, 5):
        potentialWellDepth = 0.854
        equilibriumLength = 1.1120
        
        let centerType = centerTypes[Int(minAtomID)]
        switch centerType {
        case .tertiary:
          stretchingStiffness = 4.7400
        case .secondary:
          stretchingStiffness = 4.6700
        case .primary:
          stretchingStiffness = 4.7400
        default:
          fatalError("Unrecognized carbon type.")
        }
      case (5, 123):
        potentialWellDepth = 0.854
        equilibriumLength = 1.1120
        
        let centerType = centerTypes[Int(maxAtomID)]
        switch centerType {
        case .tertiary:
          stretchingStiffness = 4.7000
        case .secondary:
          stretchingStiffness = 4.6400
        default:
          fatalError("Unrecognized carbon type.")
        }
      case (1, 123):
        potentialWellDepth = 1.130
        stretchingStiffness = 4.5600
        equilibriumLength = 1.5270
      case (123, 123):
        potentialWellDepth = 1.130
        stretchingStiffness = 4.9900
        equilibriumLength = 1.5290
      
        // Fluorine
      case (1, 11):
        potentialWellDepth = 0.989
        stretchingStiffness = 6.10
        equilibriumLength = 1.3859
        dipoleMoment = (types[1] == 11) ? +1.82 : -1.82
        
        // Silicon
      case (1, 19):
        let dipoleMagnitude: Float = (ringType == 5) ? 0.70 : 0.55
        potentialWellDepth = 0.812
        stretchingStiffness = 3.05
        equilibriumLength = (ringType == 5) ? 1.884 : 1.876
        dipoleMoment = (types[1] == 19) ? -dipoleMagnitude : +dipoleMagnitude
      case (5, 19):
        potentialWellDepth = 0.777
        stretchingStiffness = 2.65
        equilibriumLength = 1.483
      case (19, 19):
        potentialWellDepth = 0.672
        stretchingStiffness = 1.65
        equilibriumLength = (ringType == 5) ? 2.336 : 2.322
      default:
        fatalError("Not recognized: (\(minAtomType), \(maxAtomType))")
      }
      
      let parameters = MM4BondParameters(
        potentialWellDepth: potentialWellDepth,
        stretchingStiffness: stretchingStiffness,
        equilibriumLength: equilibriumLength)
      if let dipoleMoment {
        output.append((
          parameters, MM4HeteroatomBondParameters(dipoleMoment: dipoleMoment)
        ))
      } else {
        output.append((
          parameters, nil
        ))
      }
    }
    return output
  }
  
  internal func createAngleParameters(
    angles: [SIMD3<Int32>],
    atomTypes: [MM4AtomType],
    centerTypes: [MM4CenterType]
  ) -> [(
    MM4AngleParameters, MM4HeteroatomAngleParameters?
  )] {
    var output: [(MM4AngleParameters, MM4HeteroatomAngleParameters?)] = []
    for angleID in angles.indices {
      let angle = angles[angleID]
      var types: SIMD3<UInt8> = .zero
      var rings: SIMD2<UInt8> = .zero
      for lane in 0..<3 {
        let atomID = angle[lane]
        types[lane] = atomTypes[Int(atomID)].rawValue
        rings[lane] = ringTypes[Int(atomID)]
      }
      if any(types .== 11 .| types .== 19) {
        types.replace(with: .init(repeating: 1), where: types .== 123)
      }
      let minAtomType = SIMD2(types[0], types[2]).min()
      let medAtomType = types[1]
      let maxAtomType = SIMD2(types[0], types[2]).max()
      let minAtomID = (types[0] == minAtomType) ? angle[0] : angle[2]
      let medAtomID = angle[1]
      let maxAtomID = (types[2] == maxAtomType) ? angle[2] : angle[0]
      let ringType = rings.max()
      
      var bendingStiffnesses: SIMD3<Float>
      var equilibriumAngles: SIMD3<Float>
      let baseCarbonAngles: SIMD3<Float> = SIMD3(108.900, 109.470, 110.800)
      
      switch (minAtomType, medAtomType, maxAtomType) {
        // Carbon
      case (1, 1, 1):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(109.500, 110.400, 111.800)
      case (1, 1, 5):
        bendingStiffnesses = SIMD3(0.590, 0.560, 0.600)
        equilibriumAngles = baseCarbonAngles
      case (5, 1, 5):
        bendingStiffnesses = SIMD3(repeating: 0.540)
        equilibriumAngles = SIMD3(107.700, 107.800, 107.700)
      case (1, 1, 123):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(109.500, 110.500, 111.800)
      case (1, 123, 5):
        bendingStiffnesses = SIMD3(repeating: 0.560)
        equilibriumAngles = baseCarbonAngles
      case (5, 1, 123):
        bendingStiffnesses = SIMD3(repeating: 0.560)
        equilibriumAngles = baseCarbonAngles
      case (5, 123, 5):
        bendingStiffnesses = SIMD3(repeating: 0.620)
        equilibriumAngles = SIMD3(107.800, 107.800, 0.000)
      case (1, 123, 123):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(109.500, 110.500, 111.800)
      case (5, 123, 123):
        bendingStiffnesses = SIMD3(repeating: 0.580)
        equilibriumAngles = baseCarbonAngles
      case (123, 123, 123):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(108.300, 108.900, 109.000)
        
        // Fluorine
      case (1, 1, 11):
        bendingStiffnesses = SIMD3(repeating: 0.92)
        equilibriumAngles = SIMD3(106.90, 108.20, 109.30)
      case (5, 1, 11):
        bendingStiffnesses = SIMD3(0.82, 0.88, 0.98)
        equilibriumAngles = SIMD3(107.95, 107.90, 108.55)
      case (11, 1, 11):
        bendingStiffnesses = SIMD3(1.95, 2.05, 1.62)
        equilibriumAngles = SIMD3(104.30, 105.90, 108.08)
        
        // Silicon
      case (1, 1, 19):
        if ringType == 6 {
          bendingStiffnesses = SIMD3(repeating: 0.400)
          equilibriumAngles = SIMD3(109.00, 112.70, 111.50)
        } else {
          bendingStiffnesses = SIMD3(repeating: 0.550)
          equilibriumAngles = SIMD3(repeating: 107.20)
        }
      case (5, 1, 19):
        bendingStiffnesses = SIMD3(repeating: 0.540)
        equilibriumAngles = SIMD3(109.50, 110.00, 108.90)
      case (1, 19, 1):
        if ringType == 6 {
          bendingStiffnesses = SIMD3(repeating: 0.480)
          equilibriumAngles = SIMD3(109.50, 110.40, 109.20)
        } else {
          bendingStiffnesses = SIMD3(repeating: 0.650)
          equilibriumAngles = SIMD3(102.80, 103.80, 99.50)
        }
      case (19, 1, 19):
        bendingStiffnesses = SIMD3(repeating: 0.350)
        equilibriumAngles = SIMD3(109.50, 119.50, 117.00)
      case (1, 19, 5):
        bendingStiffnesses = SIMD3(repeating: 0.400)
        equilibriumAngles = SIMD3(109.30, 107.00, 110.00)
      case (5, 19, 5):
        bendingStiffnesses = SIMD3(repeating: 0.460)
        equilibriumAngles = SIMD3(106.50, 108.70, 109.50)
      case (1, 19, 19):
        bendingStiffnesses = SIMD3(repeating: 0.450)
        equilibriumAngles = SIMD3(repeating: 109.00)
      case (5, 19, 19):
        bendingStiffnesses = SIMD3(repeating: 0.350)
        equilibriumAngles = SIMD3(repeating: 109.40)
      case (19, 19, 19):
        if ringType == 6 {
          bendingStiffnesses = SIMD3(repeating: 0.250)
          equilibriumAngles = SIMD3(118.00, 110.80, 111.20)
        } else {
          bendingStiffnesses = SIMD3(repeating: 0.320)
          equilibriumAngles = SIMD3(repeating: 106.00)
        }
      default:
        fatalError("Not recognized: (\(minAtomType), \(medAtomType), \(maxAtomType))")
      }
      
      // Factors in both the center type and the other atoms in the angle.
      var angleType: Int
      do {
        var matchMask: SIMD3<UInt8> = .zero
        matchMask.replace(with: .one, where: types .== 5)
        let numHydrogens = Int(matchMask.wrappedSum())
        
        let centerType = centerTypes[Int(medAtomID)]
        switch centerType {
        case .quaternary:
          angleType = 1 - numHydrogens
        case .tertiary:
          angleType = 2 - numHydrogens
        case .secondary:
          angleType = 3 - numHydrogens
        case .primary:
          angleType = 4 - numHydrogens
        default:
          fatalError("Unrecognized center type: \(centerType)")
        }
      }
      
      // Calculate bend-bend parameters using atomic number instead of MM4 type.
    }
    return output
  }
  
  // TODO: Create an entire separate file "MM4Parameters+Torsions" for torsions
  // and all the torsion-like forces. Keep the Electronegativity Effect and
  // Bohlmann Band corrections in MM4Parameters+Extensions.
}
