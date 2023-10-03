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
  internal enum CarbonType {
    case heteroatom(UInt8)
    case methane
    case primary
    case secondary
    case tertiary
    case quaternary
  }
  
  internal func createCarbonTypes(
    atomicNumbers: [UInt8],
    bondsToAtomsMap: UnsafeMutablePointer<SIMD2<Int32>>,
    atomsToBondsMap: UnsafeMutablePointer<SIMD4<Int32>>
  ) -> [CarbonType] {
    var output: [CarbonType] = []
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
      var matchMask: SIMD4<UInt8> = .zero
      matchMask.replace(with: .one, where: otherElements .== 6)
      
      var carbonType: CarbonType
      switch matchMask.wrappedSum() {
      case 4:
        carbonType = .quaternary
      case 3:
        carbonType = .tertiary
      case 2:
        carbonType = .secondary
      case 1:
        carbonType = .primary
      case 0:
        carbonType = .methane
      default:
        fatalError("This should never happen.")
      }
      output.append(carbonType)
    }
    return output
  }
  
  internal func createBondParameters(
    atomTypes: [MM4AtomType],
    bondCount: Int,
    bondsToAtomsMap: UnsafeMutablePointer<SIMD2<Int32>>,
    carbonTypes: [CarbonType]
  ) -> [MM4BondParameters] {
    var output: [MM4BondParameters] = []
    for bondID in 0..<bondCount {
      let bond = bondsToAtomsMap[bondID]
      var types: SIMD2<UInt8> = .zero
      for lane in 0..<2 {
        let atomID = bond[lane]
        types[lane] = atomTypes[Int(atomID)].rawValue
      }
      let minAtomType = types.min()
      let maxAtomType = types.max()
      let minAtomID = (types[0] == minAtomType) ? bond[0] : bond[1]
      let maxAtomID = (types[1] == maxAtomType) ? bond[1] : bond[0]
      
      // TODO: Dipole flips in either direction, depending on the order the
      // carbon and fluorine are addressed in.
      var potentialWellDepth: Float
      var stretchingStiffness: Float
      var equilibriumLength: Float
      var dipoleMoment: Float = 0
      
      switch (minAtomType, maxAtomType) {
      case (1, 1):
        potentialWellDepth = 1.130
        stretchingStiffness = 4.5500
        equilibriumLength = 1.5270
      case (1, 5):
        potentialWellDepth = 0.854
        equilibriumLength = 1.1120
        
        let carbonType = carbonTypes[Int(minAtomID)]
        switch carbonType {
        case .tertiary:
          stretchingStiffness = 4.7400
        case .secondary:
          stretchingStiffness = 4.6700
        case .primary:
          stretchingStiffness = 4.7400
        case .methane:
          stretchingStiffness = 4.9000
          equilibriumLength = 1.1070
        default:
          fatalError("Unrecognized carbon type.")
        }
      default:
        fatalError("Not implemented.")
      }
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
      default:
        fatalError("Atomic number \(atomicNumber) not recognized.")
      }
      output.append(MM4NonbondedParameters(epsilon: epsilon, radius: radius))
    }
    return output
  }
}
