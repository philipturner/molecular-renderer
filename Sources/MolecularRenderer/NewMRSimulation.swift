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

public enum NewMRCompressionMethod {
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
  var renderer: MRRenderer
  
  // Data can be compressed with higher efficiency by dropping several bits off
  // the mantissa. If an atom moves 0.008 nm/frame, here are bits/position
  // component at reasonable precisions:
  // - 6 bits: 0.25 pm (recommended default)
  // - 5 bits: 0.5 pm
  // - 4 bits: 1 pm
  // - 3 bits: 2 pm
  public internal(set) var frameTimeInFs: Double
  public internal(set) var resolutionInApproxPm: Double
  var clusterSize: Int
  var method: NewMRCompressionMethod
  var usesCheckpoints: Bool = false
  
  var clusterCompressedOffsets: [SIMD4<Int>] = []
  var staticMetadata: [UInt8] = []
  var frameCount: Int = 0
  var clusterCursor: Int = -1
  
  fileprivate var compressedBuffer: ExpandingBuffer
  fileprivate var swapchain: Swapchain
  fileprivate var activeCluster: Cluster
  
  public init(
    renderer: MRRenderer,
    frameTimeInFs: Double,
    resolutionInApproxPm: Double,
    clusterSize: Int,
    method: NewMRCompressionMethod
  ) {
    self.renderer = renderer
    self.frameTimeInFs = frameTimeInFs
    self.resolutionInApproxPm = resolutionInApproxPm
    self.clusterSize = clusterSize
    self.method = method
    
    let device = renderer.device
    self.compressedBuffer = ExpandingBuffer(device: device)
    self.swapchain = Swapchain(device: device)
    self.activeCluster = Cluster(device: device)
  }
  
  func append(_ frame: NewMRFrame) {
    if clusterCursor != frameCount / clusterSize {
      fatalError(
        "MRSimulation doesn't support simultaneous reading and writing yet.")
    }
    
    frameCount += 1
    if frameCount % clusterSize == 0 {
      // TODO: Flush the previous frame, use GPU to encode
    }
    
    // TODO: Add to the materialized cluster
  }
  
  func frame(id: Int) -> NewMRFrame {
    fatalError("Decoding not supported yet.")
  }
  
  func save(url: URL) {
    // TODO: Prepend the header to the compressed data.
  }
  
  func processAtoms(encode: Bool) {
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    if encode {
      encoder.setComputePipelineState(renderer.encodePipeline)
    } else {
      encoder.setComputePipelineState(renderer.decodePipeline)
    }
    
    struct ProcessAtomsArguments {
      var clusterSize: UInt16
      var scaleFactor: Float
      var inverseScaleFactor: Float
    }
    let resolution = 1024 / Float(resolutionInApproxPm)
    var args = ProcessAtomsArguments(clusterSize: UInt16(clusterSize), scaleFactor: resolution, inverseScaleFactor: 1 / resolution)
    let argsBytes = MemoryLayout<ProcessAtomsArguments>.stride
    encoder.setBytes(&args, length: argsBytes, index: 0)
    
    let atomsCounts = activeCluster.atomsCounts
    let atomsOffsets = activeCluster.atomsOffsets
    var frameRanges: [SIMD2<UInt32>] = zip(atomsOffsets, atomsCounts).map {
      return SIMD2($0, $1)
    }
    let frameRangesBytes = frameRanges.count * 8
    encoder.setBytes(frameRanges, length: frameRangesBytes, index: 1)
    
    encoder.setBuffer(activeCluster.atoms.buffer, offset: 0, index: 2)
    encoder.setBuffer(
      activeCluster.compressedMetadata.uncompressed.buffer,
      offset: Int(activeCluster.metadataOffsets.last!), index: 3)
    encoder.setBuffer(
      activeCluster.compressedX.uncompressed.buffer, offset: 0, index: 4)
    encoder.setBuffer(
      activeCluster.compressedY.uncompressed.buffer, offset: 0, index: 5)
    encoder.setBuffer(
      activeCluster.compressedZ.uncompressed.buffer, offset: 0, index: 6)
    
    let numThreads = Int(atomsCounts.max(by: <)!)
    encoder.dispatchThreads(
      MTLSizeMake(numThreads, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    
    encoder.endEncoding()
    commandBuffer.commit()
    
    // Massive CPU-side stall, makes this unusable in real-time (for now).
    commandBuffer.waitUntilCompleted()
  }
}

fileprivate class ExpandingBuffer {
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
  
  func reset() {
    cursor = 0
  }
  
  func reserve(_ bytes: Int) {
    let neededBytes = roundUpToPowerOf2(cursor + bytes)
    if  buffer.length < neededBytes {
      // WARNING: If a buffer is allowed to expand, there may be data races
      // with the GPU.
      let newBuffer = device.makeBuffer(length: neededBytes)!
      memcpy(newBuffer.contents(), buffer.contents(), buffer.length)
      buffer = newBuffer
    }
  }
  
  func write(_ bytes: Int, source: UnsafeRawPointer) {
    reserve(bytes)
    memcpy(buffer.contents() + cursor, source, bytes)
    cursor += bytes
  }
  
  func read(_ bytes: Int, destination: UnsafeMutableRawPointer) -> Int {
    let readBytes = min(count - cursor,  bytes)
    memcpy(destination, buffer.contents() + cursor, bytes)
    cursor += readBytes
    return readBytes
  }
}

fileprivate class Component {
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
  
  func reset() {
    compressed.cursor = 0
    uncompressed.cursor = 0
  }
}

// Each cluster has an uncompressed header that stores:
// (a) the frame start and end, inclusive
// (b) the number of atoms in each frame
// (c) the metadata size for each frame
// (d) the offset of each component
// That's all you need to decode it. Don't round to cache boundaries.
fileprivate class Cluster {
  var frameStart: Int
  var frameCount: Int
  var atomsCounts: [UInt32]
  var metadataCounts: [UInt32]
  var atomsOffsets: [UInt32]
  var metadataOffsets: [UInt32]
  
  var compressedMetadata: Component
  var compressedX: Component
  var compressedY: Component
  var compressedZ: Component
  
  var atoms: ExpandingBuffer
  var metadata: ExpandingBuffer
  
  init(device: MTLDevice) {
    self.frameStart = -1
    self.frameCount = 0
    self.atomsCounts = []
    self.metadataCounts = []
    self.atomsOffsets = []
    self.metadataOffsets = []
    
    self.compressedMetadata = Component(device: device)
    self.compressedX = Component(device: device)
    self.compressedY = Component(device: device)
    self.compressedZ = Component(device: device)
    
    self.atoms = ExpandingBuffer(device: device)
    self.metadata = ExpandingBuffer(device: device)
  }
  
  func reset(frameStart: Int) {
    self.frameStart = frameStart
    frameCount = 0
    atomsCounts = []
    metadataCounts = []
    atomsOffsets = [0]
    metadataOffsets = [0]
    
    compressedMetadata.reset()
    compressedX.reset()
    compressedY.reset()
    compressedZ.reset()
    
    atoms.reset()
    metadata.reset()
  }
  
  func append(_ frame: NewMRFrame) {
    let atomCount = frame.atoms.count
    atomsCounts.append(UInt32(atomCount))
    atoms.cursor = Int(atomsCounts.last!)
    atoms.reserve(atomCount * 16)
    atoms.write(atomCount * 16, source: frame.atoms)
    atomsOffsets.append(atomsOffsets.last! + UInt32(atomCount))
    
    let metadataCount = frame.metadata.count
    metadataCounts.append(UInt32(metadataCount))
    metadata.cursor = Int(metadataOffsets.last!)
    metadata.reserve(metadataCount)
    metadata.write(metadataCount, source: frame.metadata)
    metadataOffsets.append(metadataOffsets.last! + UInt32(metadataCount))
  }
  
  // Whether the frame is ready to be encoded and reset.
  func full(clusterSize: Int) -> Bool {
    if frameCount > clusterSize {
      fatalError("Waited too long to encode.")
    } else {
      return frameCount == clusterSize
    }
  }
  
  // TODO: Allow the cluster to be encoded/decoded without stalling on the GPU.
  // Right now, GPU acceleration makes it slower than CPU-only. This also has
  // the unfortunate side effect that we must materialize all the frames in RAM,
  // if we want to use them in real-time.
  //
  // Once the uniform grid is entirely GPU-driven, we can remove the need for
  // the CPU to see the atoms present this frame.
  func makeFrame(frameID: Int) -> NewMRFrame {
    precondition(frameID - frameStart < frameCount)
    
    let atomCount = Int(atomsCounts[frameID - frameStart])
    let atomOffset = Int(atomsOffsets[frameID - frameStart])
    atoms.cursor = atomOffset
    let frameAtoms: [MRAtom] = .init(
      unsafeUninitializedCapacity: atomCount
    ) {
      $1 = atomCount
      let readBytes = atoms.read(atomCount * 16, destination: $0.baseAddress!)
      precondition(readBytes == atomCount * 16)
    }
    
    let metadataCount = Int(metadataCounts[frameID - frameStart])
    let metadataOffset = Int(metadataOffsets[frameID - frameStart])
    metadata.cursor = metadataOffset
    let frameMetadata: [UInt8] = .init(
      unsafeUninitializedCapacity: atomCount
    ) {
      $1 = metadataCount
      let readBytes = metadata.read(metadataCount, destination: $0.baseAddress!)
      precondition(readBytes == metadataCount)
    }
    
    return NewMRFrame(atoms: frameAtoms, metadata: frameMetadata)
  }
}

fileprivate class Swapchain {
  var clusters: [Cluster]
  var index: Int
  
  init(device: MTLDevice) {
    clusters = []
    clusters.append(Cluster(device: device))
    clusters.append(Cluster(device: device))
    index = 0
  }
  
  func newCluster(frameStart: Int) -> Cluster {
    index = (index + 1) % 2
    let cluster = clusters[index]
    cluster.reset(frameStart: frameStart)
    return cluster
  }
}
