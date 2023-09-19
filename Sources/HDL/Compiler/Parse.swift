//
//  Parse.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/19/23.
//

import Foundation

/// Unstable API; do not use this type. It is a JIT compiler for the DSL.
public struct _Parse {
  /// Initialize with a string representing the file's absolute path.
  @discardableResult
  public init(_ closure: () -> String) throws {
    let filePath = closure()
    guard let contents = FileManager.default.contents(atPath: filePath) else {
      throw _ParseError(description: "Could not real file: '\(filePath)'")
    }
    let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: contents.count)
    defer { bytes.deallocate() }
    contents.copyBytes(to: bytes, count: contents.count)
    
    var lines: [Line] = []
    do {
      var lastStart: Int = 0
      for i in 0..<contents.count {
        if RawCharacter(rawValue: bytes[i]) == "\n" {
          var count = i - lastStart
          if i > 0, RawCharacter(rawValue: bytes[i - 1]) == "\r" {
            // Remove carriage return on Windows.
            count -= 1
          }
          let string = RawString(pointer: bytes + lastStart, count: count)
          lines.append(try Line(rawValue: string))
          lastStart = i + 1
        }
      }
    }
    for line in lines {
      print(line.description)
    }
    
    // Only comments on their own line are allowed for now.
    // Bracket initializers for language keywords must all be on one line.
    enum Line {
      case code(Int, RawString)
      case closingBracket(Int)
      case comment(Int)
      case whitespace
      
      init(rawValue string: RawString) throws {
        var numIndents: Int = 0
        for i in 0..<string.count {
          if RawCharacter(string[i]) == " " {
            numIndents += 1
          } else {
            break
          }
        }
        
        if numIndents == string.count {
          self = .whitespace
        } else if RawCharacter(string[numIndents]) == "}" {
          if string.count > numIndents + 1 {
            for i in numIndents + 1..<string.count {
              guard RawCharacter(string[i]) == " " else {
                throw _ParseError(description: "A line with a closing bracket had content besides whitespace after it.")
              }
            }
          }
          self = .closingBracket(numIndents)
        } else if RawCharacter(string[numIndents]) == "/" {
          if string.count < numIndents + 2 ||
              RawCharacter(string[numIndents + 1]) != "/" {
            throw _ParseError(description: "A line with a single slash was not a comment.")
          }
          self = .comment(numIndents)
        } else {
          guard let substring = string
            .substring(start: numIndents, end: string.count) else {
            throw _ParseError(description: "Could not turn string into substring.")
          }
          self = .code(numIndents, substring)
        }
      }
      
      var description: String {
        switch self {
        case .code(let numIndents, let string):
          return "tab \(numIndents) | \(string.description)"
        case .closingBracket(let numIndents):
          return "tab \(numIndents) | } (closing bracket)"
        case .comment(let numIndents):
          return "tab \(numIndents) | // (comment)"
        case .whitespace:
          return "whitespace"
        }
      }
    }
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
  var count: Int { pointer.count }
  
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
  
  var description: String {
    guard pointer.count > 0 else {
      return ""
    }
    var array: [UInt8] = .init(repeating: 0, count: self.pointer.count + 1)
    memcpy(&array, pointer.baseAddress, pointer.count)
    return String(cString: array)
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
  
  init(_ rawValue: UInt8) {
    self.init(rawValue: rawValue)
  }
  
  init(unicodeScalarLiteral: Unicode.Scalar) {
    self.rawValue = UInt8(unicodeScalarLiteral.value)
  }
}
