//
//  BVHBuilder+FrameReport.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

import QuartzCore

extension BVHBuilder {
  func queryPerformance(frameID: Int) -> SIMD8<Double> {
    // Remove frames too far back in the history.
    frameReports.removeAll(where: {
      $0.frameID < frameID - 10
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
    if frameReports.count == 0 {
      average = .zero
    } else {
      average /= Double(frameReports.count)
    }
    
    // Add a new frame report.
    frameReports.append(
      MRFrameReport(frameID: frameID))
    
    return average
  }
  
  func logFrameReport(frameID: Int) {
    let performance = frameReportQueue.sync {
      queryPerformance(frameID: frameID)
    }
    guard reportPerformance else {
      return
    }
    
    for laneID in 0..<5 {
      // Prepend with a space.
      if laneID == 0 {
        print(" ", terminator: "")
      }
      
      // Acquire the data value.
      let microseconds = performance[laneID] * 1e6
      let microsecondsInt = Int(microseconds)
      var microsecondsRepr = "\(microsecondsInt)"
      
      // Pad to a fixed width.
      while microsecondsRepr.count < 6 {
        microsecondsRepr = " " + microsecondsRepr
      }
      
      // Display the data value.
      var terminator: String
      if laneID == 4 {
        terminator = "\n"
      } else {
        terminator = " | "
      }
      print(microsecondsRepr, terminator: terminator)
    }
  }
}
