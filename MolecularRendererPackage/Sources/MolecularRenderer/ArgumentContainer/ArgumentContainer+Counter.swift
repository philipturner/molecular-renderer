//
//  ArgumentContainer+Counter.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

extension ArgumentContainer {
  func doubleBufferIndex() -> Int {
    frameID % 2
  }
  
  func tripleBufferIndex() -> Int {
    frameID % 3
  }
  
  func haltonIndex() -> Int {
    (frameID % 32) + 1
  }
}
