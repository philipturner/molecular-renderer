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
// Encoding:
//   MRAtom -> GPU Intermediate -> LZBITMAP
// Decoding:
//   LZBITMAP -> GPU Intermediate -> MRAtom

/// Rounds an integer up to the nearest power of 2.
fileprivate func roundUpToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - max(0, input - 1).leadingZeroBitCount)
}

/// Rounds an integer down to the nearest power of 2.
fileprivate func roundDownToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - 1 - input.leadingZeroBitCount)
}

public enum NewMRCompressionAlgorithm {
  // LZBITMAP compression with block size 65536.
  case lzBitmap
  
  init<T: StringProtocol>(name: T) {
    if name == "LZBITMAP" {
      self = .lzBitmap
    } else {
      fatalError("Unrecognized algorithm: \(name)")
    }
  }
  
  var compressionAlgorithm: compression_algorithm {
    switch self {
    case .lzBitmap:
      return COMPRESSION_LZBITMAP
    }
  }
  
  var name: StaticString {
    switch self {
    case .lzBitmap:
      return StaticString("LZBITMAP")
    }
  }
}

public struct NewMRFrame {
  public var atoms: [MRAtom]
  public var metadata: [UInt8]
  
  public init(atoms: [MRAtom], metadata: [UInt8]) {
    self.atoms = atoms
    self.metadata = metadata
  }
  
  public init(atoms: [MRAtom]) {
    self.init(atoms: atoms, metadata: [])
  }
}

public class NewMRSimulation {
  public internal(set) var frameTimeInFs: Double
  
  // Data can be compressed with higher efficiency by dropping several bits off
  // the mantissa. If an atom moves 0.008 nm/frame, here are bits/position
  // component at reasonable precisions:
  // - 6 bits: 0.25 pm
  // - 5 bits: 0.5 pm
  // - 4 bits: 1 pm
  // - 3 bits: 2 pm
  public internal(set) var resolutionInApproxPm: Double
  public internal(set) var algorithm: NewMRCompressionAlgorithm
  public internal(set) var clusterBlockSize: Int = 65536
  public internal(set) var usesCheckpoints: Bool = false
  
  public internal(set) var frameCount: Int = 0
  public internal(set) var clusterSize: Int
  public internal(set) var clusterCompressedOffsets: [Int] = []
  public var clustersTotalSize: Int = 0
  public internal(set) var staticMetadata: [UInt8] = []
  
  var renderer: MRRenderer
  fileprivate var compressedData: ExpandingBuffer
  fileprivate var swapchain: Swapchain
  fileprivate var activeCluster: Cluster
  var activeClusterIndex: Int = -1
  
  // NOTE: The C API will not have default arguments, so LZBITMAP won't
  // automatically become the default on non-Apple platforms.
  public init(
    renderer: MRRenderer,
    frameTimeInFs: Double,
    resolutionInApproxPm: Double = 0.25,
    clusterSize: Int = 30,
    algorithm: NewMRCompressionAlgorithm = .lzBitmap
  ) {
    self.renderer = renderer
    self.frameTimeInFs = frameTimeInFs
    self.resolutionInApproxPm = resolutionInApproxPm
    self.clusterSize = clusterSize
    self.algorithm = algorithm
    
    let device = renderer.device
    self.compressedData = ExpandingBuffer(device: device)
    self.swapchain = Swapchain(device: device)
    self.activeCluster = swapchain.newCluster(frameStart: 0)
  }
  
  public func append(_ frame: NewMRFrame) {
    frameCount += 1
    if frameCount % clusterSize == 0 {
      encodeActiveCluster()
      activeCluster = swapchain.newCluster(frameStart: frameCount)
    }
    activeCluster.append(frame)
  }
  
  public func frame(id: Int) -> NewMRFrame {
    let desiredClusterIndex = id / clusterSize
    if desiredClusterIndex != activeClusterIndex {
      activeCluster = swapchain.newCluster(frameStart: frameCount)
      decodeActiveCluster()
    }
    return activeCluster.makeFrame(frameID: id)
  }
  
  public func save(url: URL) {
    encodeActiveCluster()
    
    // Decoding will use a similar method, which generates words upon each call.
    var header = ExpandingBuffer(device: renderer.device)
    var headerWords: [UInt64] = []
    func appendHeaderWords() {
      header.reserve(headerWords.count * 8)
      header.write(headerWords.count * 8, source: headerWords)
      headerWords.removeAll(keepingCapacity: true)
    }
    
    // frameTimeInFs, resolutionInApproxPm
    do {
      headerWords.append(frameTimeInFs.bitPattern)
      headerWords.append(resolutionInApproxPm.bitPattern)
      appendHeaderWords()
    }
    
    // algorithm
    do {
      header.reserve(128)
      memset(header.buffer.contents() + header.cursor, 0, 128)
      
      let nextCursor = header.cursor + 128
      algorithm.name.withUTF8Buffer {
        header.write($0.count, source: $0.baseAddress!)
      }
      let pointer = OpaquePointer(header.buffer.contents() + nextCursor - 128)
      print(String(cString: UnsafePointer<CChar>(pointer)))
      
      header.cursor = nextCursor
    }
    
    // blockSize, usesCheckpoints, frameCount, clusterBlockSize
    do {
      let clusterCount = (frameCount + clusterSize - 1) / clusterSize
      precondition(clusterCount == clusterCompressedOffsets.count)
      
      headerWords.append(UInt64(clusterBlockSize))
      headerWords.append(usesCheckpoints ? 1 : 0)
      headerWords.append(UInt64(frameCount))
      headerWords.append(UInt64(clusterSize))
      appendHeaderWords()
    }
    
    // clusterCompressedOffsets, clustersTotalSize, staticMetadata.count
    do {
      headerWords = clusterCompressedOffsets.map(UInt64.init)
      headerWords.append(UInt64(clustersTotalSize))
      headerWords.append(UInt64(staticMetadata.count))
      appendHeaderWords()
    }
    
    // compressed staticMetadata count, staticMetadata
    if staticMetadata.count > 0 {
      var dst = UnsafeMutablePointer<UInt8>
        .allocate(capacity: staticMetadata.count)
      defer { dst.deallocate() }
      
      let compressedBytes = compression_encode_buffer(
        dst, staticMetadata.count,
        staticMetadata, staticMetadata.count,
        nil, algorithm.compressionAlgorithm)
      guard compressedBytes > 0 else {
        fatalError("Error occurred during encoding.")
      }
      
      headerWords.append(UInt64(compressedBytes))
      appendHeaderWords()
      
      header.reserve(compressedBytes)
      header.write(compressedBytes, source: dst)
    }
    
    // padding
    let paddedSize = (header.cursor + 127) / 128 * 128
    let padding = paddedSize - header.cursor
    if padding > 0 {
      header.reserve(padding)
      memset(header.buffer.contents() + header.cursor, 0, padding)
      header.cursor += padding
    }
    
    var data = Data(
      bytes: header.buffer.contents(), count: header.cursor)
    data += Data(
      bytes: compressedData.buffer.contents(), count: compressedData.cursor)
    
    precondition(
      FileManager.default.createFile(atPath: url.path, contents: data),
      "Could not write to the file.")
  }
  
  public init(renderer: MRRenderer, url: URL) {
    guard let contents = FileManager.default.contents(atPath: url.path) else {
      fatalError("Could not open file at path: '\(url.path)'")
    }
    let contentsPointer = contents.withUnsafeBytes {
      let pointer = malloc($0.count)
      memcpy(pointer, $0.baseAddress!, $0.count)
      return UnsafeRawBufferPointer(start: pointer, count: $0.count)
    }
    defer { contentsPointer.deallocate() }
    
    var cursor = contentsPointer.baseAddress!
    func checkCapacity(_ bytesToRead: Int) {
      let pointer = cursor + bytesToRead - contentsPointer.baseAddress!
      precondition(pointer <= contentsPointer.count)
    }
    func extractHeaderWords(_ expectedCount: Int) -> [UInt64] {
      checkCapacity(expectedCount * 8)
      var output: [UInt64] = .init(repeating: 0, count: expectedCount)
      memcpy(&output, cursor, expectedCount * 8)
      cursor += expectedCount * 8
      return output
    }
    
    // frameTimeInFs, resolutionInApproxPm
    do {
      let headerWords = extractHeaderWords(2)
      frameTimeInFs = Double(bitPattern: headerWords[0])
      resolutionInApproxPm = Double(bitPattern: headerWords[1])
    }
    
    // algorithm
    do {
      checkCapacity(128)
      let name = String(
        cString: UnsafePointer<CChar>(OpaquePointer(cursor)))
      algorithm = .init(name: name)
      cursor += 128
    }
    
    // blockSize, usesCheckpoints, frameCount, clusterBlockSize
    do {
      let headerWords = extractHeaderWords(4)
      clusterBlockSize = Int(headerWords[0])
      precondition(headerWords[1] <= 1)
      usesCheckpoints = headerWords[1] > 0
      frameCount = Int(headerWords[2])
      clusterSize = Int(headerWords[3])
      
      print("Decoded frame count: \(frameCount)")
    }
    
    // clusterCompressedOffsets, clustersTotalSize, staticMetadata.count
    var staticMetadataCount: Int
    do {
      let clusterCount = (frameCount + clusterSize - 1) / clusterSize
      let headerWords = extractHeaderWords(clusterCount + 2)
      clusterCompressedOffsets = headerWords[..<clusterCount].map(Int.init)
      clustersTotalSize = Int(headerWords[clusterCount])
      staticMetadataCount = Int(headerWords[clusterCount + 1])
    }
    
    // compressed staticMetadata count, staticMetadata
    if staticMetadataCount > 0 {
      let headerWords = extractHeaderWords(1)
      let compressedCount = Int(headerWords[0])
      precondition(compressedCount > 0)
      
      checkCapacity(compressedCount)
      var dst = UnsafeMutablePointer<UInt8>
        .allocate(capacity: staticMetadataCount)
      defer { dst.deallocate() }
      
      let uncompressedBytes = compression_decode_buffer(
        dst, staticMetadataCount,
        cursor, compressedCount,
        nil, algorithm.compressionAlgorithm)
      guard uncompressedBytes == staticMetadataCount else {
        fatalError("Error occurred while decoding.")
      }
      cursor += compressedCount
      
      staticMetadata = Array(unsafeUninitializedCapacity: staticMetadataCount) {
        $1 = staticMetadataCount
        memcpy($0.baseAddress!, dst, staticMetadataCount)
      }
    } else {
      staticMetadata = []
    }
    
    var cursorDelta = cursor - contentsPointer.baseAddress!
    cursorDelta = (cursorDelta + 127) / 128 * 128
    precondition(cursorDelta + clustersTotalSize == contentsPointer.count)
    cursor = contentsPointer.baseAddress! + cursorDelta
    
    let device = renderer.device
    self.renderer = renderer
    self.compressedData = ExpandingBuffer(device: device)
    self.swapchain = Swapchain(device: device)
    self.activeCluster = swapchain.newCluster(frameStart: 0)
    
    compressedData.reserve(clustersTotalSize)
    compressedData.write(clustersTotalSize, source: cursor)
  }
  
  func encodeActiveCluster() {
    let totalAtoms = Int(activeCluster.atomsOffsets.last!)
    do {
      let component = activeCluster.compressedMetadata
      let uncompressed = component.uncompressed
      precondition(uncompressed.cursor == 0)
      
      let size = activeCluster.compressedTailStart + totalAtoms * 2
      uncompressed.reserve(size)
    }
    for component in [
      activeCluster.compressedX,
      activeCluster.compressedY,
      activeCluster.compressedZ
    ] {
      let uncompressed = component.uncompressed
      precondition(uncompressed.cursor == 0)
      
      let size = totalAtoms * 4
      uncompressed.reserve(size)
    }
    processAtoms(encode: true)
    
    DispatchQueue.concurrentPerform(iterations: 4) { [self] z in
      var component: Component
      switch z {
      case 0: component = activeCluster.compressedMetadata
      case 1: component = activeCluster.compressedX
      case 2: component = activeCluster.compressedY
      case 3: component = activeCluster.compressedZ
      default: fatalError()
      }
      
      let uncompressed = component.uncompressed
      var bytesToWrite: Int
      if z == 0 {
        let frameCount = activeCluster.frameCount
        uncompressed.write(frameCount * 4, source: activeCluster.atomsCounts)
        uncompressed.write(frameCount * 4, source: activeCluster.metadataCounts)
        
        let metadataSize = Int(activeCluster.metadataOffsets.last!)
        let metadataSource = activeCluster.metadata.buffer.contents()
        uncompressed.write(metadataSize, source: metadataSource)
        precondition(activeCluster.metadata.cursor == metadataSize)
        
        precondition(uncompressed.cursor == activeCluster.compressedTailStart)
        bytesToWrite = uncompressed.cursor + totalAtoms * 2
        uncompressed.cursor = 0
      } else {
        bytesToWrite = totalAtoms * 4
      }
      
      var src_ptr = uncompressed.buffer.contents()
      var src_size = bytesToWrite
      
      precondition(component.compressed.cursor == 0)
      precondition(component.scratch.cursor == 0)
      let scratchSize = compression_encode_scratch_buffer_size(
        algorithm.compressionAlgorithm)
      component.scratch.reserve(scratchSize)
      let scratch_ptr = component.scratch.buffer.contents()
      
      while src_size > 0 {
        let compressed = component.compressed
        compressed.reserve(65536)
        let dst_ptr = 2 + compressed.buffer.contents() + compressed.cursor
        
        let compressedBytes = compression_encode_buffer(
          .init(OpaquePointer(dst_ptr)), 65536,
          .init(OpaquePointer(src_ptr)), min(src_size, 65536),
          scratch_ptr, algorithm.compressionAlgorithm)
        guard compressedBytes > 0 else {
          fatalError("Error occurred during encoding.")
        }
        
        var header = UInt16(compressedBytes - 1)
        compressed.write(2, source: &header)
        compressed.cursor += compressedBytes
        src_ptr += 65536
        src_size -= 65536
      }
    }
    
    let metadata = activeCluster.compressedMetadata.compressed
    let x = activeCluster.compressedX.compressed
    let y = activeCluster.compressedY.compressed
    let z = activeCluster.compressedZ.compressed
    
    var header: [Int] = [
      activeCluster.frameStart,
      activeCluster.frameStart + Int(UInt(activeCluster.frameCount - 1)),
    ]
    var totalBytes = 0
    totalBytes += metadata.cursor
    header.append(totalBytes)
    totalBytes += x.cursor
    header.append(totalBytes)
    totalBytes += y.cursor
    header.append(totalBytes)
    totalBytes += z.cursor
    header.append(totalBytes)
    
    clusterCompressedOffsets.append(compressedData.cursor)
    clustersTotalSize = compressedData.cursor
    
    compressedData.reserve(header.count * 8)
    compressedData.write(header.count * 8, source: header)
    
    compressedData.reserve(totalBytes)
    compressedData.write(metadata.cursor, source: metadata.buffer.contents())
    compressedData.write(x.cursor, source: x.buffer.contents())
    compressedData.write(y.cursor, source: y.buffer.contents())
    compressedData.write(z.cursor, source: z.buffer.contents())
  }
  
  func decodeActiveCluster() {
    let compressedOffset = clusterCompressedOffsets[activeClusterIndex]
    compressedData.cursor = compressedOffset
    
    func extractHeaderWords(_ expectedCount: Int) -> [UInt64] {
      var output: [UInt64] = .init(repeating: 0, count: expectedCount)
      let readBytes = compressedData.read(
        expectedCount * 8, destination: &output)
      precondition(readBytes == expectedCount * 8)
      return output
    }
    
    let headerWords = extractHeaderWords(6)
    let frameStart = Int(headerWords[0])
    let frameEnd = Int(headerWords[1])
    precondition(frameStart == activeClusterIndex * clusterSize)
    
    let expectedEnd = min(frameStart + clusterSize, frameCount)
    precondition(frameEnd == expectedEnd)
    
    let metadataCeil = Int(headerWords[2])
    let xCeil = Int(headerWords[3])
    let yCeil = Int(headerWords[4])
    let zCeil = Int(headerWords[5])
    
    let metadataRange = 0..<metadataCeil
    let xRange = metadataCeil..<xCeil
    let yRange = xCeil..<yCeil
    let zRange = yCeil..<zCeil
    
    func reserve(_ component: Component, _ range: Range<Int>) {
      component.uncompressed.reserve(range.upperBound - range.lowerBound)
    }
    reserve(activeCluster.compressedMetadata, metadataRange)
    reserve(activeCluster.compressedX, xRange)
    reserve(activeCluster.compressedY, yRange)
    reserve(activeCluster.compressedZ, zRange)
    
    DispatchQueue.concurrentPerform(iterations: 4) { [self] z in
      var component: Component
      switch z {
      case 0: component = activeCluster.compressedMetadata
      case 1: component = activeCluster.compressedX
      case 2: component = activeCluster.compressedY
      case 3: component = activeCluster.compressedZ
      default: fatalError()
      }
      precondition(component.compressed.cursor == 0)
      precondition(component.uncompressed.cursor == 0)
      precondition(component.scratch.cursor == 0)
      
      var src = compressedData.buffer.contents() + compressedOffset
      var range: Range<Int>
      switch z {
      case 0: range = metadataRange
      case 1: range = xRange
      case 2: range = yRange
      case 3: range = zRange
      default: fatalError()
      }
      src += range.lowerBound
      
      let compressed = component.compressed
      var src_size = range.upperBound - range.lowerBound
      compressed.write(src_size, source: src)
      
      let scratchSize = compression_decode_scratch_buffer_size(
        algorithm.compressionAlgorithm)
      component.scratch.reserve(scratchSize)
      let scratch_ptr = component.scratch.buffer.contents()
      
      while src_size > 0 {
        let uncompressed = component.uncompressed
        uncompressed.reserve(65536)
        
        var header: UInt16 = 0
        let readBytes = compressed.read(2, destination: &header)
        precondition(readBytes == 2)
        
        let compressedBytes = Int(header) + 1
        let src_ptr = compressed.buffer.contents() + compressed.cursor
        let dst_ptr = uncompressed.buffer.contents() + uncompressed.cursor
        
        let uncompressedBytes = compression_decode_buffer(
          .init(OpaquePointer(dst_ptr)), 65536,
          .init(OpaquePointer(src_ptr)), compressedBytes,
          scratch_ptr, algorithm.compressionAlgorithm)
        guard uncompressedBytes > 0 else {
          fatalError("Error occurred during encoding.")
        }
        
        compressed.cursor += compressedBytes
        uncompressed.cursor += uncompressedBytes
        src_size = range.upperBound - range.lowerBound
        src_size -= compressed.cursor
      }
    }
    
    // TODO: After decompressing on 4 threads, parse the compressed header.
    // Then, decode on the GPU.
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
    withUnsafeTemporaryAllocation(
      of: SIMD2<UInt32>.self, capacity: activeCluster.frameCount
    ) { bufferPointer in
      for i in 0..<bufferPointer.count {
        bufferPointer[i] = SIMD2(atomsCounts[0], atomsCounts[1])
      }
      
      let frameRangesBytes = bufferPointer.count * 8
      encoder.setBytes(
        bufferPointer.baseAddress!, length: frameRangesBytes, index: 1)
    }
    
    encoder.setBuffer(activeCluster.atoms.buffer, offset: 0, index: 2)
    encoder.setBuffer(
      activeCluster.compressedMetadata.uncompressed.buffer,
      offset: activeCluster.compressedTailStart, index: 3)
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
  var scratch: ExpandingBuffer
  
  init(device: MTLDevice) {
    self.device = device
    self.compressed = ExpandingBuffer(device: device)
    self.uncompressed = ExpandingBuffer(device: device)
    self.scratch = ExpandingBuffer(device: device)
  }
  
  func reset() {
    compressed.cursor = 0
    uncompressed.cursor = 0
  }
}

// First-level, uncompressed header stores:
// (a) frame start and end, inclusive
// (b) offset of each component
//
// Second-level, compressed header stores:
// (a) number of atoms in each frame
// (b) metadata size for each frame
// (c) metadata for each frame
fileprivate class Cluster {
  var frameStart: Int
  var frameCount: Int
  var atomsCounts: [UInt32]
  var metadataCounts: [UInt32]
  var atomsOffsets: [UInt32]
  var metadataOffsets: [UInt32]
  
  var compressedMetadata: Component
  var compressedTailStart: Int {
    frameCount * 8 + Int(metadataOffsets.last!)
  }
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
    
    frameCount += 1
    precondition(frameCount == atomsCounts.count)
    precondition(frameCount + 1 == atomsOffsets.count)
    precondition(frameCount == metadataCounts.count)
    precondition(frameCount + 1 == metadataOffsets.count)
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
  // the CPU to see this frame's atoms.
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

// Preparation for when the serializer actually becomes GPU-accelerated.
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

