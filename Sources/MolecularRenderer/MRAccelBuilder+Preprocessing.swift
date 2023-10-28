//
//  MRAccelBuilder+Preprocessing.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/27/23.
//

import Metal
import Foundation
import simd

func denseGridStatistics(
  atoms: [MRAtom],
  styles: [MRAtomStyle],
  voxel_width_numer: Float,
  voxel_width_denom: SIMD2<Float>
) -> (boundingBox: MRBoundingBox, references: SIMD2<Int>) {
  precondition(atoms.count > 0, "Not enough atoms.")
  precondition(styles.count > 0, "Not enough styles.")
  precondition(styles.count < 255, "Too many styles.")
  
  let epsilon: Float = 1e-4
  let workBlockSize: Int = 64 * 1024
  let numThreads = (atoms.count + workBlockSize - 1) / workBlockSize
  var elementInstances = [UInt32](repeating: .zero, count: 256 * numThreads)
  var minCoordinatesArray = [SIMD3<Float>](repeating: .zero, count: numThreads)
  var maxCoordinatesArray = [SIMD3<Float>](repeating: .zero, count: numThreads)
  var referencesArray = [SIMD2<UInt32>](repeating: .zero, count: numThreads)
  
  DispatchQueue.concurrentPerform(iterations: numThreads) { taskID in
    var minCoordinates: SIMD4<Float> = .zero
    var maxCoordinates: SIMD4<Float> = .zero
    var references: SIMD2<UInt32> = .zero
    var loopStart = atoms.count * taskID / numThreads
    var loopEnd = atoms.count * (taskID + 1) / numThreads
    let elementsOffset = 256 * taskID
    
    atoms.withUnsafeBufferPointer {
      let baseAddress = OpaquePointer($0.baseAddress!)
      
      func iterateSingle(_ i: Int) {
        let atomBuffer = UnsafeMutableRawPointer(baseAddress)
          .assumingMemoryBound(to: SIMD4<Float>.self)
        let atom = atomBuffer[i]
        let element = unsafeBitCast(atom.w, to: SIMD4<UInt8>.self).x
        let elementsAddress = elementsOffset &+ Int(element)
        elementInstances[elementsAddress] &+= 1
        minCoordinates = simd_min(minCoordinates, atom)
        maxCoordinates = simd_max(maxCoordinates, atom)
        
        let radius = Float(styles[Int(element)].radius)
        let cellSpan = 1 + ceil(
          (2 * radius + epsilon) * voxel_width_denom / voxel_width_numer)
        let cellCube = cellSpan * cellSpan * cellSpan
        references &+= SIMD2<UInt32>(cellCube)
      }
      while loopStart % 4 != 0, loopStart < loopEnd {
        iterateSingle(loopStart)
        loopStart += 1
      }
      while loopEnd % 4 != 0, loopStart < loopEnd {
        iterateSingle(loopEnd)
        loopEnd -= 1
      }
      
      let randomMultiplier = min(0, 1 + Float(UInt8.random(in: 0..<255)))
      precondition(randomMultiplier == 0, "This should never happen.")
      
      if loopStart % 4 == 0, loopEnd % 4 == 0 {
        let atomBuffer = UnsafeMutableRawPointer(baseAddress)
          .assumingMemoryBound(to: SIMD16<Float>.self)
        var minCoordinatesVector: SIMD8<Float> = .zero
        var maxCoordinatesVector: SIMD8<Float> = .zero
        
        let voxelSizeInv = voxel_width_denom / voxel_width_numer
        for vector in loopStart / 4..<loopEnd / 4 {
          // 3400/3700 -> 2100/2200 -> ???
          let vector = atomBuffer[vector]
          let atom1 = vector.lowHalf.lowHalf
          let atom2 = vector.lowHalf.highHalf
          let atom3 = vector.highHalf.lowHalf
          let atom4 = vector.highHalf.highHalf
          
          @inline(__always)
          func process(_ atom: SIMD4<Float>) -> (SIMD4<Float>, SIMD4<Float>) {
            let element = Int(
              truncatingIfNeeded: unsafeBitCast(atom.w, to: SIMD4<UInt8>.self).x)
            elementInstances[elementsOffset &+ element] &+= 1
            
            let radius = Float(styles[element].radius) + epsilon
            let lowerBound0 = ((atom - radius) * voxelSizeInv[0]).rounded(.down)
            let upperBound0 = ((atom + radius) * voxelSizeInv[0]).rounded(.up)
            let lowerBound1 = ((atom - radius) * voxelSizeInv[1]).rounded(.down)
            let upperBound1 = ((atom + radius) * voxelSizeInv[1]).rounded(.up)
            return (
              SIMD4<Float>(upperBound0 - lowerBound0),
              SIMD4<Float>(upperBound1 - lowerBound1))
          }
          let (cells1_0, cells1_1) = process(atom1)
          let (cells2_0, cells2_1) = process(atom2)
          let (cells3_0, cells3_1) = process(atom3)
          let (cells4_0, cells4_1) = process(atom4)
          
          let products0 = SIMD4<Float>(
            cells1_0[0] * cells1_0[1] * cells1_0[2],
            cells2_0[0] * cells2_0[1] * cells2_0[2],
            cells3_0[0] * cells3_0[1] * cells3_0[2],
            cells4_0[0] * cells4_0[1] * cells4_0[2])
          references[0] &+= UInt32(products0.sum())
          
          let products1 = SIMD4<Float>(
            cells1_1[0] * cells1_1[1] * cells1_1[2],
            cells2_1[0] * cells2_1[1] * cells2_1[2],
            cells3_1[0] * cells3_1[1] * cells3_1[2],
            cells4_1[0] * cells4_1[1] * cells4_1[2])
          references[1] &+= UInt32(products1.sum())
          
          var minCoords = simd_min(vector.lowHalf, vector.highHalf)
          var maxCoords = simd_max(vector.lowHalf, vector.highHalf)
          minCoordinatesVector = simd_min(minCoordinatesVector, minCoords)
          maxCoordinatesVector = simd_max(maxCoordinatesVector, maxCoords)
        }
        
        minCoordinates = simd_min(
          minCoordinates, minCoordinatesVector.lowHalf)
        minCoordinates = simd_min(
          minCoordinates, minCoordinatesVector.highHalf)
        
        maxCoordinates = simd_max(
          maxCoordinates, maxCoordinatesVector.lowHalf)
        maxCoordinates = simd_max(
          maxCoordinates, maxCoordinatesVector.highHalf)
      }
    }
    
    minCoordinatesArray[taskID] = unsafeBitCast(
      minCoordinates, to: SIMD3<Float>.self)
    maxCoordinatesArray[taskID] = unsafeBitCast(
      maxCoordinates, to: SIMD3<Float>.self)
    referencesArray[taskID] = references
  }
  
  var minCoordinates: SIMD3<Float> = .zero
  var maxCoordinates: SIMD3<Float> = .zero
  for taskID in 0..<numThreads {
    minCoordinates = simd_min(minCoordinates, minCoordinatesArray[taskID])
    maxCoordinates = simd_max(maxCoordinates, maxCoordinatesArray[taskID])
  }
  for taskID in 1..<numThreads {
    for elementID in 0..<256 {
      elementInstances[elementID] += elementInstances[256 * taskID + elementID]
    }
  }
  
  let references = SIMD2<Int>(
    truncatingIfNeeded: referencesArray.reduce(.zero, &+))
  var maxRadius: Float = 0
  for i in 0..<styles.count {
    let radius = Float(styles[i].radius)
    let cellSpan = 1 + ceil(
      (2 * radius + epsilon) * voxel_width_denom / voxel_width_numer)
    
    let instances = elementInstances[i]
    let presentMask: Float = (instances > 0) ? 1 : 0
    maxRadius = max(radius * presentMask, maxRadius)
  }
  maxRadius += epsilon
  minCoordinates -= maxRadius
  maxCoordinates += maxRadius
  
  let boundingBox = MRBoundingBox(
    min: MTLPackedFloat3Make(
      minCoordinates.x, minCoordinates.y, minCoordinates.z),
    max: MTLPackedFloat3Make(
      maxCoordinates.x, maxCoordinates.y, maxCoordinates.z))
  return (boundingBox, references)
}

