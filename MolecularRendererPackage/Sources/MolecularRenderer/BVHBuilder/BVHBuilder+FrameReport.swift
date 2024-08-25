//
//  BVHBuilder+FrameReport.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

import QuartzCore

extension BVHBuilder {
  func incrementFrameReportCounter() {
    frameReportCounter += 1
  }
  
  func logBoundingBoxCreation() {
    let preprocessingStart = CACurrentMediaTime()
    (worldMinimum, worldMaximum) = reduceBoundingBox()
    let preprocessingEnd = CACurrentMediaTime()
    
    let performance = frameReportQueue.sync { () -> SIMD8<Double> in
      // Remove frames too far back in the history.
      let minimumID = frameReportCounter - Self.frameReportHistorySize
      while frameReports.count > 0, frameReports.first!.frameID < minimumID {
        frameReports.removeFirst()
      }
      
      var dataSize: Int = 0
      var output: SIMD8<Double> = .zero
      for report in frameReports {
        if report.preprocessingTimeGPU >= 0,
           report.geometryTime >= 0,
           report.renderTime >= 0 {
          dataSize += 1
          output[0] += report.preprocessingTimeCPU
          output[1] += report.copyingTime
          output[2] += report.preprocessingTimeGPU
          output[3] += report.geometryTime
          output[4] += report.renderTime
        }
      }
      if dataSize > 0 {
        output /= Double(dataSize)
      }
      
      let report = MRFrameReport(
        frameID: frameReportCounter,
        preprocessingTimeCPU: preprocessingEnd - preprocessingStart,
        copyingTime: 0,
        preprocessingTimeGPU: 0,
        geometryTime: 0,
        renderTime: 0)
      frameReports.append(report)
      return output
    }
    if reportPerformance, any(performance .> 0) {
      print("", terminator: " ")
      
      for laneID in 0..<5 {
        // Pad the integer to a common width.
        var repr = "\(Int(performance[laneID] * 1e6))"
        while repr.count < 6 {
          repr = " " + repr
        }
        
        // Print the integer and column separator.
        if laneID == 5 - 1 {
          print(repr, terminator: "\n")
        } else {
          print(repr, terminator: " | ")
        }
      }
    }
  }
}
