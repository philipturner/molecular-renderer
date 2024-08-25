//
//  FrameReporter+FrameChange.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

extension FrameReporter {
  func registerFrameChange(frameID: Int) {
    queue.sync {
      removeOldFrames(frameID: frameID)
      appendNewFrame(frameID: frameID)
    }
  }
  
  func removeOldFrames(frameID: Int) {
    let minimumFrameID = frameID - 10
    
    var newReports: [FrameReport] = []
    for reportID in reports.indices {
      let report = reports[reportID]
      guard report.frameID >= minimumFrameID else {
        continue
      }
      newReports.append(report)
    }
    reports = newReports
  }
  
  func appendNewFrame(frameID: Int) {
    let report = FrameReport(frameID: frameID)
    reports.append(report)
  }
}
