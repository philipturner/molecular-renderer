//
//  MRFrameReport.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

struct MRFrameReport {
  // The ID of the frame that owns this report.
  var frameID: Int
  
  // CPU time spent preparing geometry.
  var preprocessingTimeCPU: Double = .zero
  
  // CPU time spent copying geometry into GPU buffer.
  var copyingTime: Double = .zero
  
  // GPU time spent preparing geometry.
  var preprocessingTimeGPU: Double = .zero
  
  // GPU time spent building the uniform grid.
  var geometryTime: Double = .zero
  
  // GPU time spent rendering.
  var renderTime: Double = .zero
}
