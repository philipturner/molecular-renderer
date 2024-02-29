//
//  XTBLibrary.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 2/29/24.
//

import Foundation

class XTBLibrary {
  static var dylib: UnsafeMutableRawPointer?
  
  static func loadLibrary(path: String) {
    // TODO: Add RTLD_LAZY after debugging, to improve performance.
    let library = dlopen(path, RTLD_NOW)
    guard let library else {
      fatalError("Could not load dylib from path: \(path)")
    }
    Self.dylib = library
  }
  
  static func loadSymbol<T>(name: String) -> T {
    guard let dylib = Self.dylib else {
      fatalError("Did not set dylib to load symbol with.")
    }
    let symbol = dlsym(dylib, name)
    guard let symbol else {
      fatalError("Could not load symbol with name: \(name)")
    }
    return unsafeBitCast(symbol, to: T.self)
  }
}

// MARK: - Symbols

let xtb_getAPIVersion: @convention(c) () -> Int32 =
XTBLibrary.loadSymbol(name: "xtb_getAPIVersion")

let xtb_newEnvironment: @convention(c) () -> xtb_TEnvironment =
XTBLibrary.loadSymbol(name: "xtb_newEnvironment")

let xtb_newCalculator: @convention(c) () -> xtb_TCalculator =
XTBLibrary.loadSymbol(name: "xtb_newCalculator")
