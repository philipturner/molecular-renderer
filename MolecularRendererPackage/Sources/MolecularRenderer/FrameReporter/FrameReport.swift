//
//  FrameReport.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

struct FrameReport {
  var frameID: Int
  
  var copyTime: Double = .zero
  var buildLargeTime: Double = .zero
  var buildSmallTime: Double = .zero
  var renderTime: Double = .zero
  
  init(frameID: Int) {
    self.frameID = frameID
  }
}
