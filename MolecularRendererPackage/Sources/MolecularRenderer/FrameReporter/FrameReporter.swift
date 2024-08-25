//
//  FrameReporter.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

import Dispatch

class FrameReporter {
  var queue: DispatchQueue
  var reports: [FrameReport]
  
  init() {
    queue = Self.createQueue()
    reports = []
  }
  
  static func createQueue() -> DispatchQueue {
    let label = "com.philipturner.MolecularRenderer.FrameReporter.queue"
    return DispatchQueue(label: label)
  }
  
  func index(of frameID: Int) -> Int? {
    for index in reports.indices.reversed() {
      if reports[index].frameID == frameID {
        return index
      }
    }
    return nil
  }
}
