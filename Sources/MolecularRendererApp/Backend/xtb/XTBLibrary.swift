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

let xtb_newEnvironment: @convention(c) () -> xtb_TEnvironment? =
XTBLibrary.loadSymbol(name: "xtb_newEnvironment")

let xtb_newCalculator: @convention(c) () -> xtb_TCalculator? =
XTBLibrary.loadSymbol(name: "xtb_newCalculator")

let xtb_newResults: @convention(c) () -> xtb_TResults? =
XTBLibrary.loadSymbol(name: "xtb_newResults")

let xtb_newMolecule: @convention(c) (
  xtb_TEnvironment?,
  UnsafePointer<Int32>?,
  UnsafePointer<Int32>?,
  UnsafePointer<Double>?,
  UnsafePointer<Double>?,
  UnsafePointer<Int32>?,
  UnsafePointer<Double>?,
  UnsafePointer<CBool>?
) -> xtb_TMolecule? =
XTBLibrary.loadSymbol(name: "xtb_newMolecule")

let xtb_updateMolecule: @convention(c) (
  xtb_TEnvironment?,
  xtb_TMolecule?,
  UnsafePointer<Double>?,
  UnsafePointer<Double>?
) -> Void =
XTBLibrary.loadSymbol(name: "xtb_updateMolecule")

let xtb_checkEnvironment: @convention(c) (
  xtb_TEnvironment?) -> Int32 =
XTBLibrary.loadSymbol(name: "xtb_checkEnvironment")

let xtb_showEnvironment: @convention(c) (
  xtb_TEnvironment?,
  UnsafePointer<CChar>?
) -> Void =
XTBLibrary.loadSymbol(name: "xtb_showEnvironment")

let xtb_setVerbosity: @convention(c) (
  xtb_TEnvironment?, Int32) -> Void =
XTBLibrary.loadSymbol(name: "xtb_setVerbosity")

let xtb_loadGFN2xTB: @convention(c) (
  xtb_TEnvironment?,
  xtb_TMolecule?,
  xtb_TCalculator?,
  UnsafePointer<CChar>?
) -> Void =
XTBLibrary.loadSymbol(name: "xtb_loadGFN2xTB")

let xtb_singlepoint: @convention(c) (
  xtb_TEnvironment?,
  xtb_TMolecule?,
  xtb_TCalculator?,
  xtb_TResults?
) -> Void =
XTBLibrary.loadSymbol(name: "xtb_singlepoint")

let xtb_getEnergy: @convention(c) (
  xtb_TEnvironment?,
  xtb_TResults?,
  UnsafeMutablePointer<Double>?
) -> Void =
XTBLibrary.loadSymbol(name: "xtb_getEnergy")

let xtb_getGradient: @convention(c) (
  xtb_TEnvironment?,
  xtb_TResults?,
  UnsafeMutablePointer<Double>?
) -> Void =
XTBLibrary.loadSymbol(name: "xtb_getGradient")

let xtb_getCharges: @convention(c) (
  xtb_TEnvironment?,
  xtb_TResults?,
  UnsafeMutablePointer<Double>?
) -> Void =
XTBLibrary.loadSymbol(name: "xtb_getCharges")

let xtb_delResults: @convention(c) (
  UnsafeMutablePointer<xtb_TResults?>?) -> Void =
XTBLibrary.loadSymbol(name: "xtb_delResults")

let xtb_delCalculator: @convention(c) (
  UnsafeMutablePointer<xtb_TCalculator?>?) -> Void =
XTBLibrary.loadSymbol(name: "xtb_delCalculator")

let xtb_delMolecule: @convention(c) (
  UnsafeMutablePointer<xtb_TMolecule?>?) -> Void =
XTBLibrary.loadSymbol(name: "xtb_delMolecule")

let xtb_delEnvironment: @convention(c) (
  UnsafeMutablePointer<xtb_TEnvironment?>?) -> Void =
XTBLibrary.loadSymbol(name: "xtb_delEnvironment")
