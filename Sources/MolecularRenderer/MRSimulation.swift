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

public enum MRCompressionAlgorithm {
  // High-performance, but only has first-class support on Apple platforms.
  // Reverse-engineered and open-sourced at:
  // https://github.com/eafer/libzbitmap
  case lzBitmap
  
  // High compression ratio, but very slow to decode. Best to use this format
  // for sharing across OS platforms, or sharing over the internet. Then,
  // transcode to LZBITMAP for use in latency-sensitive feedback loops.
  case lzma
  
  init<T: StringProtocol>(name: T) {
    if name == "LZBITMAP" {
      self = .lzBitmap
    } else if name == "LZMA" {
      self = .lzma
    } else {
      fatalError("Unrecognized algorithm: \(name)")
    }
  }
  
  var compressionAlgorithm: compression_algorithm {
    switch self {
    case .lzBitmap:
      return COMPRESSION_LZBITMAP
    case .lzma:
      return COMPRESSION_LZMA
    }
  }
  
  var name: StaticString {
    switch self {
    case .lzBitmap:
      return StaticString("LZBITMAP")
    case .lzma:
      return StaticString("LZMA")
    }
  }
}

public enum MRSimulationFormat {
  case binary
  case plainText
  
  var fileExtension: StaticString {
    switch self {
    case .binary:
      return StaticString("mrsimulation")
    case .plainText:
      return StaticString("mrsimulation-txt")
    }
  }
}

public struct MRFrame {
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

public class MRSimulation {
  public internal(set) var frameTimeInFs: Double
  
  // Data can be compressed with higher efficiency by dropping several bits off
  // the mantissa. If an atom moves 0.008 nm/frame, here are bits/position
  // component at some reasonable precisions:
  // - 6 bits: 0.25 pm (recommended)
  // - 5 bits: 0.5 pm
  // - 4 bits: 1 pm
  // - 3 bits: 2 pm
  public internal(set) var resolutionInApproxPm: Double
  public internal(set) var algorithm: MRCompressionAlgorithm?
  public internal(set) var format: MRSimulationFormat
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
    clusterSize: Int = 128,
    algorithm: MRCompressionAlgorithm? = .lzBitmap,
    format: MRSimulationFormat = .binary
  ) {
    self.renderer = renderer
    self.frameTimeInFs = frameTimeInFs
    self.resolutionInApproxPm = resolutionInApproxPm
    self.clusterSize = clusterSize
    self.algorithm = algorithm
    self.format = format
    
    let device = renderer.device
    self.compressedData = ExpandingBuffer(device: device)
    self.swapchain = Swapchain(device: device)
    self.activeCluster = swapchain.newCluster(frameStart: 0)
  }
  
  public func append(_ frame: MRFrame) {
    activeCluster.append(frame)
    frameCount += 1
    if frameCount % clusterSize == 0 {
      encodeActiveCluster()
      activeCluster = swapchain.newCluster(frameStart: frameCount)
      activeClusterIndex = frameCount / clusterSize
    }
  }
  
  public func frame(id: Int) -> MRFrame {
    let desiredClusterIndex = id / clusterSize
    if desiredClusterIndex != activeClusterIndex {
      activeCluster = swapchain.newCluster(frameStart: frameCount)
      activeClusterIndex = desiredClusterIndex
      decodeActiveCluster()
    }
    return activeCluster.makeFrame(frameID: id)
  }
  
  public func save(url: URL) {
    let path = url.path
    if path.hasSuffix(".mrsim") ||
        path.hasSuffix(".mrsimulation") {
      precondition(
        self.format == .binary, "Attempted to save a text to a binary file.")
    } else if path.hasSuffix(".mrsim-txt") ||
                path.hasSuffix(".mrsimulation-txt") {
      precondition(
        self.format == .plainText, "Attempted to save a binary to a text file.")
    }
    
    if activeCluster.frameCount > 0 {
      encodeActiveCluster()
    }
    
    // Decoding will use a similar method, which generates words upon each call.
    var header = ExpandingBuffer(device: renderer.device)
    var headerWords: [UInt64] = []
    func appendHeaderWords() {
      header.reserve(headerWords.count * 8)
      header.write(headerWords.count * 8, source: headerWords)
      headerWords.removeAll(keepingCapacity: true)
    }
    
    if format == .plainText {
      precondition(
        staticMetadata.count == 0, "No metadata formats recognized yet.")
      
      var yaml = """
      specification:
        - https://github.com/philipturner/molecular-renderer
      
      header:
        frame time in femtoseconds: \(frameTimeInFs)
        spatial resolution in approximate picometers: \(resolutionInApproxPm)
        uses checkpoints: \(usesCheckpoints)
        frame count: \(frameCount)
        frame cluster size: \(clusterSize)
      
      metadata:
      
      
      """
      
      header.reserve(yaml.count)
      yaml.withUTF8 {
        header.write($0.count, source: $0.baseAddress!)
      }
    } else {
      
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
        algorithm!.name.withUTF8Buffer {
          header.write($0.count, source: $0.baseAddress!)
        }
        header.cursor = nextCursor
      }
      
      // usesCheckpoints, frameCount, clusterBlockSize
      do {
        let clusterCount = (frameCount + clusterSize - 1) / clusterSize
        precondition(clusterCount == clusterCompressedOffsets.count)
        
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
          nil, algorithm!.compressionAlgorithm)
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
    }
    
    var data = Data(
      bytes: header.buffer.contents(), count: header.cursor)
    data += Data(
      bytes: compressedData.buffer.contents(), count: compressedData.cursor)
    precondition(compressedData.cursor == clustersTotalSize)
    precondition(
      FileManager.default.createFile(atPath: url.path, contents: data),
      "Could not write to the file.")
  }
  
  public init(renderer: MRRenderer, url: URL) {
    let path = url.path
    if path.hasSuffix(".mrsim") ||
        path.hasSuffix(".mrsimulation") {
      self.format = .binary
    } else if path.hasSuffix(".mrsim-txt") ||
                path.hasSuffix(".mrsimulation-txt") {
      self.format = .plainText
    } else {
      fatalError("Invalid file extension.")
    }
    
    guard let contents = FileManager.default.contents(atPath: path) else {
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
    
    // usesCheckpoints, frameCount, clusterBlockSize
    do {
      let headerWords = extractHeaderWords(3)
      precondition(headerWords[0] <= 1)
      usesCheckpoints = headerWords[0] > 0
      frameCount = Int(headerWords[1])
      clusterSize = Int(headerWords[2])
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
        nil, algorithm!.compressionAlgorithm)
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
      guard self.format == .binary else {
        precondition(
          activeCluster.metadataCounts.allSatisfy { $0 == 0 },
          "No metadata formats recognized yet.")
        
        let actualAtoms = totalAtoms / activeCluster.frameCount
        var yaml: String
        if z == 0 {
          var elements: String = ""
          var flags: String = ""
          let space = Character(" ")
          
          var rawContents = uncompressed.buffer.contents()
          rawContents += activeCluster.compressedTailStart
          let contents = rawContents.assumingMemoryBound(to: UInt16.self)
          
          for i in 0..<actualAtoms {
            var rawTail = contents[i]
            
            var components = unsafeBitCast(rawTail, to: SIMD2<UInt8>.self)
            components = SIMD2(components.y, components.x)
            rawTail = unsafeBitCast(components, to: UInt16.self)
            
            let sign = rawTail & 1
            var tail = Int16(rawTail >> 1)
            tail = (sign > 0) ? -tail : tail
            
            components = unsafeBitCast(tail, to: SIMD2<UInt8>.self)
            elements.append(space)
            elements += String(describing: components[0])
            flags.append(space)
            flags += String(describing: components[1])
          }
          
          yaml = """
              elements:\(elements)
              flags:\(flags)
          
          """
        } else {
          var label: String
          switch z {
          case 1: label = "x coordinates"
          case 2: label = "y coordinates"
          case 3: label = "z coordinates"
          default: fatalError()
          }
          
          yaml = """
              \(label):
          
          """
          let contents = uncompressed.buffer.contents()
            .assumingMemoryBound(to: UInt32.self)
          for i in 0..<actualAtoms {
            var string: String = "      - \(i):"
            let space = Character(" ")
            
            for j in 0..<activeCluster.frameCount {
              let rawPosition = contents[j * actualAtoms + i]
              let sign = rawPosition & 1
              let delta = Int32(rawPosition >> 1)
              string.append(space)
              string += String(describing: (sign > 0) ? -delta : delta)
            }
            yaml += string + "\n"
          }
        }
        
        let compressed = component.compressed
        precondition(compressed.cursor == 0, "Invalid cursor.")
        compressed.reserve(yaml.count)
        yaml.withUTF8 {
          compressed.write($0.count, source: $0.baseAddress!)
        }
        return
      }
      
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
        algorithm!.compressionAlgorithm)
      component.scratch.reserve(scratchSize)
      let scratch_ptr = component.scratch.buffer.contents()
      
      precondition(component.compressed.cursor == 0)
      while src_size > 0 {
        let compressed = component.compressed
        compressed.reserve(2 + 65536)
        let dst_ptr = 2 + compressed.buffer.contents() + compressed.cursor
        
        let lastCursor = compressed.cursor
        let compressedBytes = compression_encode_buffer(
          .init(OpaquePointer(dst_ptr)), 65536,
          .init(OpaquePointer(src_ptr)), min(src_size, 65536),
          scratch_ptr, algorithm!.compressionAlgorithm)
        guard compressedBytes > 0 else {
          fatalError("Error occurred during encoding.")
        }
        
        var header = UInt16(compressedBytes - 0 * 1)
        precondition(header > 0)
        precondition(compressedBytes > 0)
        compressed.write(2, source: &header)
        compressed.cursor += compressedBytes
        precondition(compressed.cursor == lastCursor + 2 + compressedBytes)
        src_ptr += 65536
        src_size -= 65536
      }
    }
    
    let metadata = activeCluster.compressedMetadata.compressed
    let x = activeCluster.compressedX.compressed
    let y = activeCluster.compressedY.compressed
    let z = activeCluster.compressedZ.compressed
    
    if format == .plainText {
      func writeString(_ string: String) {
        compressedData.reserve(string.count)
        var stringCopy = string
        stringCopy.withUTF8 {
          compressedData.write($0.count, source: $0.baseAddress!)
        }
      }
      
      let frameEnd = activeCluster.frameStart + activeCluster.frameCount - 1
      let index = activeCluster.frameStart / clusterSize
      writeString("frame cluster \(index):\n")
      writeString("  frame start: \(activeCluster.frameStart)\n")
      writeString("  frame end: \(frameEnd)\n")
      writeString("  metadata:\n")
      writeString("  atoms:\n")
      compressedData.reserve(x.cursor)
      compressedData.reserve(y.cursor)
      compressedData.reserve(z.cursor)
      compressedData.reserve(metadata.cursor)
      compressedData.write(x.cursor, source: x.buffer.contents())
      compressedData.write(y.cursor, source: y.buffer.contents())
      compressedData.write(z.cursor, source: z.buffer.contents())
      compressedData.write(metadata.cursor, source: metadata.buffer.contents())
      writeString("\n")
    } else {
      
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
      
      compressedData.reserve(header.count * 8)
      compressedData.write(header.count * 8, source: header)
      
      compressedData.reserve(totalBytes)
      compressedData.write(metadata.cursor, source: metadata.buffer.contents())
      compressedData.write(x.cursor, source: x.buffer.contents())
      compressedData.write(y.cursor, source: y.buffer.contents())
      compressedData.write(z.cursor, source: z.buffer.contents())
    }
    
    clustersTotalSize = compressedData.cursor
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
    activeCluster.frameStart = frameStart
    
    let expectedEnd = min(frameStart + clusterSize, frameCount) - 1
    precondition(frameEnd == expectedEnd)
    activeCluster.frameCount = (frameEnd - frameStart) + 1
    
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
      src += 48
      src += range.lowerBound
      
      let compressed = component.compressed
      var src_size = range.upperBound - range.lowerBound
      precondition(compressed.cursor == 0)
      
      compressed.write(src_size, source: src)
      compressed.cursor = 0
      
      let scratchSize = compression_decode_scratch_buffer_size(
        algorithm!.compressionAlgorithm)
      component.scratch.reserve(scratchSize)
      let scratch_ptr = component.scratch.buffer.contents()
      
      precondition(component.compressed.cursor == 0)
      while src_size > 0 {
        src_size -= 2
        let uncompressed = component.uncompressed
        uncompressed.reserve(65536)
        
        var header: UInt16 = 0
        
        let oldCursor = compressed.cursor
        let readBytes = compressed.read(2, destination: &header)
        precondition(compressed.cursor == oldCursor + 2)
        precondition(header > 0)
        precondition(readBytes == 2)
        
        let compressedBytes = Int(header) + 0 * 1
        
        let src_ptr = compressed.buffer.contents() + compressed.cursor
        let dst_ptr = uncompressed.buffer.contents() + uncompressed.cursor
        
        let uncompressedBytes = compression_decode_buffer(
          .init(OpaquePointer(dst_ptr)), 65536,
          .init(OpaquePointer(src_ptr)), compressedBytes,
          scratch_ptr, algorithm!.compressionAlgorithm)
        guard uncompressedBytes > 0 else {
          fatalError("Error occurred during encoding @ \(z): \(src_size).")
        }
        
        precondition(compressedBytes > 0)
        compressed.cursor += compressedBytes
        uncompressed.cursor += uncompressedBytes
        src_size -= Int(header)
      }
      
      component.compressed.cursor = 0
      component.uncompressed.cursor = 0
      
      if z == 0 {
        func extractHeaderWords(_ expectedCount: Int) -> [UInt32] {
          var output: [UInt32] = .init(repeating: 0, count: expectedCount)
          let readBytes = component.uncompressed.read(
            expectedCount * 4, destination: &output)
          precondition(readBytes == expectedCount * 4)
          return output
        }
        
        let frameCount = activeCluster.frameCount
        let atomsCounts = extractHeaderWords(frameCount)
        let metadataCounts = extractHeaderWords(frameCount)
        activeCluster.atomsCounts = atomsCounts
        activeCluster.metadataCounts = metadataCounts
        
        var atomsOffsets: [UInt32] = [0]
        var metadataOffsets: [UInt32] = [0]
        atomsOffsets.reserveCapacity(frameCount + 1)
        metadataOffsets.reserveCapacity(frameCount + 1)
        
        var atomsCount: UInt32 = 0
        var metadataCount: UInt32 = 0
        for i in 0..<frameCount {
          atomsCount += atomsCounts[i]
          metadataCount += metadataCounts[i]
          atomsOffsets.append(atomsCount)
          metadataOffsets.append(metadataCount)
        }
        activeCluster.atomsOffsets = atomsOffsets
        activeCluster.metadataOffsets = metadataOffsets
        
        let metadata = activeCluster.metadata
        metadata.reserve(Int(metadataOffsets.last!))
        
        let uncompressed = component.uncompressed
        let originalCursor = uncompressed.cursor
        for i in 0..<frameCount {
          let bytes = Int(metadataCounts[i])
          let uncompressed = component.uncompressed
          let source = uncompressed.buffer.contents() + uncompressed.cursor
          metadata.write(bytes, source: source)
          uncompressed.cursor += bytes
        }
        
        let expectedCursor = originalCursor + Int(metadataOffsets.last!)
        precondition(uncompressed.cursor == expectedCursor)
        precondition(uncompressed.cursor == activeCluster.compressedTailStart)
        precondition(metadata.cursor == metadataOffsets.last!)
        
        metadata.cursor = 0
      }
    }
    
    activeCluster.atoms.reserve(Int(activeCluster.atomsOffsets.last!) * 16)
    processAtoms(encode: false)
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
    var args = ProcessAtomsArguments(
      clusterSize: UInt16(clusterSize),
      scaleFactor: resolution,
      inverseScaleFactor: 1 / resolution)
    let argsBytes = MemoryLayout<ProcessAtomsArguments>.stride
    encoder.setBytes(&args, length: argsBytes, index: 0)
    
    let atomsCounts = activeCluster.atomsCounts
    let atomsOffsets = activeCluster.atomsOffsets
    withUnsafeTemporaryAllocation(
      of: SIMD2<UInt32>.self, capacity: clusterSize
    ) { bufferPointer in
      for i in 0..<activeCluster.frameCount {
        bufferPointer[i] = SIMD2(atomsOffsets[i], atomsCounts[i])
      }
      for i in activeCluster.frameCount..<clusterSize {
        bufferPointer[i] = SIMD2(atomsOffsets.last!, 0)
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
    
    // Massive CPU-side stall, makes this unusable in real-time (for now). It is
    // okay, as long as the simulation is small and short enough to be
    // materialized in RAM entirely at once.
    commandBuffer.waitUntilCompleted()
  }
}

fileprivate class ExpandingBuffer {
  var device: MTLDevice
  var buffer: MTLBuffer
  var cursor: Int
  
  init(device: MTLDevice) {
    self.device = device
    self.buffer = device.makeBuffer(length: 65536)!
    self.cursor = 0
  }
  
  func reset() {
    cursor = 0
  }
  
  func reserve(_ bytes: Int) {
    let neededBytes = roundUpToPowerOf2(cursor + bytes)
    if buffer.length < neededBytes {
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
    let readBytes = bytes
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
  
  func append(_ frame: MRFrame) {
    let atomCount = frame.atoms.count
    atomsCounts.append(UInt32(atomCount))
    atoms.cursor = Int(atomsOffsets.last!) * 16
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
  
  func makeFrame(frameID: Int) -> MRFrame {
    precondition(frameID - frameStart < frameCount)
    
    let atomCount = Int(atomsCounts[frameID - frameStart])
    let atomOffset = Int(atomsOffsets[frameID - frameStart])
    atoms.cursor = atomOffset * 16
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
    
    return MRFrame(atoms: frameAtoms, metadata: frameMetadata)
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
