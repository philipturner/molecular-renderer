//
//  SSDCaching.swift
//  molecular-renderer
//
//  Created by Philip Turner on 10/23/25.
//

import Foundation
import HDL

// Procedure for generating a unique identifier for the current state.
func createKey(tripod: Topology) -> String {
  let key = Serialization.hash(atoms: tripod.atoms)
  
  // RFC 3548 encoding: https://www.rfc-editor.org/rfc/rfc3548#page-6
  // "/" -> "_"
  // "+" -> "-"
  var base64Key = key.base64EncodedString()
  do {
    // Fetch the null-terminated C string.
    var cString = base64Key.utf8CString
    for characterID in cString.indices {
      let byte = cString[characterID]
      let scalar = UnicodeScalar(UInt32(byte))!
      var character = Character(scalar)
      
      if character == "/" {
        character = "_"
      } else if character == "+" {
        character = "-"
      }
      cString[characterID] = CChar(character.asciiValue!)
    }
    base64Key = cString.withUnsafeBufferPointer {
      return String(cString: $0.baseAddress!)
    }
  }
  return base64Key
}

func loadCachedTrajectory(
  tripod: Topology
) -> [[SIMD4<Float>]] {
  // Find the path.
  let packagePath = FileManager.default.currentDirectoryPath
  let key = createKey(tripod: tripod)
  
  // Load the cached trajectory.
  var frames: [[SIMD4<Float>]] = []
  do {
    let url = URL(
      filePath: "\(packagePath)/.build/tooltips/\(key)")
    let data = try Data(contentsOf: url)
    frames = Serialization.decode(frames: data)
  } catch {
    frames = runMinimization(tripod: tripod)
    
    let directoryURL = URL(
      filePath: "\(packagePath)/.build/tooltips")
    try! FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true)
    
    let data = Serialization.encode(frames: frames)
    let succeeded = FileManager.default.createFile(
      atPath: "\(packagePath)/.build/tooltips/\(key)",
      contents: data)
    guard succeeded else {
      fatalError("Could not create file.")
    }
  }
  
  return frames
}
