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
  //   - packed/unpacked by the library user
  //   - a batch of [MRAtom]
  // - Intermediate format
  //   - packed/unpacked by the GPU
  //   - rearranges data to maximize compression efficiency
  //   - de-interleaves, quantizes components of [MRAtom]
  //   - interleaves data among instances within the batch
  // - Final format
  //   - packed/unpacked by the CPU
  //   - LZBITMAP compression using Metal fast resource loading
  //
  // Serialization:
  //   MRAtom -> GPU Intermediate -> LZBITMAP
  // Deserialization:
  //   LZBITMAP -> GPU Intermediate -> MRAtom
  struct SimulationHeader {
    var frameCount: Int
    var frameTimeInFs: Double
    var maxFrameMetadataSize: Int
    var batchCount: Int
  }
  
  // After storing the header, store an array of 64-bit integers stating the
  // max number of atoms in each batch. Round up to a 64 KB boundary.
  
  struct FrameHeader {
    // For each frame, store its frame ID explicitly, to help recover from
    // corrupted simulations.
    public var frameID: Int
  }
  
  // After the frame ID, store an 8-bit boolean mask of whether each frame is
  // active. Then, concatenate the metadata for every active batch. Pad with
  // zeroes until reaching the inactive batch size. Round to a 64B boundary.
  //
  // Repeat that process with the concatenated X mantissas, X exponents,
  // Y/Z mantissas/exponents, and 16-bit masks combining the element IDs
  // with flags. Across batch instances, zero-pad the number of atoms to a
  // multiple of 4. Round to 64B boundaries between components.
  //
  // After serializing the entire frame, round up to a 64 KB boundary.
  
  public internal(set) var frameTimeInFs: Double
  public internal(set) var maxFrameMetadataSize: Int = 0
  public internal(set) var maxAtomsPerBatch: [Int] = []
  public internal(set) var frames: [MRFrame] = []
  
  var fileHandle: MTLIOFileHandle?
  var context: MTLIOCompressionContext?
  var lastCommandBuffer: (Int, MTLCommandBuffer)?
  var semaphore: DispatchSemaphore = .init(value: 8)
  
  init(frameTimeInFs: Double) {
    self.frameTimeInFs = frameTimeInFs
  }
  
  init(renderer: MRRenderer, url: URL) throws {
    // First, synchronously load the header, to determine how large each frame
    // is.
    
    // Load each frame in a separate command, asynchronously in the background.
    // Meanwhile, deserialize frames streamed from the SSD. Do this on the GPU
    // so it runs reasonably fast in Swift debug mode.
    fatalError("Not implemented.")
  }
  
  func append(_ frame: MRFrame) {
    var index = 0
    for (atoms, metadata) in zip(frame.atoms, frame.metadata) {
      maxFrameMetadataSize = max(metadata.count, maxFrameMetadataSize)
      if index >= maxAtomsPerBatch.count {
        maxAtomsPerBatch.append(atoms.count)
      } else {
        maxAtomsPerBatch[index] = max(maxAtomsPerBatch[index], atoms.count)
      }
      index += 1
    }
    frames.append(frame)
  }
  
  func store(renderer: MRRenderer, url: URL) throws {
    let handle = try! renderer.device.makeIOHandle(
      url: url, compressionMethod: .lzBitmap)
    precondition(
      context == nil, "Saved twice without destroying the context.")
    
    let path = url.absoluteURL.path
    context = MTLIOCreateCompressionContext(path, .lzBitmap, 65536)!
//    defer {
//      let status = MTLIOFlushAndDestroyCompressionContext(context!)
//      guard status == .complete else {
//        fatalError("Could not flush and destroy compression context.")
//      }
//      context = nil
//    }
  }
  
  func synchronize() {
    
  }
}

public struct MRFrame {
  public var atoms: [[MRAtom]]
  public var metadata: [[Data]]
}

class MRSerializer {
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var ioCommandQueue: MTLIOCommandQueue
 
  var serializePipeline: MTLComputePipelineState
  var deserializePipeline: MTLComputePipelineState
  var framesQueue: DispatchQueue = .init(
    label: "com.philipturner.molecular-renderer.MRSerializer.framesQueue")
  
  init(renderer: MRRenderer, library: MTLLibrary) {
    self.device = renderer.device
    self.commandQueue = renderer.commandQueue
    
    let desc = MTLIOCommandQueueDescriptor()
    desc.type = .concurrent
    self.ioCommandQueue = try! device.makeIOCommandQueue(descriptor: desc)
    
    let serializeFunction = library.makeFunction(name: "serialize")!
    let deserializeFunction = library.makeFunction(name: "deserialize")!
    serializePipeline = try! device.makeComputePipelineState(
      function: serializeFunction)
    deserializePipeline = try! device.makeComputePipelineState(
      function: deserializeFunction)
  }
  
  func storeHeader(simulation: inout MRSimulation) {
    let bytes = malloc(65536)!
    memset(bytes, 0, 65536)
    defer { bytes.deallocate() }
    var cursor = bytes
    
    let headerPointer = cursor.assumingMemoryBound(
      to: MRSimulation.SimulationHeader.self)
    headerPointer.pointee = .init(
      frameCount: simulation.frames.count,
      frameTimeInFs: simulation.frameTimeInFs,
      maxFrameMetadataSize: simulation.maxFrameMetadataSize,
      batchCount: simulation.maxAtomsPerBatch.count)
    cursor += MemoryLayout<MRSimulation.SimulationHeader>.stride
    
    let maxAtomsPointer = cursor.assumingMemoryBound(to: Int.self)
    let batchCount = simulation.maxAtomsPerBatch.count
    for i in 0..<batchCount {
      maxAtomsPointer[i] = simulation.maxAtomsPerBatch[i]
    }
    cursor += 8 * batchCount
    
    MTLIOCompressionContextAppendData(
      simulation.context!, bytes, cursor - bytes)
  }
  
  func loadHeader(simulation: inout MRSimulation) {
    let bytes = malloc(65536)!
    memset(bytes, 0, 65536)
    defer { bytes.deallocate() }
    var cursor = bytes
    
    let ioCommandBuffer = ioCommandQueue.makeCommandBuffer()
    ioCommandBuffer.loadBytes(bytes, size: 65536, sourceHandle: simulation.fileHandle!, sourceHandleOffset: 0)
    ioCommandBuffer.commit()
    ioCommandBuffer.waitUntilCompleted()
    
    let headerPointer = cursor.assumingMemoryBound(
      to: MRSimulation.SimulationHeader.self)
    let header = headerPointer.pointee
    cursor += MemoryLayout<MRSimulation.SimulationHeader>.stride
    
    simulation.frames = Array(
      repeating: MRFrame(atoms: [], metadata: []), count: header.frameCount)
  }
  
  func storeFrameAsync(simulation: inout MRSimulation, frameID: Int) {
    let frame = simulation.frames[frameID]
  }
  
  func loadFrameAsync(simulation: inout MRSimulation, frameID: Int) {
    simulation.frames.append(MRFrame(atoms: [], metadata: []))
  }
}
