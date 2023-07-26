//
//  MRSimulation.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 7/26/23.
//

import Compression
import Metal

// ========================================================================== //
//                                MRSimulation                                //
//  high-performance codec for recording and replaying molecular simulations  //
// ========================================================================== //

// Summary of serialization pipeline:
// - Original format
//   - packed/unpacked by the library user
//   - [MRAtom]
// - Intermediate format
//   - packed/unpacked by the GPU
//   - de-interleaves and quantizes components of each MRAtom
//   - interleaves data among consecutive frames
// - Final format
//   - packed/unpacked by 4 CPU cores
//   - LZBITMAP lossless compression
//
// Serialization:
//   MRAtom -> GPU Intermediate -> LZBITMAP
// Deserialization:
//   LZBITMAP -> GPU Intermediate -> MRAtom

/// Rounds an integer up to the nearest power of 2.
fileprivate func roundUpToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - max(0, input - 1).leadingZeroBitCount)
}

/// Rounds an integer down to the nearest power of 2.
fileprivate func roundDownToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - 1 - input.leadingZeroBitCount)
}

public enum NewMRCompressioMethod {
  case lzBitmap
  case zlib
  
  var compressionAlgorithm: compression_algorithm {
    switch self {
    case .lzBitmap:
      return COMPRESSION_LZBITMAP
    case .zlib:
      return COMPRESSION_ZLIB
    }
  }
}

public struct NewMRFrame {
  var atoms: [MRAtom]
  var metadata: [UInt8]
  
  init(atoms: [MRAtom], metadata: [UInt8]) {
    self.atoms = atoms
    self.metadata = metadata
  }
  
  init(atoms: [MRAtom]) {
    self.init(atoms: atoms, metadata: [])
  }
}

public class NewMRSimulation {
  public internal(set) var frameTimeInFs: Double
  public internal(set) var resolutionInApproxPm: Double
  var clusterCompressedOffsets: [SIMD4<Int>]
  var staticMetadata: [UInt8]
  var usesCheckpoints: Bool = false
  
  struct ExpandingBuffer {
    var device: MTLDevice
    var buffer: MTLBuffer
    var cursor: Int
    var count: Int
    
    init(device: MTLDevice) {
      self.device = device
      self.buffer = device.makeBuffer(length: 65536)!
      self.cursor = 0
      self.count = 0
    }
    
    mutating func reserve(_ bytes: Int) {
      let neededBytes = roundUpToPowerOf2(cursor + bytes)
      if buffer == nil || buffer!.length < neededBytes {
        let newBuffer = device.makeBuffer(length: neededBytes)!
        if let buffer {
          // WARNING: If a buffer is allowed to expand, there may be data races
          // with the GPU.
          memcpy(newBuffer.contents(), buffer.contents(), buffer.length)
        }
        buffer = newBuffer
      }
    }
    
    func write(_ bytes: Int, source: UnsafeMutableRawPointer) {
      reserveBytes(bytes)
      memcpy(buffer.contents() + cursor, source, bytes)
      cursor += bytes
    }
    
    func read(_ bytes: Int, destination: UnsafeMutableRawPointer) -> Int {
      let readBytes = min(count - cursor,  bytes)
      memcpy(destination, buffer.contents() + cursor, bytes)
      cursor += readBytes
    }
  }
  
  var compressedBuffer: ExpandingBuffer
  var compressedBytes: Int = 0
  var encodingCursor: Int = 0
  var url: URL
  var method: NewMRCompressionMethod
  
  // Each cluster has an uncompressed header that stores:
  // (a) the frame start and end, inclusive
  // (b) the number of atoms in each frame
  // (c) the metadata size for each frame
  // (d) the offset of each component
  // That's all you need to decode it. Don't round to cache boundaries.
  // TODO: All internal offsets must be UInt32.
  class Component {
    var device: MTLDevice
    var compressed: ExpandingBuffer
    var uncompressed: ExpandingBuffer
    var scratch: MTLBuffer
    var blockSize: Int = 1024 * 1024
    
    init(device: MTLDevice) {
      self.device = device
      self.compressed = ExpandingBuffer(device: device)
      self.uncompressed = ExpandingBuffer(device: device)
      self.scratch = device.makeBuffer(length: blockSize)!
    }
  }
  
  class Cluster {
    var index: Int = -1
    var metadata: Component
    var x: Component
    var y: Component
    var z: Component
    var atoms: ExpandingBuffer
    var metadata: ExpandingBuffer
    var activeCommandBuffer: MTLCommandBuffer?
    
    init(device: MTLDevice) {
      fatalError("Not implemented.")
    }
    
    func makeFrame(frameID: Int) -> MRFrame {
      fatalError("Not implemented")
    }
    
    func waitOnGPU() {
      if let activeCommandBuffer {
        activeCommandBuffer.waitUntilCompleted()
        activeCommandBuffer = nil
      }
    }
  }
  
  class Swapchain {
    var clusters: [Cluster]
    var index: Int
    
    init(device: MTLDevice) {
      fatalError("Not implemented.")
    }
    
    func nextCluster() -> Cluster {
      index = (index + 1) % 2
    }
  }
  
  var swapchain: Swapchain
  var activeCluster: Cluster
  
  
}
