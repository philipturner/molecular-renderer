//
//  GIFEncoder.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/7/23.
//

import Compression
import Foundation
import simd

// Source:
// https://web.archive.org/web/20181222182620/http://www.w3.org/Graphics/GIF/spec-gif89a.txt
final class GIFEncoder {
  var data: Data
  var path: String
  var scratchInput: UnsafeMutablePointer<SIMD16<UInt8>>
  var scratchLZW: UnsafeMutablePointer<UInt8>
  var scratchOutput: UnsafeMutablePointer<UInt8>
  
  init(path: String) {
    self.data = Data()
    self.path = path
    
    let maxDataSubBlocks = (640 * 640 + 254) / 255
    scratchInput = malloc(640 * 640)
      .assumingMemoryBound(to: SIMD16<UInt8>.self)
    scratchLZW = malloc(640 * 640)
      .assumingMemoryBound(to: UInt8.self)
    scratchOutput = malloc(256 * maxDataSubBlocks)
      .assumingMemoryBound(to: UInt8.self)
    
    data.append("GIF89a".data(using: .utf8)!)
    
    var imageSize: UInt16 = 640
    append(&imageSize, length: 2)
    append(&imageSize, length: 2)
    
    var flags: UInt8 = 0
    flags |= 0b0000_0001 // global color table flag
    flags |= 0b0000_1110 // color resolution
    flags |= 0b1110_0000 // size of global color table
    append(&flags, length: 1)
    
    var backgroundColorIndex: UInt8 = 0
    append(&backgroundColorIndex, length: 1)
    
    var pixelAspectRatio: UInt8 = 0
    append(&pixelAspectRatio, length: 1)
    
    for i in 0...255 {
      var color = SIMD3<UInt8>(repeating: UInt8(i))
      append(&color, length: 3)
    }
  }
  
  deinit {
    free(scratchInput)
    free(scratchLZW)
    free(scratchOutput)
  }
  
  private func append(_ bytes: UnsafeRawPointer, length: Int) {
    data.append(bytes.assumingMemoryBound(to: UInt8.self), count: length)
  }
  
  // Pixels are in BGRA8888 format (little endian; A consumes the highest bits).
  func addImage(pixels: UnsafeRawPointer) {
    var imageSeparator: UInt8 = 0x2C
    append(&imageSeparator, length: 1)
    
    var imagePosition: UInt16 = 0
    append(&imagePosition, length: 2)
    append(&imagePosition, length: 2)
    
    var imageSize: UInt16 = 640
    append(&imageSize, length: 2)
    append(&imageSize, length: 2)
    
    var flags: UInt8 = 0
    append(&flags, length: 1)
    
    // Operate on 128 bits of output data at a time.
    let imageChunks = pixels.assumingMemoryBound(to: SIMD16<UInt32>.self)
    for i in 0..<640 * 640 / 16 {
      let chunk = imageChunks[i]
      var sum = SIMD16<UInt16>(truncatingIfNeeded: chunk & 0xFF)
      sum &+= SIMD16<UInt16>(truncatingIfNeeded: chunk / 256 & 0xFF)
      sum &+= SIMD16<UInt16>(truncatingIfNeeded: chunk / 65536 & 0xFF)
      sum &+= 1
      scratchInput[i] = SIMD16<UInt8>(clamping: sum / 3)
    }
    
    // Cast the aligned data to UInt8 (unaligned) and convert to the format
    // with number of pixels interlaced.
//    let scratchSize = compression_encode_scratch_buffer_size(
//      COMPRESSION_LZ)
  }
  
  func save(fileName: String) {
    let path = self.path + "/" + fileName + ".gif"
    let url = URL(filePath: path)
    try! data.write(to: url, options: .atomic)
  }
}
