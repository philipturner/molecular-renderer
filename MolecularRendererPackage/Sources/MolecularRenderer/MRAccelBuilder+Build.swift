//
//  MRAccelBuilder+Preprocessing.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/27/23.
//

import Metal
import Foundation
import simd
import func QuartzCore.CACurrentMediaTime

func denseGridStatistics(
  atoms: [MRAtom],
  styles: [MRAtomStyle],
  voxel_width_numer: Float,
  voxel_width_denom: Float
) -> (boundingBox: (SIMD3<Float>, SIMD3<Float>), references: Int) {
  precondition(atoms.count > 0, "Not enough atoms.")
  precondition(styles.count > 0, "Not enough styles.")
  precondition(styles.count < 255, "Too many styles.")
  
  let epsilon: Float = 1e-4
  let workBlockSize: Int = 64 * 1024
  let numThreads = (atoms.count + workBlockSize - 1) / workBlockSize
  var elementInstances = [UInt32](repeating: .zero, count: 256 * numThreads)
  var minCoordinatesArray = [SIMD3<Float>](repeating: .zero, count: numThreads)
  var maxCoordinatesArray = [SIMD3<Float>](repeating: .zero, count: numThreads)
  var referencesArray = [Double](repeating: .zero, count: numThreads)
  
  DispatchQueue.concurrentPerform(iterations: numThreads) { taskID in
    var minCoordinates: SIMD4<Float> = .zero
    var maxCoordinates: SIMD4<Float> = .zero
    var references: Double = .zero
    var loopStart = atoms.count * taskID / numThreads
    var loopEnd = atoms.count * (taskID + 1) / numThreads
    let elementsOffset = 256 * taskID
    
    atoms.withUnsafeBufferPointer {
      let baseAddress = OpaquePointer($0.baseAddress!)
      let voxelSizeInv = voxel_width_denom / voxel_width_numer
      let atomBuffer = UnsafeMutableRawPointer(baseAddress)
        .assumingMemoryBound(to: SIMD4<Float>.self)
      
      @inline(__always)
      func countCells(_ atom: SIMD4<Float>) -> SIMD4<Float> {
        let element8 = unsafeBitCast(atom.w, to: SIMD4<UInt8>.self).z
        let element = Int(truncatingIfNeeded: element8)
        elementInstances[elementsOffset &+ element] &+= 1
        
        let radius = Float(styles[element].radius) + epsilon
        let lowerBound = ((atom - radius) * voxelSizeInv)
        let upperBound = ((atom + radius) * voxelSizeInv)
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
        var minCoordinatesVector: SIMD8<Float> = .zero
        var maxCoordinatesVector: SIMD8<Float> = .zero
        
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
  guard let references = Int(exactly: referencesArray.reduce(0, +)) else {
    fatalError("This should never happen.")
  }
  
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
  
  return ((minCoordinates, maxCoordinates), references)
}

extension MRAccelBuilder {
  func buildDenseGrid(
    encoder: MTLComputeCommandEncoder
  ) {
    if sceneSize == .extreme, builtGrid {
      return
    }
    builtGrid = true
    
    guard let sceneSize else {
      fatalError("Voxel size denominator not set.")
    }
    
    let voxel_width_numer: Float = 4
    let voxel_width_denom: Float = (sceneSize == .small) ? 16 : 8
    let preprocessingStart = CACurrentMediaTime()
    var statistics = denseGridStatistics(
      atoms: atoms,
      styles: styles,
      voxel_width_numer: voxel_width_numer,
      voxel_width_denom: voxel_width_denom)
    let preprocessingEnd = CACurrentMediaTime()
    
    
    
    let minCoordinates = SIMD3(statistics.boundingBox.0.x,
                               statistics.boundingBox.0.y,
                               statistics.boundingBox.0.z)
    let maxCoordinates = SIMD3(statistics.boundingBox.1.x,
                               statistics.boundingBox.1.y,
                               statistics.boundingBox.1.z)
    let maxMagnitude = simd_max(abs(minCoordinates), abs(maxCoordinates))
    self.gridDims = SIMD3<UInt16>(2 * ceil(
      maxMagnitude * voxel_width_denom / voxel_width_numer))
    
    // If some atoms fly extremely far out of bounds, prevent the app from
    // crashing. No atom may have a coordinate larger than +/- ~100 nm, which
    // creates a 2 GB memory allocation.
    self.gridDims = simd_min(self.gridDims, .init(repeating: 800))
    let totalCells = Int(gridDims[0]) * Int(gridDims[1]) * Int(gridDims[2])
    if sceneSize != .extreme {
      guard statistics.references < 16 * 1024 * 1024 else {
        fatalError("Too many references for a dense grid.")
      }
    }
    
    // Allocate new memory.
    let copyingStart = CACurrentMediaTime()
    let atomsBuffer = allocate(
      &denseGridAtoms[ringIndex],
      desiredElements: atoms.count,
      bytesPerElement: 16)
    memcpy(denseGridAtoms[ringIndex]!.contents(), atoms, atoms.count * 16)
    
    // Add 8 to the number of slots, so the counters can be located at the start
    // of the buffer.
    let numSlots = (totalCells + 127) / 128 * 128
    let atomicSpan = (sceneSize == .extreme) ? 2 : 1
    let dataBuffer = allocate(
      &denseGridData,
      desiredElements: 8 + numSlots * atomicSpan,
      bytesPerElement: 4)
    let countersBuffer = allocate(
      &denseGridCounters,
      desiredElements: totalCells,
      bytesPerElement: 4)
    let referencesBuffer = allocate(
      &denseGridReferences,
      desiredElements: statistics.references,
      bytesPerElement: 4)
    let copyingEnd = CACurrentMediaTime()
    
    // The first rendered frame will have an ID of 1.
    frameReportCounter += 1
    let performance = frameReportQueue.sync { () -> SIMD4<Double> in
      // Remove frames too far back in the history.
      let minimumID = frameReportCounter - Self.frameReportHistorySize
      while frameReports.count > 0, frameReports.first!.frameID < minimumID {
        frameReports.removeFirst()
      }
      
      var dataSize: Int = 0
      var output: SIMD4<Double> = .zero
      for report in frameReports {
        if report.geometryTime >= 0, report.renderTime >= 0 {
          dataSize += 1
          output[0] += report.preprocessingTime
          output[1] += report.copyingTime
          output[2] += report.geometryTime
          output[3] += report.renderTime
        }
      }
      if dataSize > 0 {
        output /= Double(dataSize)
      }
      
      let report = MRFrameReport(
        frameID: frameReportCounter,
        preprocessingTime: preprocessingEnd - preprocessingStart,
        copyingTime: copyingEnd - copyingStart,
        geometryTime: 1,
        renderTime: 1)
      frameReports.append(report)
      return output
    }
    if reportPerformance, any(performance .> 0) {
      print(
        Int(performance[0] * 1e6),
        Int(performance[1] * 1e6),
        Int(performance[2] * 1e6),
        Int(performance[3] * 1e6))
    }
    
    encoder.setComputePipelineState(memsetPipeline)
    encoder.setBuffer(dataBuffer, offset: 0, index: 0)
    encoder.dispatchThreads(
      MTLSizeMake(8 + numSlots * atomicSpan, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
    
    struct UniformGridArguments {
      var gridDims: SIMD3<UInt16>
      var cellSphereTest: UInt16
      var worldToVoxelTransform: Float
    }
    
    var arguments: UniformGridArguments = .init(
      gridDims: gridDims,
      cellSphereTest: 1,
      worldToVoxelTransform: voxel_width_denom / voxel_width_numer)
    let argumentsStride = MemoryLayout<UniformGridArguments>.stride
    encoder.setBytes(&arguments, length: argumentsStride, index: 0)
    
    styles.withUnsafeBufferPointer {
      let length = $0.count * MemoryLayout<MRAtomStyle>.stride
      encoder.setBytes($0.baseAddress!, length: length, index: 1)
    }
    
    // Set the data at offset 32, to fit the counters before it.
    encoder.setBuffer(atomsBuffer, offset: 0, index: 2)
    encoder.setBuffer(dataBuffer, offset: 32, index: 3)
    encoder.setBuffer(countersBuffer, offset: 0, index: 4)
    encoder.setBuffer(dataBuffer, offset: ringIndex * 4, index: 5)
    encoder.setBuffer(referencesBuffer, offset: 0, index: 6)
    encoder.setBuffer(dataBuffer, offset: ringIndex * 4 + 16, index: 7)
    
    encoder.setComputePipelineState(densePass1Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    
    encoder.setComputePipelineState(densePass2Pipeline)
    encoder.dispatchThreadgroups(
      MTLSizeMake(numSlots / 128, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    
    encoder.setComputePipelineState(densePass3Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
}
