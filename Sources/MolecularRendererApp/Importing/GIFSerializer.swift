//
//  GIFSerializer.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/7/23.
//

import CairoGraphics
import Foundation
import GIF

final class GIFSerializer {
  var gif: GIF
  var path: String
  var previousFrames: [[UInt32]] = []
  
  let width: Int = 720
  let height: Int = 640
  
  init(path: String) {
    self.gif = GIF(width: width, height: height)
    self.path = path
  }
  
  // Pixels are in BGRA8888 format (little endian; A consumes the highest bits).
  func addImage(pixels: UnsafeRawPointer, blurFusion: Int = 1) {
    let _pixels = pixels.assumingMemoryBound(to: UInt32.self)
    if previousFrames.count < blurFusion - 1 {
      previousFrames.append(Array(
        unsafeUninitializedCapacity: width * height
      ) { pointer, count in
        count = width * height
        for y in 0..<height {
          for x in 0..<width {
            let index = y * width + x
            pointer[index] = _pixels[index]
          }
        }
      })
      return
    }
    defer {
      previousFrames = []
    }
    
    let image = try! CairoImage(width: width, height: height)
    var sumBuffer = [SIMD4<Float16>](repeating: .zero, count: width * height)
    for frame in previousFrames {
      for y in 0..<height {
        for x in 0..<width {
          let index = y * width + x
          let pixel = unsafeBitCast(frame[index], to: SIMD4<UInt8>.self)
          sumBuffer[index] += SIMD4<Float16>(pixel)
        }
      }
    }
    
    let numFramesRecip = (blurFusion == 1) ? 0 : 1 / Float(blurFusion - 1)
    let currentMultiplier = (blurFusion == 1) ? 1 : Float(0.5)
    for y in 0..<height {
      for x in 0..<width {
        let index = y * width + x
        var sum = SIMD4<Float>(sumBuffer[index])
        sum *= numFramesRecip
        sum *= 1 - currentMultiplier
        
        var pixel = unsafeBitCast(_pixels[index], to: SIMD4<UInt8>.self)
        sum += SIMD4<Float>(pixel) * currentMultiplier
        sum = sum.rounded(.toNearestOrEven)
        sum.clamp(lowerBound: .zero, upperBound: .init(repeating: 255))
        pixel = SIMD4<UInt8>(sum)
        
        let color = Color(argb: unsafeBitCast(pixel, to: UInt32.self))
        image[y, x] = color
      }
    }
    
    let quantization = OctreeQuantization(fromImage: image)
    let frame = Frame(
      image: image, delayTime: 2, localQuantization: quantization)
    gif.frames.append(frame)
  }
  
  func save(fileName: String) {
    // Don't let any previous frames potentially leak into another render.
    previousFrames = []
    
    let path = self.path + "/" + fileName + ".gif"
    let url = URL(filePath: path)
    
    print()
    print("Started encoding GIF.")
    let start = cross_platform_media_time()
    let data = try! gif.encoded()
    let end = cross_platform_media_time()
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
    let width = serializer.width
    let height = serializer.height
    let image = malloc(width * height * 4)
      .assumingMemoryBound(to: SIMD4<UInt8>.self)
    defer { free(image) }
    
    let numFrames: Int = 30
    for t in 0..<numFrames {
      print("Encoding frame \(t)")
      let timeT = Float(t) / Float(numFrames)
      var progressT = sin(timeT * 2 * .pi)
      progressT = (progressT + 1) / 2
      precondition(progressT >= 0 && progressT <= 1)
      
      let widthRecip = 1 / Float(width)
      let heightRecip = 1 / Float(height)
      for y in 0..<height {
        for x in 0..<width {
          let index = y * width + x
          var progressX = Float(x) * widthRecip
          var progressY = Float(y) * heightRecip
          progressX *= progressT
          progressY *= progressT
          
          var color = SIMD4<Float>(progressX, progressY, 0, 1)
          color.round(.toNearestOrEven)
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
