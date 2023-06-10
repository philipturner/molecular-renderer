//
//  ParsingUtilities.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/4/23.
//

import Foundation

func startError(
  _ start: any StringProtocol,
  _ sequence: any StringProtocol,
  line: UInt = #line,
  function: StaticString = #function
) -> Never {
  fatalError(
    "'\(start)' is not the start of '\(sequence)'.",
    file: (function), line: line)
}

func assertExpectedPrefix<T: StringProtocol>(
  _ prefix: String,
  from text: T
) where T == T.SubSequence {
  guard text.starts(with: prefix) else {
    startError(prefix, text)
  }
}

func removeExpectedPrefix<T: StringProtocol>(
  _ prefix: String,
  from text: inout T
) where T == T.SubSequence {
  assertExpectedPrefix(prefix, from: text)
  text.removeFirst(prefix.count)
}

func removeIncluding<T: StringProtocol>(
  _ prefix: String,
  from text: inout T
) where T == T.SubSequence {
  while text.starts(with: prefix) {
    text.removeFirst(prefix.count)
  }
}

func removeExcluding<T: StringProtocol>(
  _ prefix: String,
  from text: inout T
) where T == T.SubSequence {
  while !text.starts(with: prefix) {
    text.removeFirst(prefix.count)
  }
}

func extractExcluding<T: StringProtocol>(
  _ prefix: String,
  from text: inout T
) -> String where T == T.SubSequence {
  var output: String = ""
  while !text.starts(with: prefix) {
    output += text.prefix(prefix.count)
    text = text.dropFirst(prefix.count)
  }
  return output
}

func largeIntegerRepr(_ number: Int) -> String {
  if number < 1_000 {
    return String(number)
  } else if number < 1_000_000 {
    let radix = 1_000
    return "\(number / radix).\(number % radix / 100) thousand"
  } else if number < 1_000_000_000 {
    let radix = 1_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) million"
  } else if number < 1_000_000_000_000 {
    let radix = 1_000_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) billion"
  } else {
    let radix = 1_000_000_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) trillion"
  }
}

func latencyRepr<T: BinaryFloatingPoint>(_ number: T) -> String {
  let number = Int(rint(Double(number) * 1e6)) // microseconds
  if number < 1_000 {
    return "\(number) µs"
  } else if number < 1_000_000 {
    let radix = 1_000
    return "\(number / radix).\(number % radix / (radix / 10)) ms"
  } else if number < 60 * 1_000_000 {
    let radix = 1_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) s"
  } else if number < 3_600 * 1_000_000 {
    let radix = 60 * 1_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) min"
  } else {
    let radix = 3_600 * 1_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) hr"
  }
}
