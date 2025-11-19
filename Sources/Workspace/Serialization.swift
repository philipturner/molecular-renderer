//
//  Serialization.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/12/24.
//

import Foundation
import HDL

struct Serialization {
  
}

// MARK: - Atoms

extension Serialization {
  // Generates a unique hash from a list of atoms.
  static func hash(atoms: [SIMD4<Float>]) -> Data {
    var xorHash: SIMD4<UInt32> = .zero
    var rotateHash: SIMD4<UInt32> = .one
    var floatSum: SIMD4<UInt32> = .zero
    
    for atom in atoms {
      let storageCasted = unsafeBitCast(atom, to: SIMD4<UInt32>.self)
      
      xorHash ^= storageCasted
      xorHash = (xorHash &<< 3) | (xorHash &>> (32 - 3))
      
      rotateHash &*= storageCasted
      rotateHash &+= 1
      rotateHash = (rotateHash &<< 9) | (rotateHash &>> (32 - 9))
      
      var quantized = atom
      quantized *= 1024
      quantized.round(.toNearestOrEven)
      floatSum &+= unsafeBitCast(quantized, to: SIMD4<UInt32>.self)
    }
    
    var data = Data()
    func addVector(_ vector: SIMD4<UInt32>) {
      let castedVector = unsafeBitCast(vector, to: SIMD16<UInt8>.self)
      for laneID in 0..<16 {
        let byte = castedVector[laneID]
        data.append(byte)
      }
    }
    addVector(xorHash)
    addVector(rotateHash)
    addVector(floatSum)
    return data
  }
  
  // Compresses a list of atoms into binary data.
  //
  // Segments the volume into 64x64x64 nm blocks. The block-sparse volume must
  // not exceed 67 million cubic nanometers.
  //
  // The compression is a factor of ~2x from the information-theoretic limit.
  static func serialize(atoms: [SIMD4<Float>]) -> Data {
    // Allocate a dictionary for the chunk indices.
    var chunkIDs: [SIMD3<UInt16>: UInt8] = [:]
    var chunkCount: UInt8 = .zero
    
    // Allocate an array for the compressed atoms.
    var compressedAtoms: [SIMD4<UInt16>] = []
    
    // Loop over the atoms.
    for atom in atoms {
      // Quantize the position to ~1 picometer precision.
      var position = atom.position
      position *= 1024
      position.round(.toNearestOrEven)
      
      // Convert to a 32-bit integer.
      let integerValue = SIMD3<Int32>(position)
      let bitPattern = SIMD3<UInt32>(truncatingIfNeeded: integerValue)
      
      // Search for a matching sector.
      let upperBits = SIMD3<UInt16>(truncatingIfNeeded: bitPattern &>> 16)
      var chunkID: UInt8
      if let matchingID = chunkIDs[upperBits] {
        chunkID = matchingID
      } else if chunkCount < UInt8.max {
        chunkIDs[upperBits] = chunkCount
        chunkID = chunkCount
        chunkCount += 1
      } else {
        fatalError("Exceeded available vocabulary of 256 chunks.")
      }
      
      // Encode the lower bits.
      let lowerBits = SIMD3<UInt16>(truncatingIfNeeded: bitPattern)
      
      // Pack the atomic number and chunk ID into 16 bits.
      let idPair = SIMD2<UInt8>(atom.atomicNumber, chunkID)
      
      // Create a 4-lane vector with the data.
      let vector = SIMD4(lowerBits, unsafeBitCast(idPair, to: UInt16.self))
      compressedAtoms.append(vector)
    }
    
    // Allocate an array for the output data.
    var output = [SIMD4<UInt16>](repeating: .zero, count: 257)
    
    // Create a header for the serialized data.
    let atomCount = UInt64(atoms.count)
    output[0] = unsafeBitCast(atomCount, to: SIMD4<UInt16>.self)
    
    // Encode the chunks.
    for (key, value) in chunkIDs {
      let vector = SIMD4(key, 0)
      output[Int(1 + value)] = vector
    }
    
    // Encode the atoms.
    output += compressedAtoms
    
    // Return the data for further processing in the caller.
    let byteCount = output.count * MemoryLayout<SIMD4<UInt16>>.stride
    return Data(bytes: output, count: byteCount)
  }
  
  static func deserialize(atoms: Data) -> [SIMD4<Float>] {
    let wordCount = atoms.count / MemoryLayout<SIMD4<UInt16>>.stride
    var rawData = [SIMD4<UInt16>](repeating: .zero, count: wordCount)
    rawData.withUnsafeMutableBytes {
      let copiedCount = atoms.copyBytes(to: $0)
      guard copiedCount == atoms.count else {
        fatalError("Incorrect number of bytes was copied.")
      }
    }
    
    // Read the header.
    let header = rawData[0]
    let atomCount = unsafeBitCast(header, to: UInt64.self)
    guard 1 + 256 + atomCount == wordCount else {
      fatalError("Atom count was incorrect.")
    }
    
    // Loop over the atoms.
    var output: [SIMD4<Float>] = []
    for atomID in 0..<atomCount {
      let vector = rawData[Int(257 + atomID)]
      
      // Decode the lower bits.
      let lowerBits = SIMD3(vector[0], vector[1], vector[2])
      
      // Decode the atomic number and chunk ID.
      let idPair = unsafeBitCast(vector[3], to: SIMD2<UInt8>.self)
      
      // Locate the matching sector.
      let chunkID = idPair[1]
      let chunkVector = rawData[Int(1) + Int(chunkID)]
      let upperBits = unsafeBitCast(chunkVector, to: SIMD3<UInt16>.self)
      
      // Convert to a 32-bit integer.
      var bitPattern: SIMD3<UInt32> = .zero
      bitPattern |= SIMD3(truncatingIfNeeded: lowerBits)
      bitPattern |= SIMD3(truncatingIfNeeded: upperBits) &<< 16
      let integerValue = SIMD3<Int32>(truncatingIfNeeded: bitPattern)
      
      // Dequantize the position, from picometers to nanometers.
      var position = SIMD3<Float>(integerValue)
      position /= 1024
      
      // Decode the atomic number and convert to an entity.
      let atomicNumber = UInt8(idPair[0])
      let atom = SIMD4(position, Float(atomicNumber))
      output.append(atom)
    }
    
    return output
  }
}

// MARK: - Bonds

extension Serialization {
  // Compresses a bond topology into binary data.
  //
  // The typical compression ratio is ~2.0x. This is close to the
  // information-theoretic limit of ~3.5x.
  static func serialize(bonds: [SIMD2<UInt32>]) -> Data {
    var lastAtomID: UInt32 = .zero
    
    // Sort the bonds into compressable and non-compressable groups.
    var compressedBonds: [SIMD2<UInt16>] = []
    var decompressedBonds: [SIMD2<UInt32>] = []
    for bond in bonds {
      // We rely on there always being an 8-compressed atom nearby.
      guard bond[0] >= lastAtomID,
            bond[0] - lastAtomID < 65536 else {
        print(compressedBonds.count, decompressedBonds.count, bonds.count)
        fatalError("Bond could not be compressed.")
      }
      guard bond[1] > bond[0] else {
        fatalError("Bond was not sorted.")
      }
      
      let difference = bond[1] - bond[0]
      if difference < 65536 {
        let startDelta = UInt16(bond[0] - lastAtomID)
        let lengthDelta = UInt16(bond[1] - bond[0])
        let compressedBond = SIMD2(startDelta, lengthDelta)
        compressedBonds.append(compressedBond)
        
        // Update the atom cursor.
        lastAtomID = bond[0]
      } else {
        // Do not update the atom cursor.
        decompressedBonds.append(bond)
      }
    }
    
    // Allocate an array for the raw data.
    var rawData: [SIMD2<UInt32>] = []
    
    // Write to the header.
    var header: SIMD2<UInt32> = .zero
    header[0] = UInt32(compressedBonds.count)
    header[1] = UInt32(decompressedBonds.count)
    rawData.append(header)
    
    // Pad the compressable bonds to a multiple of two.
    while compressedBonds.count % 2 != 0 {
      compressedBonds.append(SIMD2<UInt16>.zero)
    }
    
    // Write the compressable bonds.
    for groupID in 0..<compressedBonds.count / 2 {
      var vector: SIMD4<UInt16> = .zero
      for laneID in 0..<2 {
        let compressedBond = compressedBonds[groupID * 2 + laneID]
        vector[laneID * 2 + 0] = compressedBond[0]
        vector[laneID * 2 + 1] = compressedBond[1]
      }
      let castedVector = unsafeBitCast(vector, to: SIMD2<UInt32>.self)
      rawData.append(castedVector)
    }
    
    // Write the non-compressable bonds.
    rawData.append(contentsOf: decompressedBonds)
    
    // Return the data for further processing in the caller.
    return Data(bytes: rawData, count: rawData.count * 8)
  }
  
  static func deserialize(bonds: Data) -> [SIMD2<UInt32>] {
    var rawData = [SIMD2<UInt32>](repeating: .zero, count: bonds.count / 8)
    rawData.withUnsafeMutableBytes {
      let copiedCount = bonds.copyBytes(to: $0)
      guard copiedCount == bonds.count else {
        fatalError("Incorrect number of bytes was copied.")
      }
    }
    
    // Read the header.
    let header = rawData[0]
    let compressedBondCount = UInt32(header[0])
    let decompressedBondCount = UInt32(header[1])
    
    // Pad the compressable bonds to a multiple of two.
    var paddedCompressedBondCount = compressedBondCount
    while paddedCompressedBondCount % 2 != 0 {
      paddedCompressedBondCount += 1
    }
    
    // Read the compressable bonds.
    var compressedBonds: [SIMD2<UInt16>] = []
    for groupID in 0..<paddedCompressedBondCount / 2 {
      let castedVector = rawData[Int(1 + groupID)]
      let vector = unsafeBitCast(castedVector, to: SIMD4<UInt16>.self)
      for laneID in 0..<2 {
        var compressedBond: SIMD2<UInt16> = .zero
        compressedBond[0] = vector[laneID * 2 + 0]
        compressedBond[1] = vector[laneID * 2 + 1]
        compressedBonds.append(compressedBond)
      }
    }
    
    // Restore the padded count to the original count.
    while compressedBonds.count > compressedBondCount {
      compressedBonds.removeLast()
    }
    
    // Read the non-compressable bonds.
    let decompressedRange = Int(1 + paddedCompressedBondCount / 2)...
    let decompressedBonds = Array(rawData[decompressedRange])
    guard decompressedBonds.count == decompressedBondCount else {
      fatalError("Could not decode decompressed bonds.")
    }
    
    // Merge the bonds into a common array.
    var lastAtomID: UInt32 = .zero
    var bonds: [SIMD2<UInt32>] = []
    for compressedBond in compressedBonds {
      let startDelta = UInt32(compressedBond[0])
      let lengthDelta = UInt32(compressedBond[1])
      let bond = SIMD2(
        lastAtomID + startDelta,
        lastAtomID + startDelta + lengthDelta)
      bonds.append(bond)
      
      // Update the atom cursor.
      lastAtomID += startDelta
    }
    bonds.append(contentsOf: decompressedBonds)
    
    // Sort the array of bonds.
    bonds.sort(by: { lhs, rhs in
      if lhs[0] > rhs[0] {
        return false
      } else if lhs[0] < rhs[0] {
        return true
      }
      if lhs[1] > rhs[1] {
        return false
      } else if lhs[1] < rhs[1] {
        return true
      }
      return true
    })
    return bonds
  }
}

// MARK: - Frames

extension Serialization {
  // Procedure for saving a simulation trajectory.
  //
  // Truncates the atom coordinates to picometer precision. This does not
  // make the data robust to infinitesimal rounding errors.
  static func encode(frames: [[SIMD4<Float>]]) -> Data {
    var mergedFrames: [SIMD4<Float>] = []
    for frame in frames {
      mergedFrames.append(contentsOf: frame)
    }
    let compressedTrajectory = Serialization.serialize(atoms: mergedFrames)
    
    var header: [UInt32] = []
    header.append(UInt32(compressedTrajectory.count))
    header.append(UInt32(frames.count))
    for frame in frames {
      header.append(UInt32(frame.count))
    }
    
    var serialized = Data()
    header.withUnsafeBytes {
      let chunk = Data(bytes: $0.baseAddress!, count: $0.count)
      serialized.append(chunk)
    }
    serialized.append(compressedTrajectory)
    return serialized
  }
  
  // Procedure for loading a simulation trajectory.
  static func decode(frames: Data) -> [[SIMD4<Float>]] {
    guard frames.count >= 4 else {
      fatalError("Not enough room for header.")
    }
    var dataCursor: Int = .zero
    
    // Decode the header.
    var header: [UInt32] = []
    frames.withUnsafeBytes { buffer in
      let rawPointer = buffer.baseAddress!
      do {
        let wordPointer = (rawPointer + dataCursor)
          .assumingMemoryBound(to: UInt32.self)
        header.append(wordPointer.pointee)
        dataCursor += 4
      }
      do {
        let wordPointer = (rawPointer + dataCursor)
          .assumingMemoryBound(to: UInt32.self)
        header.append(wordPointer.pointee)
        dataCursor += 4
      }
      
      let frameCount = Int(header[1])
      guard (frames.count - dataCursor) >= 4 * frameCount else {
        fatalError("Not enough room for frames.")
      }
      for _ in 0..<frameCount {
        let wordPointer = (rawPointer + dataCursor)
          .assumingMemoryBound(to: UInt32.self)
        header.append(wordPointer.pointee)
        dataCursor += 4
      }
    }
    
    // Decompress the trajectory data.
    guard (frames.count - dataCursor) == header[0] else {
      fatalError("Not enough room for compressed data.")
    }
    let compressedTrajectory: Data = frames[dataCursor...]
    let decompressedTrajectory = Serialization
      .deserialize(atoms: compressedTrajectory)
    
    // Check that the atom count matches the expected value.
    var totalAtomCount: Int = .zero
    for frameID in 0..<header[1] {
      let atomCount = header[2 + Int(frameID)]
      totalAtomCount += Int(atomCount)
    }
    guard decompressedTrajectory.count == totalAtomCount else {
      fatalError("Decompressed trajectory had unexpected size.")
    }
    
    // Decode the frames.
    var atomCursor: Int = .zero
    var output: [[SIMD4<Float>]] = []
    for frameID in 0..<header[1] {
      let atomCount = header[2 + Int(frameID)]
      let nextAtomCursor = atomCursor + Int(atomCount)
      let atoms = decompressedTrajectory[atomCursor..<nextAtomCursor]
      output.append(Array(atoms))
      
      atomCursor = nextAtomCursor
    }
    guard atomCursor == decompressedTrajectory.count else {
      fatalError("Failed to parse entire trajectory.")
    }
    
    return output
  }
  
  // Converts unsafe characters to underscores, to make the file name
  // compatible with the file system.
  static func fileSafeString(_ input: String) -> String {
    // Fetch the null-terminated C string.
    var cString = input.utf8CString
    for characterID in cString.indices {
      let byte = cString[characterID]
      let scalar = UnicodeScalar(UInt32(byte))!
      var character = Character(scalar)
      
      if character == "/" {
        character = "_"
      } else if character == ":" {
        character = "_"
      } else if character == ";" {
        character = "_"
      }
      cString[characterID] = CChar(character.asciiValue!)
    }
    return cString.withUnsafeBufferPointer {
      return String(cString: $0.baseAddress!)
    }
  }
}
