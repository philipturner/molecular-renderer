//
//  FrameReporter+Logging.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

extension FrameReporter {
  func log() {
    let performance = queue.sync {
      queryPerformance()
    }
    display(performance: performance)
  }
  
  func queryPerformance() -> SIMD4<Double> {
    var validFrameCount: Int = .zero
    var sum: SIMD4<Double> = .zero
    
    for reportID in reports.indices {
      let report = reports[reportID]
      guard report.buildLargeTime > 0 else {
        continue
      }
      
      validFrameCount += 1
      sum[0] += report.copyTime
      sum[1] += report.buildLargeTime
    }
    
    if validFrameCount > 0 {
      return sum / Double(validFrameCount)
    } else {
      return .zero
    }
  }
  
  func display(performance: SIMD4<Double>) {
    let laneCount: Int = 4
    for laneID in 0..<laneCount {
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
      if laneID == laneCount - 1 {
        terminator = "\n"
      } else {
        terminator = " | "
      }
      print(microsecondsRepr, terminator: terminator)
    }
  }
}
