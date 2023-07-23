//
//  MRSimulation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/23/23.
//

import Metal

// High-performance codec for recording and replaying molecular simulations.
//
// Right now, this loads the entire simulation into RAM before the app starts
// up. Eventually, we can extend it, so it happens in real-time. Doing so may
// require the sparse grid because that's entirely GPU-driven.
public class MRSimulation {
  // Summary of serialization pipeline:
  // - Original format
  //   - packed/unpacked by the library user (and eventually the GPU)
  //   - a batch of [MRAtom]
  // - Intermediate format:
  //   - packed/unpacked by the GPU
  //   - rearranges data to maximize compression efficiency
  //   - de-interleaves, quantizes components of [MRAtom]
  //   - interleaves data among instances within the batch
  // - Final format:
  //   - packed/unpacked by the CPU
  //   - LZBITMAP compression using Metal fast resource loading
  //
  // Serialization:
  // MRAtom -> GPU Intermediate -> LZBITMAP
  // Deserialization:
  // LZBITMAP -> GPU Intermediate -> MRAtom
  struct SimulationHeader {
    var frameCount: Int
    var frameTimeInFs: Double
    var maxFrameMetadataSize: Int
    var batchCount: Int
    var atomsPerBatch: SIMD32<Int>
  }
  
  // After storing the header, round up to a 64 KB boundary.
  
  struct FrameHeader {
    // For each frame, store its frame ID explicitly, to help recover from
    // corrupted simulations.
    public var frameID: Int
    public var batchActiveMask: SIMD32<UInt8>
  }
  
  // After the header, concatenate the metadata for every active batch. Pad with
  // zeroes until reaching the inactive batch size. Round to a 64B boundary.
  //
  // Repeat that process with the concatenated X mantissas, X exponents,
  // Y/Z mantissas/exponents, and 16-bit masks combining the element IDs
  // with flags. Across batch instances, pad the number of atoms to 4.
  //
  // After serializing the entire frame, round up to a 64 KB boundary.
  
  public var frameTimeInFs: Double
  public var maxFrameMetadataSize: Int
  public var batchCount: Int = 0
  public var frames: [MRFrame] = []
  
  init(
    frameTimeInFs: Double,
    maxFrameMetadataSize: Int
  ) {
    self.frameTimeInFs = frameTimeInFs
    self.maxFrameMetadataSize = maxFrameMetadataSize
  }
  
  init(url: URL) throws {
    // First, synchronously load the header, to determine how large each frame
    // is.
    
    // Load each frame in a separate command, asynchronously in the background.
    // Meanwhile, deserialize frames streamed from the SSD. Do this on the GPU
    // so it runs reasonably fast in Swift debug mode.
    fatalError("Not implemented.")
  }
  
  func append(_ frame: MRFrame) {
    // Increase the batch count if needed.
    
    // Quantize atom positions to 1/1024 nm precision, rounding to the nearest
    // even integer. Store 16-bit "mantissa" parts separately from 16-bit
    // "exponent" parts.
  }
  
  // TODO: Store the X, Y, Z, and element/flags components separately. Do not
  // store the square radii. The element IDs and flags are allowed to change
  // each frame.
  func store(url: URL) throws {
    
  }
}

public struct MRFrame {
  public var timeInFs: Double
  public var batchActiveMask: SIMD32<UInt8>
  public var atoms: [[MRAtom]]
  public var metadata: [[Data]]
}
