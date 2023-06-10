//
//  Downloader.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/10/23.
//

import Foundation
import QuartzCore

// A 'DynamicDownloader' would issue a Metal fast resource loading command,
// which asynchronously returns the data just in time for rendering.
struct StaticDownloader {
  private var url: URL
  private(set) var latency: Double
  private(set) var data: Data
  var string: String { String(data: data, encoding: .utf8)! }
  
  // Immediately downloads the file upon initialization, blocking the caller.
  init(url: URL) throws {
    let start = CACurrentMediaTime()
    let data = try Data(contentsOf: url)
    let end = CACurrentMediaTime()
    
    self.url = url
    self.data = data
    self.latency = end - start
  }
  
  func logLatency() {
    // TODO: Query a global variable that determines whether events like this
    // are logged.
    print("Downloaded in \(latencyRepr(latency))")
    print("- path: \(url)")
  }
}
