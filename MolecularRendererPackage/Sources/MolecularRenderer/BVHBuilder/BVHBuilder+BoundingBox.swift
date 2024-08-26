//
//  BVHBuilder+BoundingBox.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

import Dispatch
import QuartzCore
import simd

func denseGridStatistics(
  atoms: [SIMD4<Float>],
  atomRadii: [Float]
) -> (boundingBox: (SIMD3<Float>, SIMD3<Float>), references: Int) {
  precondition(atoms.count > 0, "Not enough atoms.")
  precondition(atomRadii.count > 0, "Not enough styles.")
  precondition(atomRadii.count < 255, "Too many styles.")
  
  let epsilon: Float = 1e-4
  let workBlockSize: Int = 64 * 1024
  let numThreads = (atoms.count + workBlockSize - 1) / workBlockSize
  var elementInstances = [UInt32](repeating: .zero, count: 256 * numThreads)
  var minCoordinatesArray = [SIMD3<Float>](repeating: .zero, count: numThreads)
  var maxCoordinatesArray = [SIMD3<Float>](repeating: .zero, count: numThreads)
  var referencesArray = [Double](repeating: .zero, count: numThreads)
  
  DispatchQueue.concurrentPerform(iterations: numThreads) { taskID in
    var minCoordinates = SIMD4<Float>(repeating: Float(Int32.max))
    var maxCoordinates = SIMD4<Float>(repeating: Float(Int32.min))
    var references: Double = .zero
    var loopStart = atoms.count * taskID / numThreads
    var loopEnd = atoms.count * (taskID + 1) / numThreads
    let elementsOffset = 256 * taskID
    
    atoms.withUnsafeBufferPointer {
      let baseAddress = OpaquePointer($0.baseAddress!)
      let atomBuffer = UnsafeMutableRawPointer(baseAddress)
        .assumingMemoryBound(to: SIMD4<Float>.self)
      
      @inline(__always)
      func countCells(_ atom: SIMD4<Float>) -> SIMD4<Float> {
        let element = Int(atom.w)
        elementInstances[elementsOffset &+ element] &+= 1
        
        let radius = Float(atomRadii[element]) + epsilon
        let lowerBound = ((atom - radius) / 0.25)
        let upperBound = ((atom + radius) / 0.25)
        return upperBound.rounded(.down) - lowerBound.rounded(.down) + 1
      }
      
      while loopStart % 4 != 0, loopStart < loopEnd {
        let atom = atomBuffer[loopStart]
        minCoordinates = simd_min(minCoordinates, atom)
        maxCoordinates = simd_max(maxCoordinates, atom)
        
        let cells = countCells(atom)
        references += Double(cells[0] * cells[1] * cells[2])
        loopStart &+= 1
      }
      while loopEnd % 4 != 0, loopStart < loopEnd {
        let atom = atomBuffer[loopEnd &- 1]
        minCoordinates = simd_min(minCoordinates, atom)
        maxCoordinates = simd_max(maxCoordinates, atom)
        
        let cells = countCells(atom)
        references += Double(cells[0] * cells[1] * cells[2])
        loopEnd &-= 1
      }
      
      if loopStart % 4 == 0, loopEnd % 4 == 0 {
        let atomBuffer = UnsafeMutableRawPointer(baseAddress)
          .assumingMemoryBound(to: SIMD16<Float>.self)
        var minCoordinatesVector = SIMD8<Float>(repeating: Float(Int32.max))
        var maxCoordinatesVector = SIMD8<Float>(repeating: Float(Int32.min))
        
        for vectorID in loopStart / 4..<loopEnd / 4 {
          let vector = atomBuffer[vectorID]
          let atom1 = vector.lowHalf.lowHalf
          let atom2 = vector.lowHalf.highHalf
          let atom3 = vector.highHalf.lowHalf
          let atom4 = vector.highHalf.highHalf
          
          let cells1 = countCells(atom1)
          let cells2 = countCells(atom2)
          let cells3 = countCells(atom3)
          let cells4 = countCells(atom4)
          
          let products0 = SIMD4<Float>(
            cells1[0] * cells1[1] * cells1[2],
            cells2[0] * cells2[1] * cells2[2],
            cells3[0] * cells3[1] * cells3[2],
            cells4[0] * cells4[1] * cells4[2])
          references += Double(products0.sum())
          
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
  
  var minCoordinates = SIMD3<Float>(repeating: Float(Int32.max))
  var maxCoordinates = SIMD3<Float>(repeating: Float(Int32.min))
  for taskID in 0..<numThreads {
    minCoordinates = simd_min(minCoordinates, minCoordinatesArray[taskID])
    maxCoordinates = simd_max(maxCoordinates, maxCoordinatesArray[taskID])
  }
  for taskID in 1..<numThreads {
    for elementID in 0..<256 {
      elementInstances[elementID] += elementInstances[256 * taskID + elementID]
    }
  }
  guard let references = Int(exactly: referencesArray.reduce(0, +)) else {
    fatalError("This should never happen.")
  }
  
  var maxRadius: Float = 0
  for i in 0..<atomRadii.count {
    let radius = Float(atomRadii[i])
    let cellSpan = 1 + ceil(
      (2 * radius + epsilon) / 0.25)
    
    let instances = elementInstances[i]
    let presentMask: Float = (instances > 0) ? 1 : 0
    maxRadius = max(radius * presentMask, maxRadius)
  }
  
  /*
  print()
  print(minCoordinates)
  print(maxCoordinates)
  print()
  
  print()
  print(maxRadius)
  print()
   */
  
  maxRadius += epsilon
  
  /*
  print()
  print(maxRadius)
  print()
   */
  
  minCoordinates -= maxRadius
  maxCoordinates += maxRadius
  
  /*
  print()
  print(minCoordinates)
  print(maxCoordinates)
  print()
   */
  
  return ((minCoordinates, maxCoordinates), references)
}

extension BVHBuilder {
  func reduceBoundingBox() -> (SIMD3<Int32>, SIMD3<Int32>) {
    let atoms = renderer.argumentContainer.currentAtoms
    
    let statistics = denseGridStatistics(
      atoms: atoms, atomRadii: renderer.atomRadii)
    guard statistics.references < 64 * 1024 * 1024 else {
      fatalError("Too many references for a dense grid.")
    }
    
    var minCoordinates = statistics.boundingBox.0
    var maxCoordinates = statistics.boundingBox.1
    
    // Clamp to [-64, 64].
    minCoordinates.replace(with: -64, where: minCoordinates .< -64)
    maxCoordinates.replace(with: 64, where: maxCoordinates .> 64)
    
    // Round to the nearest multiple of 2 nm.
    minCoordinates /= 2
    maxCoordinates /= 2
    minCoordinates.round(.down)
    maxCoordinates.round(.up)
    minCoordinates *= 2
    maxCoordinates *= 2
    
    // Convert from floating point to integer.
    return (
      SIMD3<Int32>(minCoordinates),
      SIMD3<Int32>(maxCoordinates))
  }
}
