//
//  Vector.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 5/6/23.
//

import Foundation
import simd

// MARK: - Boilerplate code for VectorBlock implementation

protocol VectorBlock {
  associatedtype Scalar
  
  static var scalarCount: Int { get }
  
  static var zero: Self { get }
  
  func forEachElement(_ closure: (Int, Scalar) -> Void)
}

extension UInt8: VectorBlock {
  static var scalarCount: Int { 1 }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Self) -> Void) { closure(0, self) }
}

extension Float: VectorBlock {
  static var scalarCount: Int { 1 }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Self) -> Void) { closure(0, self) }
}

extension Double: VectorBlock {
  static var scalarCount: Int { 1 }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Self) -> Void) { closure(0, self) }
}

extension SIMD2: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD4: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD8: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD16: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD32: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD64: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

// WARNING: Make sure to avoid copy-on-write semantics!
struct Vector<T> {
  var count: Int
  var alignedCount: Int
  private(set) var elements: [T]
  var bufferPointer: UnsafeMutableBufferPointer<T>
  
  init(repeating repeatedValue: T, count: Int, alignment: Int) {
    self.count = count
    self.alignedCount = ~(alignment - 1) & (count + alignment - 1)
    self.elements = Array(repeating: repeatedValue, count: alignedCount)
    self.bufferPointer = elements.withUnsafeMutableBufferPointer { $0 }
  }
  
  // A highly performant index into the array.
  @inline(__always)
  mutating func setElement(_ value: T, index: Int) {
    #if DEBUG
    elements.withUnsafeMutableBufferPointer { bufferPointer in
      assert(index >= 0 && index < self.count)
      assert(self.bufferPointer.baseAddress == bufferPointer.baseAddress)
      assert(self.bufferPointer.count == bufferPointer.count)
    }
    let baseAddress = self.bufferPointer.baseAddress!
    #else
    let baseAddress = self.bufferPointer.baseAddress.unsafelyUnwrapped
    #endif

    baseAddress[index] = value
  }
  
  // A highly performant index into the array.
  @inline(__always)
  mutating func setElement<
    U: VectorBlock
  >(_ value: U, type: U.Type, actualIndex: Int) {
    #if DEBUG
    elements.withUnsafeMutableBufferPointer { bufferPointer in
      assert(actualIndex >= 0 && actualIndex < self.count)
      assert(self.bufferPointer.baseAddress == bufferPointer.baseAddress)
      assert(self.bufferPointer.count == bufferPointer.count)
      assert(actualIndex % U.scalarCount == 0)
    }
    let baseAddress = self.bufferPointer.baseAddress!
    #else
    let baseAddress = self.bufferPointer.baseAddress.unsafelyUnwrapped
    #endif

    let castedAddress = unsafeBitCast(
      baseAddress + actualIndex, to: UnsafeMutablePointer<U>.self)
    castedAddress.pointee = value
  }
  
  // A highly performant index into the array.
  @inline(__always)
  mutating func getElement(index: Int) -> T {
    #if DEBUG
    elements.withUnsafeMutableBufferPointer { bufferPointer in
      assert(index >= 0 && index < self.count)
      assert(self.bufferPointer.baseAddress == bufferPointer.baseAddress)
      assert(self.bufferPointer.count == bufferPointer.count)
    }
    let baseAddress = self.bufferPointer.baseAddress!
    #else
    let baseAddress = self.bufferPointer.baseAddress.unsafelyUnwrapped
    #endif
    
    return baseAddress[index]
  }
  
  // A highly performant index into the array.
  @inline(__always)
  mutating func getElement<
    U: VectorBlock
  >(type: U.Type, actualIndex: Int) -> U {
    #if DEBUG
    elements.withUnsafeMutableBufferPointer { bufferPointer in
      assert(actualIndex >= 0 && actualIndex < self.count)
      assert(self.bufferPointer.baseAddress == bufferPointer.baseAddress)
      assert(self.bufferPointer.count == bufferPointer.count)
      assert(actualIndex % U.scalarCount == 0)
    }
    let baseAddress = self.bufferPointer.baseAddress!
    #else
    let baseAddress = self.bufferPointer.baseAddress.unsafelyUnwrapped
    #endif

    let castedAddress = unsafeBitCast(
      baseAddress + actualIndex, to: UnsafeMutablePointer<U>.self)
    return castedAddress.pointee
  }
}
