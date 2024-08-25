//
//  FrameReport.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

struct FrameReport {
  var frameID: Int
  
  var reduceBBTime: Double = .zero
  var copyTime: Double = .zero
  var prepareTime: Double = .zero
  var buildTime: Double = .zero
  var renderTime: Double = .zero
  
  init(frameID: Int) {
    self.frameID = frameID
  }
}
