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
  
  public internal(set) var frameTimeInFs: Double
  public internal(set) var resolutionInApproxPm: Double
  var clusterCompressedOffsets: [SIMD4<Int>] = []
  var staticMetadata: [UInt8] = []
  var usesCheckpoints: Bool = false
  
  fileprivate var compressedBuffer: ExpandingBuffer
  var compressedBytes: Int = 0
  var encodingCursor: Int = 0
  var url: URL?
  var method: NewMRCompressionMethod?
  
  fileprivate var swapchain: Swapchain
  fileprivate var activeCluster: Cluster
  
  public init(
    renderer: MRRenderer,
    frameTimeInFs: Double,
    resolutionInApproxPm: Double
  ) {
    self.renderer = renderer
    self.frameTimeInFs = frameTimeInFs
    self.resolutionInApproxPm = resolutionInApproxPm
    self.clusterCompressedOffsets = []
    
    let device = renderer.device
    self.compressedBuffer = ExpandingBuffer(device: device)
    self.swapchain = Swapchain(device: device)
    self.activeCluster = Cluster(device: device)
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
  
  func serialize() {
    // TODO
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
  // Right now, GPU acceleration makes it slower than CPU-only.
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
  
  func encode(renderer: MRRenderer) {
    // TODO
  }
  
  func decode(renderer: MRRenderer) {
    // TODO
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
