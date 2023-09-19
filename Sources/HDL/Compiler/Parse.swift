//
//  Parse.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/19/23.
//

import Foundation

/// Unstable API; do not use this type.
public struct _Parse {
  /// Initialize with a string representing the file's absolute path.
  public init(_ closure: () -> String) throws {
    let filePath = closure()
    guard let contents = FileManager.default.contents(atPath: filePath) else {
      throw _ParseError(description: "Could not real file: '\(filePath)'")
    }
    let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: contents.count)
    defer { bytes.deallocate() }
    contents.copyBytes(to: bytes, count: contents.count)
  }
}

/// Unstable API; do not use this type.
public struct _ParseError: LocalizedError {
  public var description: String
  
  public init(description: String) {
    self.description = description
  }
}

fileprivate struct RawString: Equatable, ExpressibleByStringLiteral {
  var pointer: UnsafeMutableBufferPointer<UInt8>
  
  init(pointer: UnsafeMutablePointer<UInt8>, count: Int) {
    self.pointer = .init(start: pointer, count: count)
  }
  
  /// Do not try to mutating strings generated this way.
  init(stringLiteral: StaticString) {
    self.pointer = .init(
      start: .init(mutating: stringLiteral.utf8Start),
      count: stringLiteral.utf8CodeUnitCount)
  }
  
  /// This subscript doesn't allow the string to be mutated.
  subscript(index: Int) -> UInt8 {
    pointer[index]
  }
  
  static func == (lhs: RawString, rhs: RawString) -> Bool {
    if lhs.pointer.count != rhs.pointer.count {
      return false
    }
    if lhs.pointer.count == 0 {
      return true
    }
    return memcmp(
      lhs.pointer.baseAddress, rhs.pointer.baseAddress, lhs.pointer.count) == 0
  }
  
  func substring(start: Int = 0, end: Int) -> RawString? {
    guard end >= 0, end <= pointer.count else {
      return nil
    }
    guard let baseAddress = self.pointer.baseAddress else {
      fatalError("Tried to get the substring of a zero-length string.")
    }
    return RawString(pointer: baseAddress + start, count: end - start)
  }
  
  func starts(with other: RawString) -> Bool {
    if let substring = self.substring(end: other.pointer.count) {
      return substring == other
    } else {
      return false
    }
  }
  
  mutating func removeFirst(_ count: Int) {
    guard count >= 0, count <= self.pointer.count else {
      fatalError("This should never happen.")
    }
    guard let baseAddress = self.pointer.baseAddress else {
      fatalError("Tried removing first characters of a zero-length string.")
    }
    let newBaseAddress = baseAddress + count
    let newCount = self.pointer.count - count
    self.pointer = .init(start: newBaseAddress, count: newCount)
  }
}

fileprivate struct RawCharacter: Equatable, ExpressibleByUnicodeScalarLiteral {
  var rawValue: UInt8
  
  init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
  
  init(unicodeScalarLiteral: Unicode.Scalar) {
    self.rawValue = UInt8(unicodeScalarLiteral.value)
  }
}
