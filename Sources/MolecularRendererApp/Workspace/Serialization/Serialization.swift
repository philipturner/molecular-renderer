//
//  Serialization.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/12/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Serialization {
  // Recover the bond topology after serializing the atom positions.
  //
  // WARNING: The search algorithm is fixed at '.covalentBondLength(1.4)'.
  static func reconstructBonds(
    topology: inout Topology,
    quaternaryAtomIDs: [UInt8]
  ) {
    let matches = topology.match(
      topology.atoms, algorithm: .covalentBondLength(1.4))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let matchCount = matches[atomID].count - 1
      if atom.atomicNumber == 1 {
        if matchCount != 1 {
          fatalError("Unexpected bond count.")
        }
      }
      if quaternaryAtomIDs.contains(atom.atomicNumber) {
        if matchCount != 4 {
          print("Unexpected bond count.")
        }
      }
      
      for neighborID in matches[atomID] where atomID < neighborID {
        let bond = SIMD2(UInt32(atomID), UInt32(neighborID))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
  }
  
  // Stores the raw data as a base-64 string.
  //
  // Compresses the information to within a factor of ~2x of the
  // information-theoretic limit.
  static func serialize(atoms: [Entity]) -> String {
    var rawData: [SIMD4<UInt16>] = []
    
    var header: SIMD4<UInt16> = .zero
    header[0] = UInt16(atoms.count % 65536)
    header[1] = UInt16(atoms.count / 65536)
    rawData.append(header)
    
    for atom in atoms {
      // Quantize the position to ~1 picometer precision.
      var position = atom.position
      position *= 1024
      position += 32768
      position.round(.toNearestOrEven)
      
      // Check that every atom falls within the bounds: 0 ≤ r < 64 nm.
      if any(position .< 0) || any(position .>= 65536) {
        fatalError("Position was out of range.")
      }
      
      let chunk = SIMD4(
        SIMD3<UInt16>(position), UInt16(atom.atomicNumber))
      rawData.append(chunk)
    }
    
    let data = Data(bytes: rawData, count: rawData.count * 8)
    return data.base64EncodedString(options: .lineLength76Characters)
  }
  
  // Retrieves the raw data from a base-64 string.
  static func deserialize(string: String) -> [Entity] {
    let data = Data(
      base64Encoded: string, options: .ignoreUnknownCharacters)
    guard let data else {
      fatalError("Could not decode base64-encoded string.")
    }
    guard data.count % 8 == 0 else {
      fatalError("Data was not aligned to 8 bytes.")
    }
    
    var rawData = [SIMD4<UInt16>](repeating: .zero, count: data.count / 8)
    rawData.withUnsafeMutableBytes {
      let copiedCount = data.copyBytes(to: $0)
      guard copiedCount == data.count else {
        fatalError("Incorrect number of bytes was copied.")
      }
    }
    
    let header = rawData[0]
    let atomCount = UInt32(header[0]) + 65536 * UInt32(header[1])
    guard atomCount == rawData.count - 1 else {
      fatalError("Atom count was incorrect.")
    }
    
    var atoms: [Entity] = []
    for chunk in rawData[1...] {
      var position = SIMD3<Float>(
        unsafeBitCast(chunk, to: SIMD3<UInt16>.self))
      position -= 32768
      position /= 1024
      
      let atomicNumber = UInt8(chunk[3])
      guard let element = Element(rawValue: atomicNumber) else {
        fatalError("Unrecognized atomic number.")
      }
      let entity = Entity(position: position, type: .atom(element))
      atoms.append(entity)
    }
    return atoms
  }
}
