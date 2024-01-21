//
//  Base64.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/6/24.
//

import Foundation

// A base64-encoded format wrapping a 16-byte representation of an atom.
// It is a SIMD4<Float> vector storing the position and the atomic number,
// casted from UInt8 to Float. Next, it is converted into base64 to make the
// raw data easily portable.
//
// It can even be stored as a string literal in source code. For this
// reason, newlines are inserted after every 76 bytes of output. Around 4
// atoms fit into each line of code. Most base64 encoders ignore whitespace,
// as it's a common method to organize large base64 strings. The overall
// storage overhead is ~200 bits/atom, which may be comparable to mrsim-txt.
//
// Hashes and asterisks can be used to comment sections of the encoded output.
// They may signify frame numbers or keys to identify specific objects. This
// structure is compatible with most base64 encoders. It also locally encodes
// whether a hash begins or ends a comment, allowing initial parsing/scanning to
// be parallelized.
//
// #* comment *#
//
// Comments are not baked into this file due to the potential for feature creep.
// Comments and parallelization of large encoding/decoding jobs should be
// comparatively easy to implement client-side. All that might be needed is a
// faster single-core CPU kernel in this file, for both encoding and decoding
// individual arrays of atoms.

struct Base64Decoder {
  // This currently takes ~100 nanoseconds per atom on a single CPU core.
  static func decodeAtoms(_ string: String) -> [SIMD4<Float>] {
    let options: Data.Base64DecodingOptions = [
      .ignoreUnknownCharacters
    ]
    guard let data = Data(base64Encoded: string, options: options) else {
      fatalError("Could not decode the data.")
    }
    guard data.count % 16 == 0 else {
      fatalError("Data did not have the right alignment.")
    }
    
    let rawMemory: UnsafeMutableBufferPointer<SIMD4<Float>> =
      .allocate(capacity: data.count / 16)
    let encodedBytes = data.copyBytes(to: rawMemory)
    guard encodedBytes == data.count else {
      fatalError("Did not encode the right number of bytes.")
    }
    
    let output = Array(rawMemory)
    rawMemory.deallocate()
    return output
  }
  
  static func decodeBonds(_ string: String) -> [SIMD2<UInt32>] {
    let options: Data.Base64DecodingOptions = [
      .ignoreUnknownCharacters
    ]
    guard let data = Data(base64Encoded: string, options: options) else {
      fatalError("Could not decode the data.")
    }
    guard data.count % 8 == 0 else {
      fatalError("Data did not have the right alignment.")
    }
    
    let rawMemory: UnsafeMutableBufferPointer<SIMD2<UInt32>> =
      .allocate(capacity: data.count / 8)
    let encodedBytes = data.copyBytes(to: rawMemory)
    guard encodedBytes == data.count else {
      fatalError("Did not encode the right number of bytes.")
    }
    
    let output = Array(rawMemory)
    rawMemory.deallocate()
    return output
  }
}

struct Base64Encoder {
  // This currently takes ~100 nanoseconds per atom on a single CPU core.
  static func encodeAtoms(_ atoms: [SIMD4<Float>]) -> String {
    let rawMemory: UnsafeMutableRawPointer =
      .allocate(byteCount: 16 * atoms.count, alignment: 16)
    rawMemory.copyMemory(from: atoms, byteCount: 16 * atoms.count)
    
    let data = Data(bytes: rawMemory, count: 16 * atoms.count)
    let options: Data.Base64EncodingOptions = [
      .lineLength76Characters,
      .endLineWithLineFeed
    ]
    let string = data.base64EncodedString(options: options)
    
    rawMemory.deallocate()
    return string
  }
  
  static func encodeBonds(_ bonds: [SIMD2<UInt32>]) -> String {
    let rawMemory: UnsafeMutableRawPointer =
      .allocate(byteCount: 8 * bonds.count, alignment: 8)
    rawMemory.copyMemory(from: bonds, byteCount: 8 * bonds.count)
    
    let data = Data(bytes: rawMemory, count: 8 * bonds.count)
    let options: Data.Base64EncodingOptions = [
      .lineLength76Characters,
      .endLineWithLineFeed
    ]
    let string = data.base64EncodedString(options: options)
    
    rawMemory.deallocate()
    return string
  }
}
