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
  // with flags. Between batch instances, zero-pad the number of atoms to a
  // multiple of 64.
  //
  // After serializing the entire frame, round up to a 64 KB boundary.
  
  public internal(set) var frameTimeInFs: Double = -1
  public internal(set) var maxFrameMetadataSize: Int = 0
  public internal(set) var maxAtomsPerBatch: [Int] = []
  public internal(set) var frames: [MRFrame] = []
  
  var fileHandle: MTLIOFileHandle?
  var context: MTLIOCompressionContext?
  var frameStride: Int?
  var atomsStride: Int?
  
  var framesInFlight: [Bool] = []
  var semaphores: [DispatchSemaphore] = []
  var frameBuffers: [MTLBuffer] = []
  var atomsBuffers: [MTLBuffer] = []
  var frameID: Int = 0
  
  init(frameTimeInFs: Double) {
    self.frameTimeInFs = frameTimeInFs
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
  
  func initializeFrameBuffers(renderer: MRRenderer) {
    var stride = MemoryLayout<FrameHeader>.stride
    let batchSize = maxAtomsPerBatch.count
    stride += 1 * batchSize
    stride += maxFrameMetadataSize * batchSize
    stride = (stride + 63) / 64 * 64
    
    let totalAtoms = maxAtomsPerBatch.reduce(0) {
      $0 + ($1 + 63) / 64 * 64
    }
    stride += totalAtoms * 7 * 2
    self.atomsStride = totalAtoms
    
    let pageSize = 65536
    stride = (stride + pageSize - 1) / pageSize * pageSize
    self.frameStride = stride
    
    framesInFlight = Array(repeating: false, count: 8)
    semaphores = Array(repeating: DispatchSemaphore(value: 0), count: 8)
    frameBuffers = []
    atomsBuffers = []
    frameID = 0
    
    for _ in 0..<8 {
      frameBuffers.append(renderer.device.makeBuffer(length: stride)!)
      atomsBuffers.append(renderer.device.makeBuffer(length: totalAtoms * 16)!)
    }
  }
  
  func initializeFile(renderer: MRRenderer, url: URL) {
    fileHandle = try! renderer.device.makeIOHandle(
      url: url, compressionMethod: .lzBitmap)
  }
  
  func stream(_ closure: () -> Void) {
    while frameID < frames.count {
      if framesInFlight[frameID % 8] {
        semaphores[frameID % 8].wait()
      }
      closure()
      
      framesInFlight[frameID % 8] = true
      frameID += 1
    }
    while frameID < frames.count + 8 {
      if framesInFlight[frameID % 8] {
        semaphores[frameID % 8].wait()
      }
      frameID += 1
    }
  }
  
  init(renderer: MRRenderer, url: URL) throws {
    initializeFile(renderer: renderer, url: url)
    renderer.serializer.loadHeader(simulation: self)
    initializeFrameBuffers(renderer: renderer)
    
    stream {
      renderer.serializer.loadFrameAsync(simulation: self)
    }
  }
  
  func store(renderer: MRRenderer, url: URL) throws {
    initializeFrameBuffers(renderer: renderer)
    initializeFile(renderer: renderer, url: url)
    
    let path = url.absoluteURL.path
    context = MTLIOCreateCompressionContext(path, .lzBitmap, 65536)!
    defer {
      let status = MTLIOFlushAndDestroyCompressionContext(context!)
      guard status == .complete else {
        fatalError("Could not flush and destroy compression context.")
      }
      context = nil
    }
    renderer.serializer.storeHeader(simulation: self)
    
    stream {
      renderer.serializer.storeFrameAsync(simulation: self)
    }
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
  
  func storeHeader(simulation: MRSimulation) {
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
  
  func loadHeader(simulation: MRSimulation) {
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
    
    simulation.frameTimeInFs = header.frameTimeInFs
    simulation.maxFrameMetadataSize = header.maxFrameMetadataSize
    simulation.maxAtomsPerBatch = Array(repeating: 0, count: header.frameCount)
    simulation.frames = Array(
      repeating: MRFrame(atoms: [], metadata: []), count: header.frameCount)
    
    let maxAtomsPointer = cursor.assumingMemoryBound(to: Int.self)
    let batchCount = simulation.maxAtomsPerBatch.count
    for i in 0..<batchCount {
      simulation.maxAtomsPerBatch[i] = maxAtomsPointer[i]
    }
    cursor += 8 * batchCount
  }
  
  func storeFrameAsync(simulation: MRSimulation) {
    let frameID = simulation.frameID
    let frame = simulation.frames[frameID]
    precondition(frame.atoms.count == simulation.maxAtomsPerBatch.count)
    precondition(frame.metadata.count == simulation.maxAtomsPerBatch.count)
    
    let frameBuffer = simulation.frameBuffers[frameID]
    let atomsBuffer = simulation.atomsBuffers[frameID]
    var cursor = frameBuffer.contents()
    
    let header = cursor.assumingMemoryBound(to: MRSimulation.FrameHeader.self)
    header.pointee = .init(frameID: frameID)
    cursor += 8
    
    for i in 0..<frame.atoms.count {
      let mask = cursor.assumingMemoryBound(to: UInt8.self)
      let count = frame.atoms[i].count
      if count == 0 {
        mask.pointee = 0
      } else {
        precondition(count == simulation.maxAtomsPerBatch[i])
        mask.pointee = 1
      }
    }
    
    var missingDataBytes: Int = 0
    for i in 0..<frame.atoms.count {
      guard frame.atoms[i].count > 0 else {
        missingDataBytes += simulation.maxFrameMetadataSize
        continue
      }
      memset(cursor, 0, simulation.maxFrameMetadataSize)
      defer {
        cursor += simulation.maxFrameMetadataSize
      }
      
      let metadata = frame.metadata[i]
      precondition(metadata.count < simulation.maxFrameMetadataSize)
      guard metadata.count > 0 else {
        continue
      }
      
      metadata.withUnsafeBufferPointer { bufferPointer in
        _ = memcpy(cursor, bufferPointer.baseAddress!, bufferPointer.count)
      }
    }
    cursor += missingDataBytes
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder(
      dispatchType: .concurrent)!
    encoder.setComputePipelineState(serializePipeline)
    encoder.setBuffer(atomsBuffer, offset: 0, index: 0)
    encoder.setBuffer(frameBuffer, offset: 0, index: 1)
    
    var atomsStride = simulation.atomsStride!
    var atomsCursor = atomsBuffer.contents()
    encoder.setBytes(&atomsStride, length: 4, index: 2)
    
    let cursorStart = frameBuffer.contents()
    let atomsStart = atomsBuffer.contents()
    for i in 0..<frame.atoms.count {
      var numAtoms = simulation.maxAtomsPerBatch[i]
      let numAtomThreads = (numAtoms + 1) / 2
      numAtoms = (numAtoms + 63) / 64 * 64
      defer {
        atomsCursor += numAtoms * 16
      }
      memcpy(atomsCursor, frame.atoms[i], numAtoms * 16)
      
      encoder.setBufferOffset(atomsCursor - atomsStart, index: 0)
      encoder.setBufferOffset(cursor - cursorStart, index: 1)
      encoder.dispatchThreads(
        MTLSizeMake(numAtomThreads, 1, 1),
        threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
      
      cursor += numAtoms * MemoryLayout<UInt16>.stride
    }
    encoder.endEncoding()
    commandBuffer.addCompletedHandler { [self, simulation] _ in
      var succeeded = false
      while !succeeded {
        framesQueue.sync {
          let currentFrameID = simulation.frames.count
          if currentFrameID > frameID {
            fatalError("This should never happen.")
          }
          if currentFrameID < frameID {
            // The other way around, this won't be necessary, because each array
            // will already have a slot for the current frame ID.
            return
          }
          
          MTLIOCompressionContextAppendData(
            simulation.context!,
            frameBuffer.contents(),
            simulation.frameStride!)
          
          simulation.semaphores[frameID % 8].signal()
        }
        if !succeeded {
          usleep(50)
        }
      }
    }
    commandBuffer.commit()
  }
  
  func loadFrameAsync(simulation: MRSimulation) {
    
  }
}
