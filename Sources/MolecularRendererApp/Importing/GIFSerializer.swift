//
//  GIFSerializer.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/7/23.
//

import CairoGraphics
import Foundation
import GIF
import QuartzCore
import simd

final class GIFSerializer {
  var gif: GIF
  var path: String
  
  init(path: String) {
    self.gif = GIF(width: 640, height: 640)
    self.path = path
  }
  
  // Pixels are in BGRA8888 format (little endian; A consumes the highest bits).
  func addImage(pixels: UnsafeRawPointer) {
    let image = try! CairoImage(width: 640, height: 640)
    
    let _pixels = pixels.assumingMemoryBound(to: UInt32.self)
    for y in 0..<640 {
      for x in 0..<640 {
        let index = y * 640 + x
        let pixel = _pixels[index]
        let color = Color(argb: pixel)
        image[y, x] = color
      }
    }
    
    let quantization = OctreeQuantization(fromImage: image)
    let frame = Frame(
      image: image, delayTime: 5, localQuantization: quantization)
    gif.frames.append(frame)
  }
  
  func save(fileName: String) {
    let path = self.path + "/" + fileName + ".gif"
    let url = URL(filePath: path)
    
    print()
    print("Started encoding GIF.")
    let start = CACurrentMediaTime()
    let data = try! gif.encoded()
    let end = CACurrentMediaTime()
    let latency = String(format: "%.3f", end - start)
    print("Finished encoding GIF in \(latency) seconds.")
    
    if data.count >= 1024 * 1024 {
      print("File size: \(data.count / 1024 / 1024) MB")
    } else {
      print("File size: \(data.count / 1024) KB")
    }
    try! data.write(to: url, options: .atomic)
  }
}

struct GIFExamples {
  static func saveExampleGIF(serializer: GIFSerializer) {
    let image = malloc(640 * 640 * 4)
      .assumingMemoryBound(to: SIMD4<UInt8>.self)
    defer { free(image) }
    
    let numFrames: Int = 30
    for t in 0..<numFrames {
      print("Encoding frame \(t)")
      let timeT = Float(t) / Float(numFrames)
      var progressT = sin(timeT * 2 * .pi)
      progressT = (progressT + 1) / 2
      precondition(progressT >= 0 && progressT <= 1)
      
      for y in 0..<640 {
        for x in 0..<640 {
          let index = y * 640 + x
          var progressX = Float(x) / 640
          var progressY = Float(y) / 640
          progressX *= progressT
          progressY *= progressT
          
          var color = SIMD4<Float>(progressX, progressY, 0, 1)
          color = __tg_rint(color * 256)
          var color16 = SIMD4<UInt16>(color) as SIMD4<UInt16>
          color16.replace(with: SIMD4(repeating: 255), where: color16 .> 255)
          let color8 = SIMD4<UInt8>(truncatingIfNeeded: color16)
          image[index] = color8
        }
      }
      serializer.addImage(pixels: image)
    }
    serializer.save(fileName: "Test")
  }
}
