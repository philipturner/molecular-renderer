#if os(Windows)
import SwiftCOM
import WinSDK

import struct Foundation.Data

@_silgen_name("dxcompiler_compile")
private func dxcompiler_compile(
  _ source: UnsafePointer<CChar>,
  _ sourceLength: UInt32,
  _ object: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ objectLength: UnsafeMutablePointer<UInt32>,
  _ rootSignature: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ rootSignatureLength: UnsafeMutablePointer<UInt32>
) -> Int32

// NOTE: This file will be changed drastically soon.
//
// The existing code doesn't require an ID3D12Device yet, so don't provide one
// in the initializer.

public struct ShaderDescriptor {
  public var source: String?
  
  public init() {
    
  }
}

public struct Shader {
  public let object: Data
  public let rootSignature: Data
  
  public init(descriptor: ShaderDescriptor) {
    guard let source = descriptor.source else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Declare the function arguments and return values.
    let sourceCount = UInt32(source.count)
    var object: UnsafeMutablePointer<UInt8>?
    var objectLength: UInt32 = .zero
    var rootSignature: UnsafeMutablePointer<UInt8>?
    var rootSignatureLength: UInt32 = .zero
    
    // Invoke the function from the DXC wrapper.
    let errorCode = dxcompiler_compile(
      source,
      sourceCount,
      &object,
      &objectLength,
      &rootSignature,
      &rootSignatureLength)
    if errorCode != 0 {
      fatalError("dxcompiler_compile failed with error code \(errorCode).")
    }
    
    // Create data objects to encapsulate the blobs' contents.
    guard let object,
          let rootSignature else {
      fatalError("This should never happen.")
    }
    self.object = Data(
      bytesNoCopy: object,
      count: Int(objectLength),
      deallocator: .free)
    self.rootSignature = Data(
      bytesNoCopy: rootSignature,
      count: Int(rootSignatureLength),
      deallocator: .free)
  }
}

#endif
