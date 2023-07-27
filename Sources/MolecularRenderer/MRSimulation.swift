//
//  MRSimulation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/23/23.
//

import Compression
import Metal
import System

// ========================================================================== //
//                                MRSimulation                                //
//  high-performance codec for recording and replaying molecular simulations  //
// ========================================================================== //

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
    var batchCount: Int
    var frameCount: Int
    var frameTimeInFs: Double
    
    // Make the resolution a power of 2 to minimize rounding error.
    var resolutionInApproxPm: Double
    var maxFrameMetadataSize: Int
    
    // Whether to include variable-length, one-time metadata per simulation in
    // the batch, such as a list of bonds or ion charges.
    var hasExtendedMetadata: Int = 0
  }
  
  // After storing the header, store an array of 64-bit integers stating the
  // number of atoms in each simulation. Round up to a 64 KB boundary.
  
  struct FrameHeader {
    // For each frame, store its frame ID explicitly, to help recover from
    // corrupted simulations.
    public var frameID: Int
  }
  
  // After the frame ID, store an 8-bit boolean mask of whether each frame is
  // active. Then, concatenate the metadata for every active batch. Pad with
  // zeroes until reaching the inactive batch size. Round to a 128 B boundary.
  //
  // Repeat that process with each component of the atom's origin separately. Do
  // so again for the 16-bit tail storage (atomic number + flags), which is
  // padded to 32 bits. Between batch instances, zero-pad the number of atoms to
  // a multiple of 8.
  //
  // After serializing the entire frame, round up to a 64 KB boundary.
  
  // Data can be compressed with higher efficiency by dropping several bits off
  // the mantissa. If an atom moves 0.008 nm/frame, here are bits/position
  // component at reasonable precisions:
  // - 6 bits: 0.25 pm
  // - 5 bits: 0.5 pm
  // - 4 bits: 1 pm
  // - 3 bits: 2 pm
  //
  // TODO: Save a checkpoint every N frames for recovery from corruption and
  // replaying from the middle of the recording. The distance between each
  // checkpoint should be specified in the header. The delta for checkpointed
  // frames should still be stored, so you can trace backward from such frames
  // (halving the required checkpointing resolution).
  
  public internal(set) var frameTimeInFs: Double = -1
  public internal(set) var resolutionInApproxPm: Double = -1
  public internal(set) var maxFrameMetadataSize: Int = 0
  public internal(set) var maxAtomsPerBatch: [Int] = []
  public internal(set) var frames: [MRFrame] = []
  
  var fileHandle: MTLIOFileHandle?
  var context: MRCompressionContext?
  var frameStride: Int?
  var atomsStride: Int?
  
  var framesInFlight: [Bool] = []
  var semaphores: [DispatchSemaphore] = []
  var frameBuffers: [MTLBuffer] = []
  var atomsBuffers: [MTLBuffer] = []
  var cumulativeSumBuffer: MTLBuffer?
  var frameID: Int = 0
  var finishedFrameID: Int = 0
  
  public init(frameTimeInFs: Double, resolutionInApproxPm: Double) {
    self.frameTimeInFs = frameTimeInFs
    self.resolutionInApproxPm = resolutionInApproxPm
  }
  
  public init(renderer: MRRenderer, url: URL, method: MRCompressionMethod) {
    fatalError()
//    fileHandle = try! renderer.device.makeIOHandle(
//      url: url, compressionMethod: method.ioMethod)
//    renderer.serializer.loadHeader(simulation: self)
//    initializeFrameBuffers(renderer: renderer)
//    
//    stream {
//      renderer.serializer.loadFrameAsync(simulation: self)
//    }
  }
  
  public func append(_ frame: MRFrame) {
    var index = 0
    precondition(frame.atoms.count == frame.metadata.count)
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
  
  public func serialize(
    renderer: MRRenderer, url: URL, method: MRCompressionMethod
  ) {
    fatalError()
//    initializeFrameBuffers(renderer: renderer)
//    
//    context = MRCompressionContext(url: url, method: method)
//    defer {
//      context!.destroy()
//      context = nil
//    }
//    renderer.serializer.storeHeader(simulation: self)
//    
//    stream {
//      renderer.serializer.storeFrameAsync(simulation: self)
//    }
  }
  
  func initializeFrameBuffers(renderer: MRRenderer) {
    var stride = MemoryLayout<FrameHeader>.stride
    let batchSize = maxAtomsPerBatch.count
    stride += 1 * batchSize
    stride += maxFrameMetadataSize * batchSize
    stride = (stride + 127) / 128 * 128
    
    let totalAtoms = maxAtomsPerBatch.reduce(0) {
      $0 + ($1 + 7) / 8 * 8
    }
    stride += totalAtoms * 16
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
      
      let device = renderer.device
      atomsBuffers.append(device.makeBuffer(length: totalAtoms * 16)!)
      cumulativeSumBuffer = device.makeBuffer(length: totalAtoms * 16)!
    }
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
}

public struct MRFrame {
  public var atoms: [[MRAtom]]
  public var metadata: [Data]
  
  public init(atoms: [[MRAtom]], metadata: [Data]) {
    self.atoms = atoms
    self.metadata = metadata
  }
}

public enum MRCompressionMethod {
  case lzBitmap
  
  var ioMethod: MTLIOCompressionMethod {
    switch self {
    case .lzBitmap:
      // TODO: Actually use LZBITMAP.
      return .zlib
    }
  }
  
  var compressionAlgorithm: compression_algorithm {
    switch self {
    case .lzBitmap:
      return COMPRESSION_ZLIB
    }
  }
}

class MRSerializer {
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var ioCommandQueue: MTLIOCommandQueue
  
  var serializePipeline: MTLComputePipelineState
  var deserializePipeline: MTLComputePipelineState
  var framesQueue: DispatchQueue = .init(
    label: "com.philipturner.molecular-renderer.MRSerializer.framesQueue")
  var asyncQueue: DispatchQueue = .init(
    label: "com.philipturner.molecular-renderer.MRSerializer.asyncQueue",
    attributes: .concurrent)
  
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
      batchCount: simulation.maxAtomsPerBatch.count,
      frameCount: simulation.frames.count,
      frameTimeInFs: simulation.frameTimeInFs,
      resolutionInApproxPm: simulation.resolutionInApproxPm,
      maxFrameMetadataSize: simulation.maxFrameMetadataSize)
    cursor += MemoryLayout<MRSimulation.SimulationHeader>.stride
    
    let maxAtomsPointer = cursor.assumingMemoryBound(to: Int.self)
    let batchCount = simulation.maxAtomsPerBatch.count
    for i in 0..<batchCount {
      maxAtomsPointer[i] = simulation.maxAtomsPerBatch[i]
    }
    cursor += batchCount * MemoryLayout<Int>.stride
    
    simulation.context!.append(header: bytes)
  }
  
  private func alignCursor(
    _ cursor: inout UnsafeMutableRawPointer, frameBuffer: MTLBuffer
  ) {
    let newCursor = frameBuffer.contents()
    var cursorDistance = cursor - newCursor
    cursorDistance = (cursorDistance + 127) / 128 * 128
    cursor = newCursor + cursorDistance
  }
  
  func loadHeader(simulation: MRSimulation) {
    let bytes = malloc(65536)!
    memset(bytes, 0, 65536)
    defer { bytes.deallocate() }
    var cursor = bytes
    
    let ioCommandBuffer = ioCommandQueue.makeCommandBuffer()
    let buf = device.makeBuffer(length: 65536)!
    ioCommandBuffer.load(buf, offset: 0, size: 65536, sourceHandle: simulation.fileHandle!, sourceHandleOffset: 0)
//    ioCommandBuffer.loadBytes(bytes, size: 65536, sourceHandle: simulation.fileHandle!, sourceHandleOffset: 0)
    ioCommandBuffer.commit()
    ioCommandBuffer.waitUntilCompleted()
    print(ioCommandBuffer.status == .error)
    print(ioCommandBuffer.status == .cancelled)
    print(ioCommandBuffer.status == .complete)
    print(ioCommandBuffer.status == .pending)
    
    cursor = buf.contents()
    
    let headerPointer = cursor.assumingMemoryBound(
      to: MRSimulation.SimulationHeader.self)
    let header = headerPointer.pointee
    cursor += MemoryLayout<MRSimulation.SimulationHeader>.stride
    
    print(headerPointer.pointee)
    
    simulation.frameTimeInFs = header.frameTimeInFs
    simulation.resolutionInApproxPm = header.resolutionInApproxPm
    simulation.maxFrameMetadataSize = header.maxFrameMetadataSize
    simulation.maxAtomsPerBatch = Array(repeating: 0, count: header.batchCount)
    simulation.frames = Array(
      repeating: MRFrame(atoms: [], metadata: []), count: header.frameCount)
    
    let maxAtomsPointer = cursor.assumingMemoryBound(to: Int.self)
    let batchCount = simulation.maxAtomsPerBatch.count
    for i in 0..<batchCount {
      simulation.maxAtomsPerBatch[i] = maxAtomsPointer[i]
    }
  }
  
  func startEncoder(
    _ commandBuffer: MTLCommandBuffer, simulation: MRSimulation
  ) -> MTLComputeCommandEncoder {
    let encoder = commandBuffer
      .makeComputeCommandEncoder(dispatchType: .concurrent)!
    
    struct SerializationArguments {
      var batchStride: UInt32
      var scaleFactor: Float
      var inverseScaleFactor: Float
    }
    let resolution = 1024 / Float(simulation.resolutionInApproxPm)
    var arguments = SerializationArguments(
      batchStride: UInt32(simulation.atomsStride!),
      scaleFactor: resolution,
      inverseScaleFactor: 1 / resolution)
    
    var atomsStride = simulation.atomsStride!
    encoder.setBytes(&arguments, length: 12, index: 0)
    encoder.setBuffer(simulation.cumulativeSumBuffer, offset: 0, index: 1)
    return encoder
  }
  
  func storeFrameAsync(simulation: MRSimulation) {
    let frameID = simulation.frameID
    let frame = simulation.frames[frameID]
    precondition(frame.atoms.count == simulation.maxAtomsPerBatch.count)
    precondition(frame.metadata.count == simulation.maxAtomsPerBatch.count)
    
    let frameBuffer = simulation.frameBuffers[frameID % 8]
    let atomsBuffer = simulation.atomsBuffers[frameID % 8]
    var cursor = frameBuffer.contents()
    
    let header = cursor.assumingMemoryBound(to: MRSimulation.FrameHeader.self)
    header.pointee = .init(frameID: frameID)
    cursor += MemoryLayout<MRSimulation.FrameHeader>.stride
    
    for i in 0..<frame.atoms.count {
      let mask = cursor.assumingMemoryBound(to: UInt8.self)
      let count = frame.atoms[i].count
      if count == 0 {
        mask.pointee = 0
      } else {
        precondition(count == simulation.maxAtomsPerBatch[i])
        mask.pointee = 1
      }
      cursor += 1
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
      precondition(metadata.count <= simulation.maxFrameMetadataSize)
      guard metadata.count > 0 else {
        continue
      }
      
      metadata.copyBytes(
        to: cursor.assumingMemoryBound(to: UInt8.self), count: metadata.count)
    }
    
    memset(cursor, 0, missingDataBytes)
    
    alignCursor(&cursor, frameBuffer: frameBuffer)
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = startEncoder(commandBuffer, simulation: simulation)
    encoder.setComputePipelineState(serializePipeline)
    encoder.setBuffer(atomsBuffer, offset: 0, index: 2)
    encoder.setBuffer(frameBuffer, offset: 0, index: 3)
    
    var atomsCursor = atomsBuffer.contents()
    let cursorStart = frameBuffer.contents()
    let atomsStart = atomsBuffer.contents()
    for i in 0..<frame.atoms.count {
      let numAtoms = simulation.maxAtomsPerBatch[i]
      defer {
        atomsCursor += ((numAtoms + 7) / 8 * 8) * 16
      }
      guard frame.atoms[i].count > 0 else {
        continue
      }
      memcpy(atomsCursor, frame.atoms[i], numAtoms * 16)
      
      encoder.setBufferOffset(atomsCursor - atomsStart, index: 1)
      encoder.setBufferOffset(atomsCursor - atomsStart, index: 2)
      encoder.setBufferOffset(cursor - cursorStart, index: 3)
      encoder.dispatchThreads(
        MTLSizeMake(numAtoms, 1, 1),
        threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
      
      cursor += numAtoms * MemoryLayout<UInt32>.stride
    }
    encoder.endEncoding()
    
    let workItem = { [self, simulation] in
      var succeeded = false
      while !succeeded {
        framesQueue.sync {
          let currentFrameID = simulation.finishedFrameID
          if currentFrameID > frameID {
            fatalError("This should never happen.")
          }
          if currentFrameID < frameID {
            return
          }
          succeeded = true
          simulation.finishedFrameID += 1
          
          precondition(frameBuffer.length == simulation.frameStride!)
          //          memset(frameBuffer.contents() + 4, 0, frameBuffer.length - 4)
//          MTLIOCompressionContextAppendData(
//            simulation.context!,
//            frameBuffer.contents(),
//            simulation.frameStride!)
          
//          simulation.context!.0
//            .append(contentsOf: Data(
//              bytes: frameBuffer.contents(), count: simulation.frameStride!))
          
          simulation.semaphores[frameID % 8].signal()
        }
        if !succeeded {
          usleep(50)
        }
      }
    }
    commandBuffer.addCompletedHandler { _ in
      self.asyncQueue.async(execute: workItem)
    }
//    commandBuffer.addCompletedHandler { _ in
//      simulation.semaphores[frameID % 8].signal()
//    }
    commandBuffer.commit()
    
    do {
      // This is a short-term fix to avoid a race condition. Eventually, we should
      // either buffer up a large amount of data in RAM and move through the SSD
      // in chunks, or use Apple's "Compression" library directly.
      commandBuffer.waitUntilCompleted()
      simulation.context!.append(buffer: frameBuffer)
    }
  }
  
  func loadFrameAsync(simulation: MRSimulation) {
    let frameID = simulation.frameID
    let frameBuffer = simulation.frameBuffers[frameID % 8]
    let atomsBuffer = simulation.atomsBuffers[frameID % 8]
    
    let ioCommandBuffer = ioCommandQueue.makeCommandBuffer()
    ioCommandBuffer.loadBytes(
      frameBuffer.contents(), size: simulation.frameStride!,
      sourceHandle: simulation.fileHandle!,
      sourceHandleOffset: 65536 + frameID * simulation.frameStride!)
    
    let workItem = { [self, simulation] in
      print("Finished MTLIOCommandBuffer \(frameID)")
      var cursor = frameBuffer.contents()
      
      let header = cursor.assumingMemoryBound(to: MRSimulation.FrameHeader.self)
      precondition(header.pointee.frameID == frameID)
      cursor += MemoryLayout<MRSimulation.FrameHeader>.stride
      
      let batchSize = simulation.maxAtomsPerBatch.count
      var mask = [UInt8](repeating: 0, count: batchSize)
      memcpy(&mask, cursor, batchSize)
      cursor += batchSize
      
      var metadata: [Data] = []
      for i in 0..<batchSize {
        if mask[i] == 0 {
          metadata.append(Data())
        } else {
          let data = Data(bytes: cursor, count: simulation.maxFrameMetadataSize)
          metadata.append(data)
          cursor += simulation.maxFrameMetadataSize
        }
      }
      
      alignCursor(&cursor, frameBuffer: frameBuffer)
      
      
      
      var commandBuffer: MTLCommandBuffer?
      var succeeded = false
      while !succeeded {
        framesQueue.sync {
          let currentFrameID = simulation.finishedFrameID
          if currentFrameID > frameID {
            fatalError("This should never happen.")
          }
          if currentFrameID < frameID {
            return
          }
          succeeded = true
          simulation.finishedFrameID += 1
          
          commandBuffer = commandQueue.makeCommandBuffer()
          commandBuffer!.enqueue()
        }
        if !succeeded {
          usleep(50)
        }
      }
      
      let encoder = startEncoder(commandBuffer!, simulation: simulation)
      encoder.setComputePipelineState(deserializePipeline)
      encoder.setBuffer(atomsBuffer, offset: 0, index: 2)
      encoder.setBuffer(frameBuffer, offset: 0, index: 3)
      
      var atomsCursor = atomsBuffer.contents()
      let cursorStart = frameBuffer.contents()
      let atomsStart = atomsBuffer.contents()
      for i in 0..<batchSize {
        let numAtoms = simulation.maxAtomsPerBatch[i]
        defer {
          atomsCursor += ((numAtoms + 7) / 8 * 8) * 16
        }
        guard mask[i] > 0 else {
          continue
        }
        
        encoder.setBufferOffset(atomsCursor - atomsStart, index: 1)
        encoder.setBufferOffset(atomsCursor - atomsStart, index: 2)
        encoder.setBufferOffset(cursor - cursorStart, index: 3)
        encoder.dispatchThreads(
          MTLSizeMake(numAtoms, 1, 1),
          threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
        
        cursor += numAtoms * MemoryLayout<UInt32>.stride
      }
      encoder.endEncoding()
      
      let workItem = { [self, simulation] in
        print("Finished MTLCommandBuffer \(frameID)")
        var atoms: [[MRAtom]] = []
        atomsCursor = atomsBuffer.contents()
        
        
        for i in 0..<batchSize {
          let numAtoms = simulation.maxAtomsPerBatch[i]
          defer {
            atomsCursor += (numAtoms + 7) / 8 * 8 * 16
          }
          
          if mask[i] == 0 {
            atoms.append([])
          } else {
            atoms.append(Array(unsafeUninitializedCapacity: numAtoms) {
              memcpy($0.baseAddress!, atomsCursor, numAtoms * 16)
              $1 = numAtoms
            })
          }
        }
        
        let frame = MRFrame(atoms: atoms, metadata: metadata)
        framesQueue.sync {
          simulation.frames[frameID] = frame
        }
        simulation.semaphores[frameID % 8].signal()
      }
      commandBuffer!.addCompletedHandler { _ in
        self.asyncQueue.async(execute: workItem)
      }
      
      print("Started MTLCommandBuffer \(frameID)")
      commandBuffer!.commit()
    }
    ioCommandBuffer.addCompletedHandler { _ in
      self.asyncQueue.async(execute: workItem)
    }
    
    print("Started MTLIOCommandBuffer \(frameID)")
    ioCommandBuffer.commit()
  }
}

/// Rounds an integer up to the nearest power of 2.
fileprivate func roundUpToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - max(0, input - 1).leadingZeroBitCount)
}

/// Rounds an integer down to the nearest power of 2.
fileprivate func roundDownToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - 1 - input.leadingZeroBitCount)
}

// TODO: Metal fast resource loading is bugged out right now. Use
// 'compression_context' for all loading operations, and eventually use a custom
// resource loader instead of Metal's one.
//
// TODO: Measure disk memory consumption in FP32, UInt32, and then finally
// cumulative-summed.
//
// TODO: Test the difference in memory consumption with different precisions.
class MRCompressionContext {
  var compressedData: UnsafeMutableBufferPointer<UInt8>
  var uncompressedBytes: Int = 0
  var cursor: Int = 0
  var url: URL
  var method: MRCompressionMethod
  
  var stream: compression_stream
  var blockSize: Int
  var scratchBuffer: UnsafeMutableBufferPointer<UInt8>
  
  init(url: URL, method: MRCompressionMethod) {
    self.compressedData = .allocate(capacity: 0)
    self.url = url
    self.method = method
    self.stream = withUnsafeTemporaryAllocation(
      of: compression_stream.self, capacity: 1
    ) {
      return $0[0]
    }
    
    let status = compression_stream_init(
      &stream, COMPRESSION_STREAM_ENCODE, method.compressionAlgorithm)
    precondition(status == COMPRESSION_STATUS_OK)
    self.blockSize = 1024 * 1024
    self.scratchBuffer = .allocate(capacity: blockSize)
  }
  
  deinit {
    compressedData.deallocate()
    scratchBuffer.deallocate()
  }
  
  func append(header: UnsafeMutableRawPointer) {
    append(UnsafeRawPointer(header), count: 65536)
  }
  
  func append(buffer: MTLBuffer) {
    append(buffer.contents(), count: buffer.length)
  }
  
  // Returns whether you should keep copying more data.
  private func copyScratchBuffer() -> Bool {
    let writtenBytes = blockSize - stream.dst_size
    guard writtenBytes > 0 else {
      return false
    }
    
    var nextCount = cursor + writtenBytes
    if compressedData.count < nextCount {
      let previous = compressedData
      nextCount = roundUpToPowerOf2(nextCount)
      compressedData = .allocate(capacity: nextCount)
      memcpy(
        compressedData.baseAddress!,
        previous.baseAddress!, cursor)
    }
    
    precondition(compressedData.count >= nextCount)
    memcpy(
      compressedData.baseAddress! + cursor,
      scratchBuffer.baseAddress!, writtenBytes)
    cursor += writtenBytes
    
    if writtenBytes < blockSize {
      return false
    } else {
      return true
    }
  }
  
  private func append(_ pointer: UnsafeRawPointer, count: Int) {
    uncompressedBytes += count
    stream.src_ptr = pointer.assumingMemoryBound(to: UInt8.self)
    stream.src_size = count
    
    while true {
      stream.dst_ptr = scratchBuffer.baseAddress!
      stream.dst_size = scratchBuffer.count
      
      let status = compression_stream_process(&stream, 0)
      precondition(status == COMPRESSION_STATUS_OK)
      guard copyScratchBuffer() else {
        break
      }
    }
  }
  
  func destroy() {
    do {
      stream.dst_ptr = scratchBuffer.baseAddress!
      stream.dst_size = scratchBuffer.count
      
      let finalizeFlag = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
      let status = compression_stream_process(&stream, finalizeFlag)
      precondition(status == COMPRESSION_STATUS_END)
      
      // The assumption that FINALIZE bytes < block size may be incorrect.
      precondition(copyScratchBuffer() == false)
    }
    compression_stream_destroy(&stream)
    
    let ratio = Float(cursor) / Float(uncompressedBytes)
    let ratioRepr = String(format: "%.1f", 100 * ratio)
    print("Compressed bytes:", compressedData.count)
    print("Compression ratio: \(ratioRepr)% (lower is better)")
    
    let context = MTLIOCreateCompressionContext(
      url.path, method.ioMethod, 65536)!
    let status = compression_stream_init(
      &stream, COMPRESSION_STREAM_DECODE, method.compressionAlgorithm)
    precondition(status == COMPRESSION_STATUS_OK)
    defer {
      compression_stream_destroy(&stream)
    }
    
    do {
      stream.src_ptr = .init(compressedData.baseAddress!)
      stream.src_size = cursor
      
      var offset = 0
      while true {
        let scratch = scratchBuffer.baseAddress!
        stream.dst_ptr = scratch
        stream.dst_size = scratchBuffer.count
        
        let status = compression_stream_process(&stream, 0)
        precondition(status == COMPRESSION_STATUS_OK)
        let readBytes = blockSize - stream.dst_size
        guard readBytes > 0 else {
          break
        }
        
        if offset == 0 {
          let rawPointer = UnsafeMutableRawPointer(scratch)
          let headerPointer = rawPointer.assumingMemoryBound(
            to: MRSimulation.SimulationHeader.self)
          print(headerPointer.pointee)
          
        }
        offset += readBytes
        
        MTLIOCompressionContextAppendData(context, scratch, readBytes)
        if readBytes < blockSize {
          break
        }
      }
    }
    
    let ioStatus = MTLIOFlushAndDestroyCompressionContext(context)
    precondition(ioStatus == .complete, "Error destroying IO context.")
  }
}



