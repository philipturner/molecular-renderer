//
//  BVHBuilder+FrameReport.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

import QuartzCore

extension BVHBuilder {
  func queryPerformance() -> SIMD8<Double> {
    // Remove frames too far back in the history.
    frameReports.removeAll(where: {
      $0.frameID <= frameReportCounter - 10
    })
    
    // Take the average of the rest.
    var average: SIMD8<Double> = .zero
    for report in frameReports {
      average[0] += report.preprocessingTimeCPU
      average[1] += report.copyingTime
      average[2] += report.preprocessingTimeGPU
      average[3] += report.geometryTime
      average[4] += report.renderTime
    }
    average /= Double(frameReports.count)
    
    return average
  }
  
  func startNewFrameReport() {
    let report = MRFrameReport(
      frameID: frameReportCounter,
      preprocessingTimeCPU: 0,
      copyingTime: 0,
      preprocessingTimeGPU: 0,
      geometryTime: 0,
      renderTime: 0)
    frameReports.append(report)
  }
  
  func logFrameReport() {
    let performance = frameReportQueue.sync {
      let output = queryPerformance()
      
      frameReportCounter += 1
      startNewFrameReport()
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
