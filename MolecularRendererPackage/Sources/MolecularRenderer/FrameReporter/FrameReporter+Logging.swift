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
    // display(performance: performance)
  }
  
  func queryPerformance() -> SIMD4<Double> {
    // Initialize the accumulators.
    var sum: SIMD4<Double> = .zero
    var validFrameCount: SIMD4<Double> = .zero
    
    // Iterate over the reports.
    for reportID in reports.indices {
      let report = reports[reportID]
      
      var reportData: SIMD4<Double> = .zero
      reportData[0] = report.copyTime
      reportData[1] = report.buildLargeTime
      reportData[2] = report.buildSmallTime
      reportData[3] = report.renderTime
      
      sum += reportData
      validFrameCount += reportData.replacing(
        with: .one, where: reportData .> 0)
    }
    
    // Take the average.
    sum /= validFrameCount
    sum.replace(with: SIMD4.zero, where: validFrameCount .== 0)
    return sum
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
