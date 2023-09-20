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
      if lastStart != contents.count {
        let string = RawString(
          pointer: bytes + lastStart, count: contents.count - lastStart)
        lines.append(try Line(rawValue: string))
      }
    }
    
    print()
    print("=== AST ===")
    for line in lines {
      print(line.description)
    }
    
    var stack: [Keyword] = []
    for line in lines {
      switch line {
      case .code(_, let tokens):
        guard case .keyword(let keyword) = tokens.first! else {
          throw _ParseError(description: "Expected code to start with a keyword: \(tokens.description)")
        }
        
        switch keyword {
        case .concave, .convex, .volume:
          guard tokens.count == 2,
                case .openingBracket = tokens[1] else {
            throw _ParseError(description: "Expected opening bracket after first token: \(tokens.description)")
          }
          switch keyword {
          case .concave: Compiler.global.startConcave()
          case .convex: Compiler.global.startConvex()
          case .volume: Compiler.global.startVolume()
          default: fatalError("This should never happen.")
          }
          stack.append(keyword)
        case .cut:
          guard tokens.count == 1 else {
            throw _ParseError(description: "Expected no tokens after Cut: \(tokens.description)")
          }
          Cut()
        case .material:
          guard tokens.count == 4 else {
            throw _ParseError(description: "Expected three tokens after Material: \(tokens.description)")
          }
          guard case .openingBracket = tokens[1],
                case .expression(.element(let element)) = tokens[2],
                case .closingBracket = tokens[3] else {
            throw _ParseError(description: "Expected bracket, element, bracket after Material: \(tokens.description)")
          }
          Material { element }
        default:
          guard tokens.count >= 4 else {
            throw _ParseError(description: "Expected at least three tokens after \(tokens[0].description): \(tokens.description)")
          }
          guard case .openingBracket = tokens[1],
                case .closingBracket = tokens[tokens.count - 1] else {
            throw _ParseError(description: "Expected bracket, multiple tokens, bracket after \(tokens[0].description): \(tokens.description)")
          }
          
          func parseVector(range: Range<Int>) throws -> Vector<Cubic> {
            var output: Vector<Cubic> = .init(simdValue: .zero)
            var lastScalar: (Int, Float)?
            var lastOperator: (Int, Operator)?
            var lastVector: (Int, Vector<Cubic>)?
            for i in range {
              guard case .expression(let expression) = tokens[i] else {
                throw _ParseError(description: "Expected expression but got '\(tokens[i].description): \(tokens.description)")
              }
              func invalidExpression(_ reason: String? = nil) -> _ParseError {
                _ParseError(description: "Invalid syntax at token '\(expression.description)': \(tokens.description)\nReason: \(reason ?? "[unknown]")")
              }
              func debugDiagnostics() {
                print("")
                print("i = \(i)")
                print("  output: \(output)")
                print("  lastScalar: \(lastScalar as Any)")
                print("  lastOperator: \(lastOperator as Any)")
                print("  lastVector: \(lastVector as Any)")
              }
              if i % 2 == 0 {
                if case .number(let number) = expression {
                  defer { lastScalar = (i, number) }
                  guard let lastOperator else { continue }
                  if lastOperator == (i - 1, .times) {
                    guard lastScalar == nil ||
                            lastScalar!.0 != i - 2 else {
                      throw invalidExpression("Two scalars sandwiched between a times")
                    }
                    guard let (lastVectorID, lastVector) = lastVector,
                          lastVectorID == i - 2 else {
                      throw invalidExpression("No vector to precede a scalar in a times")
                    }
                    output = output + lastVector * number
                  }
                } else if case .cubicAxis(let cubicAxis) = expression {
                  debugDiagnostics()
                  defer { lastVector = (i, cubicAxis) }
                  guard let lastOperator else { continue }
                  if lastOperator == (i - 1, .times) {
                    debugDiagnostics()
                    guard lastVector == nil ||
                            lastVector!.0 != i - 2 else {
                      throw invalidExpression("Two vectors sandwiched between a times")
                    }
                    guard let (lastScalarID, lastScalar) = lastScalar,
                          lastScalarID == i - 2 else {
                      throw invalidExpression("No scalar to precede a vector in a times")
                    }
                    print("  output <- \(output) + \(lastScalar) * \(cubicAxis)")
                    output = output + lastScalar * cubicAxis
                    print("  output = \(output)")
                  } else if lastOperator.0 == i - 1, i == range.upperBound - 1 {
                    // Immediately add to output if there aren't any more tokens.
                    print("  newVector: \(cubicAxis)")
                    if lastOperator.1 == .times {
                      fatalError("This should never happen: times at closing.")
                    } else if lastOperator.1 == .plus {
                      print("  output <- \(output) + \(cubicAxis)")
                      output = output + cubicAxis
                      print("  output = \(output)")
                    } else {
                      print("  output <- \(output) - \(cubicAxis)")
                      output = output - cubicAxis
                      print("  output = \(output)")
                    }
                  }
                } else {
                  throw _ParseError(description: "Expected number or axis at even-numbered token '\(expression.description): \(tokens.description)")
                }
              } else {
                if case .`operator`(let `operator`) = expression {
                  defer { lastOperator = (i, `operator`) }
                  if `operator` == .times {
                    guard let (lastOperatorID, _) = lastOperator else {
                      continue
                    }
                    if lastOperatorID == i - 1 {
                      throw invalidExpression("Two consecutive operators.")
                    }
                  } else if let (lastScalarID, _) = lastScalar,
                            lastScalarID == i - 1 {
                    throw invalidExpression("Retained a scalar without merging it with a vector.")
                  } else if let (lastVectorID, lastVector) = lastVector,
                            lastVectorID == i - 1 {
                    guard let (lastOperatorID, lastOperator) = lastOperator else {
                      debugDiagnostics()
                      print("  output <- \(lastVector)")
                      output = output + lastVector
                      print("  output = \(output)")
                      continue
                    }
                    if lastOperatorID == i - 1 {
                      throw invalidExpression("Two consecutive operators.")
                    }
                    if lastOperatorID != i - 2 {
                      continue
                    }
                    if lastOperator == .times {
                      // This should hopefully already be handled correctly.
                    } else if lastOperator == .plus {
                      debugDiagnostics()
                      print("  output <- \(output) + \(lastVector)")
                      output = output + lastVector
                      print("  output = \(output)")
                    } else {
                      debugDiagnostics()
                      print("  output <- \(output) - \(lastVector)")
                      output = output - lastVector
                      print("  output = \(output)")
                    }
                  }
                } else {
                  throw _ParseError(description: "Expected operator at odd-numbered token '\(expression.description): \(tokens.description)")
                }
              }
            }
            return output
          }
          
          // TODO: Support the vector input argument required for Ridge/Valley.
          let output = try parseVector(range: 2..<tokens.count - 1)
          switch keyword {
          case .bounds: Bounds { output }
          case .origin: Origin { output }
          case .plane: Plane { output }
          case .ridge: fatalError("Not implemented.")
          case .valley: fatalError("Not implemented.")
          default: fatalError("This should never happen.")
          }
        }
      case .closingBracket(_):
        let keyword = stack.removeLast()
        switch keyword {
        case .bounds, .cut, .material, .origin, .plane, .ridge, .valley:
          throw _ParseError(description: "Popped an unexpected keyword from the stack: '\(keyword.description)'")
        case .concave: Compiler.global.endConcave()
        case .convex: Compiler.global.endConvex()
        case .volume: Compiler.global.endVolume()
        }
      case .comment(_):
        continue
      case .whitespace:
        continue
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

fileprivate struct RawString: Equatable, ExpressibleByStringLiteral, CustomStringConvertible {
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

// Only comments on their own line are allowed for now.
// Bracket initializers for language keywords must all be on one line.
fileprivate enum Line {
  case code(Int, [Token])
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
      var tokenStrings: [RawString] = []
      var lastStart: Int = 0
      
      for i in 0..<substring.count {
        if RawCharacter(substring[i]) == " " {
          if lastStart == i {
            throw _ParseError(description: "Cannot have two consecutive spaces in a code line, even from trailing whitespace. Unable to parse line: '\(substring.description)'")
          }
          let tokenString = RawString(
            pointer: substring.pointer.baseAddress! + lastStart,
            count: i - lastStart)
          tokenStrings.append(tokenString)
          lastStart = i + 1
        }
      }
      if lastStart != substring.count {
        let tokenString = RawString(
          pointer: substring.pointer.baseAddress! + lastStart,
          count: substring.count - lastStart)
        tokenStrings.append(tokenString)
      }
      
      // Until we've debugged the separation into different substrings, don't call any token initializers. Also, the strings need to be separated into
      // different substrings in a pre-pass due to the need to handle the very
      // last segment.
      let tokens = try tokenStrings.map(Token.init(rawValue:))
      self = .code(numIndents, tokens)
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

// TODO: Support parentheses in expressions.
// TODO: Support simple for loops on an array of vector expressions?
fileprivate enum Token: CustomStringConvertible {
  // Unsure of the most formal wording for "{" and "}"; this is probably
  // incorrect. Calling them "opening bracket" and "closing bracket" for now.
  case keyword(Keyword)
  case openingBracket
  case expression(Expression)
  case closingBracket
  
  init(rawValue string: RawString) throws {
    guard string.count > 0, RawCharacter(string[string.count - 1]) != " " else {
      throw _ParseError(description: "Malformatted string entered into 'Token' initializer: '\(string.description)'")
    }
    if string[0] >= 65 && string[0] <= 90 {
      // Uppercase ASCII characters.
      self = .keyword(try Keyword(rawValue: string))
    } else if RawCharacter(string[0]) == "{" {
      guard string.count == 1 else {
        throw _ParseError(description: "Too many characters in opening bracket token: '\(string.description)'")
      }
      self = .openingBracket
    } else if RawCharacter(string[0]) == "}" {
      guard string.count == 1 else {
        throw _ParseError(description: "Too many characters in closing bracket token: '\(string.description)'")
      }
      self = .closingBracket
    } else {
      self = .expression(try Expression(rawValue: string))
    }
  }
  
  var description: String {
    switch self {
    case .keyword(let keyword):
      return ".keyword(\(keyword.description))"
    case .openingBracket:
      return ".openingBracket"
    case .expression(let expression):
      return ".expression(\(expression.description)"
    case .closingBracket:
      return ".closingBracket"
    }
  }
}

fileprivate enum Keyword: CustomStringConvertible {
  case bounds
  case concave
  case convex
  case cut
  case material
  case origin
  case plane
  case ridge
  case valley
  case volume
  
  init(rawValue string: RawString) throws {
    switch string {
    case "Bounds":
      self = .bounds
    case "Concave":
      self = .concave
    case "Convex":
      self = .convex
    case "Cut()":
      self = .cut
    case "Material":
      self = .material
    case "Origin":
      self = .origin
    case "Plane":
      self = .plane
    case "Ridge":
      self = .ridge
    case "Valley":
      self = .valley
    case "Volume":
      self = .volume
    default:
      throw _ParseError(description: "Unrecognized keyword: '\(string.description)'")
    }
  }
  
  var description: String {
    switch self {
    case .bounds: return "Bounds"
    case .concave: return "Concave"
    case .convex: return "Convex"
    case .cut: return "Cut"
    case .material: return "Material"
    case .origin: return "Origin"
    case .plane: return "Plane"
    case .ridge: return "Ridge"
    case .valley: return "Valley"
    case .volume: return "Volume"
    }
  }
}

fileprivate enum Expression: CustomStringConvertible {
  // A prefix operator (+/-) may be prepended to any axis.
  case cubicAxis(Vector<Cubic>)
  // Moissanite ([.carbon, .silicon]) not supported yet.
  case element(Element)
  case number(Float)
  case `operator`(Operator)
  
  init(rawValue string: RawString) throws {
    if string == "+" {
      self = .operator(.plus)
    } else if string == "-" {
      self = .operator(.minus)
    } else if string == "*" {
      self = .operator(.times)
    } else if string.starts(with: ".") {
      switch string {
      case ".hydrogen":
        self = .element(.hydrogen)
      case ".carbon":
        self = .element(.carbon)
      case ".silicon":
        self = .element(.silicon)
      case ".germanium":
        self = .element(.germanium)
      default:
        throw _ParseError(description: "Unrecognized element: '\(string.description)'")
      }
    } else if string[string.count - 1] == 104 ||
                string[string.count - 1] == 107 ||
                string[string.count - 1] == 108 {
      guard string.count >= 1 && string.count <= 2 else {
        throw _ParseError(description: "Unrecognized axis: '\(string.description)'")
      }
      var vector: Vector<Cubic>
      switch string[string.count - 1] {
      case 104: vector = h
      case 107: vector = k
      case 108: vector = l
      default: fatalError("This should never happen.")
      }
      if string.count == 2 {
        if string.starts(with: "+") {
          vector = +vector
        } else if string.starts(with: "-") {
          vector = -vector
        } else {
          throw _ParseError(description: "Invalid prefix operator for axis: '\(string.description)'")
        }
      }
      self = .cubicAxis(vector)
    } else {
      guard let float = Float(string.description) else {
        throw _ParseError(description: "Invalid number: '\(string.description)'")
      }
      self = .number(float)
    }
  }
  
  var description: String {
    switch self {
    case .cubicAxis(let vector):
      return ".cubicAxis(\(vector.simdValue))"
    case .element(let element):
      return ".element(\(element.description))"
    case .number(let number):
      return ".number(\(number))"
    case .operator(let `operator`):
      return ".operator(\(`operator`.description))"
    }
  }
}

fileprivate enum Operator: CustomStringConvertible {
  case plus
  case minus
  case times
  
  var description: String {
    switch self {
    case .plus: return ".plus"
    case .minus: return ".minus"
    case .times: return ".times"
    }
  }
}


