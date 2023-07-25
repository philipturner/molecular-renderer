//
//  MRSimulation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/23/23.
//

import Metal

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
  // the mantissa. If an atom moves 0.25 nm/frame, here are bits/position
  // component at specific precisions:
  // - 9 bits: 1 pm
  // - 8 bits: 2 pm
  // - 7 bits: 4 pm
  // - 6 bits: 8 pm
  // - 5 bits: 16 pm
  // - 4 bits: 33 pm
  // - 3 bits: 63 pm
  // - 2 bits: 125 pm
  // - 1 bit:  250 pm
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
  var method: MTLIOCompressionMethod?
//  var context: MTLIOCompressionContext?
  var context: (Data, URL)?
  var frameStride: Int?
  var atomsStride: Int?
  
  var framesInFlight: [Bool] = []
  var semaphores: [DispatchSemaphore] = []
  var ioCommandBuffers: [MTLIOCommandBuffer?] = []
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
    initializeFile(
      renderer: renderer, url: url, method: method, serializing: false)
    renderer.serializer.loadHeader(simulation: self)
    initializeFrameBuffers(renderer: renderer)
    
    stream {
      renderer.serializer.loadFrameAsync(simulation: self)
    }
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
    initializeFrameBuffers(renderer: renderer)
    initializeFile(
      renderer: renderer, url: url, method: method, serializing: true)
    
    let path = url.absoluteURL.path
//    context = MTLIOCreateCompressionContext(path, self.method!, 65536)!
    context = (Data(count: 0), URL(filePath: path))
    defer {
//      let status = MTLIOFlushAndDestroyCompressionContext(context!)
//      guard status == .complete else {
//        fatalError("Could not flush and destroy compression context.")
//      }
      let (data, url) = context!
      try! data.write(to: url, options: .atomic)
      context = nil
    }
    renderer.serializer.storeHeader(simulation: self)
    
    stream {
      renderer.serializer.storeFrameAsync(simulation: self)
    }
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
    ioCommandBuffers = Array(repeating: nil, count: 8)
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
  
  func initializeFile(
    renderer: MRRenderer,
    url: URL,
    method: MRCompressionMethod,
    serializing: Bool
  ) {
    var ioMethod: MTLIOCompressionMethod
    switch method {
    case .lzBitmap:
      ioMethod = .lzBitmap
//      ioMethod = .none
    }
    self.method = ioMethod
    
    if !serializing {
      fileHandle = try! renderer.device.makeIOHandle(
        url: url)//, compressionMethod: ioMethod)
    }
  }
  
  func stream(_ closure: () -> Void) {
    func maybeWait() {
      if framesInFlight[frameID % 8] {
        ioCommandBuffers[frameID % 8]!.waitUntilCompleted()
        ioCommandBuffers[frameID % 8] = nil
        semaphores[frameID % 8].wait()
      }
    }
    
    while frameID < frames.count {
      maybeWait()
      closure()
      
      framesInFlight[frameID % 8] = true
      frameID += 1
    }
    while frameID < frames.count + 8 {
      maybeWait()
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
    desc.maxCommandsInFlight = 8
    desc.maxCommandBufferCount = 8
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
    
    simulation.context!.0
      .append(contentsOf: Data(bytes: bytes, count: 65536))
//    MTLIOCompressionContextAppendData(
//      simulation.context!, bytes, cursor - bytes)
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
    encoder.setBuffer(frameBuffer, offset: 0, index: 0)
    encoder.setBuffer(atomsBuffer, offset: 0, index: 2)
    
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
      
      encoder.setBufferOffset(cursor - cursorStart, index: 0)
      encoder.setBufferOffset(atomsCursor - atomsStart, index: 1)
      encoder.setBufferOffset(atomsCursor - atomsStart, index: 2)
      encoder.dispatchThreads(
        MTLSizeMake(numAtoms, 1, 1),
        threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
      
      cursor += numAtoms * MemoryLayout<UInt32>.stride
    }
    encoder.endEncoding()
//    commandBuffer.commit()
//    commandBuffer.waitUntilCompleted()
    
    commandBuffer.addCompletedHandler { [self, simulation] _ in
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
          
          simulation.context!.0
            .append(contentsOf: Data(
              bytes: frameBuffer.contents(), count: simulation.frameStride!))
          
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
    let frameID = simulation.frameID
    let frameBuffer = simulation.frameBuffers[frameID % 8]
    let atomsBuffer = simulation.atomsBuffers[frameID % 8]
    
    let ioCommandBuffer = ioCommandQueue.makeCommandBuffer()
    ioCommandBuffer.loadBytes(
      frameBuffer.contents(), size: simulation.frameStride!,
      sourceHandle: simulation.fileHandle!,
      sourceHandleOffset: 65536 + frameID * simulation.frameStride!)
    
    
    
    ioCommandBuffer.addCompletedHandler { [self, simulation] _ in
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
      encoder.setBuffer(frameBuffer, offset: 0, index: 0)
      encoder.setBuffer(atomsBuffer, offset: 0, index: 2)
      
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
        
        encoder.setBufferOffset(cursor - cursorStart, index: 0)
        encoder.setBufferOffset(atomsCursor - atomsStart, index: 1)
        encoder.setBufferOffset(atomsCursor - atomsStart, index: 2)
        encoder.dispatchThreads(
          MTLSizeMake(numAtoms, 1, 1),
          threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
        
        cursor += numAtoms * MemoryLayout<UInt32>.stride
      }
      encoder.endEncoding()
//    commandBuffer!.commit()
//    commandBuffer!.waitUntilCompleted()
    
      commandBuffer!.addCompletedHandler { [self, simulation] _ in
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
      commandBuffer!.commit()
      print("Committed MTLCommandBuffer \(frameID)")
    }
    
    ioCommandBuffer.commit()
    
    // TODO: Stagger so you explicitly wait on the IO command buffer on the CPU,
    // four frames behind the Metal command buffer.
    //
    // Try that as a last resort. Before doing so, try just sending the
    // completion handler to an asynchronous queue. The queue will be of type
    // "concurrent" and managed by the MRSerializer.
    ioCommandBuffer.waitUntilCompleted()
    simulation.ioCommandBuffers[frameID % 8] = ioCommandBuffer
//    ioCommandBuffer.waitUntilCompleted()
    
//    ioCommandBuffer.commit()
//    print("Committed MTLIOCommandBuffer \(frameID)")
  }
}

