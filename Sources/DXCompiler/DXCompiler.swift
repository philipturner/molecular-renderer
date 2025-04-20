// Be careful which symbols are exposed to the client. There are name conflicts
// with several COM objects in the CDXCompiler module.
@_exported import var CDXCompiler.DXC_CP_UTF90
import CDXCompiler
import SwiftCOM
import WinSDK

// Single source file with all the bindings needed to use the HLSL JIT compiler.
// Complements the customized 'dxcapi.h' header in the 'CDXCompiler' Clang
// module.

// Similar to 'IUnknown.CreateInstance', but not an instance member.
public func DxcCreateInstance<Interface: SwiftCOM.IUnknown>(
  `class` clsid: CLSID
) throws -> Interface {
  var clsid: CLSID = clsid
  var iid: IID = Interface.IID

  var pointer: UnsafeMutableRawPointer?
  try SwiftCOM.CHECKED(DxcCreateInstance(&clsid, &iid, &pointer))
  return Interface(pUnk: pointer)
}

public func DxcCreateInstance2<Interface: SwiftCOM.IUnknown>(
  malloc: SwiftCOM.IMalloc,
  `class` clsid: CLSID
) throws -> Interface {
  try malloc.perform(as: WinSDK.IMalloc.self) { pMalloc in
    var clsid: CLSID = clsid
    var iid: IID = Interface.IID
    
    var pointer: UnsafeMutableRawPointer?
    try SwiftCOM.CHECKED(DxcCreateInstance2(pMalloc, &clsid, &iid, &pointer))
    return Interface(pUnk: pointer)
  }
  
}

// MARK: - Simple Data Structures

@_exported import struct CDXCompiler.DxcShaderHash
@_exported import struct CDXCompiler.DxcBuffer
@_exported import struct CDXCompiler.DxcDefine

// MARK: - IDxcBlob

public let IID_IDxcBlob = GUID(
  Data1: 0x8BA5FB08,
  Data2: 0x5195,
  Data3: 0x40e2,
  Data4: (0xAC, 0x58, 0x0D, 0x98, 0x9C, 0x3A, 0x01, 0x02))

public class IDxcBlob: SwiftCOM.IUnknown {
  public override class var IID: IID { IID_IDxcBlob }

  public func GetBufferPointer() throws -> UnsafeMutableRawPointer? {
    return try perform(as: CDXCompiler.IDxcBlob.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetBufferPointer(pThis)
    }
  }

  public func GetBufferSize() throws -> SIZE_T {
    return try perform(as: CDXCompiler.IDxcBlob.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetBufferSize(pThis)
    }
  }
}

// MARK: - IDxcBlobEncoding

public let IID_IDxcBlobEncoding = GUID(
  Data1: 0x7241d424,
  Data2: 0x2646,
  Data3: 0x4191,
  Data4: (0x97, 0xc0, 0x98, 0xe9, 0x6e, 0x42, 0xfc, 0x68))

public class IDxcBlobEncoding: IDxcBlob {
  public override class var IID: IID { IID_IDxcBlobEncoding }

  public func GetEncoding() throws -> UINT32 {
    return try perform(as: CDXCompiler.IDxcBlobEncoding.self) { pThis in
      var known: WindowsBool = WindowsBool(false)
      var codePage: UINT32 = UINT32()
      try CHECKED(pThis.pointee.lpVtbl.pointee.GetEncoding(
        pThis, &known, &codePage))

      if known == true {
        guard codePage != 0 else {
          fatalError("Unexpected value for codePage.")
        }
      } else {
        guard codePage == 0 else {
          fatalError("Unexpected value for codePage.")
        }
      }
      return codePage
    }
  }
  
  public func intReturnFunction() throws -> Int {
    let intReturn = try perform(as: WinSDK.IUnknown.self) {   pThis in
      print(pThis.pointee.lpVtbl.pointee.AddRef)
      
      print(pThis.pointee.lpVtbl.pointee.AddRef(pThis))
      return Int(2)
    }
    return intReturn
  }
}

// MARK: - IDxcBlobUtf8

public let IID_IDxcBlobUtf8 = GUID(
  Data1: 0x3DA636C9,
  Data2: 0xBA71,
  Data3: 0x4024,
  Data4: (0xA3, 0x01, 0x30, 0xCB, 0xF1, 0x25, 0x30, 0x5B))

public class IDxcBlobUtf8: IDxcBlobEncoding {
  public override class var IID: IID { IID_IDxcBlobUtf8 }
}

// MARK: - IDxcIncludeHandler

public let IID_IDxcIncludeHandler = GUID(
  Data1: 0x7f61fc7d,
  Data2: 0x950d,
  Data3: 0x467f,
  Data4: (0xb3, 0xe3, 0x3c, 0x02, 0xfb, 0x49, 0x18, 0x7c))

public class IDxcIncludeHandler: SwiftCOM.IUnknown {
  public override class var IID: IID { IID_IDxcIncludeHandler }
}

// MARK: - IDxcOperationResult

public let IID_IDxcOperationResult = GUID(
  Data1: 0xCEDB484A,
  Data2: 0xD4E9,
  Data3: 0x445A,
  Data4: (0xB9, 0x91, 0xCA, 0x21, 0xCA, 0x15, 0x7D, 0xC2))

public class IDxcOperationResult: SwiftCOM.IUnknown {
  public override class var IID: IID { IID_IDxcOperationResult }
}

// MARK: - IDxcUtils

public let IID_IDxcUtils = GUID(
  Data1: 0x4605C4CB,
  Data2: 0x2019,
  Data3: 0x492A,
  Data4: (0xAD, 0xA4, 0x65, 0xF2, 0x0B, 0xB7, 0xD6, 0x7F))

public let CLSID_DxcUtils = GUID(
  Data1: 0x6245d6af,
  Data2: 0x66e0,
  Data3: 0x48fd,
  Data4: (0x80, 0xb4, 0x4d, 0x27, 0x17, 0x96, 0x74, 0x8c))

public class IDxcUtils: SwiftCOM.IUnknown {
  public override class var IID: IID { IID_IDxcUtils }

  public func CreateBlob(
    _ pData: LPCVOID,
    _ size: UINT32,
    _ codePage: UINT32
  ) throws -> IDxcBlobEncoding {
    return try perform(as: CDXCompiler.IDxcUtils.self) { pThis in
      var pEncoding: UnsafeMutablePointer<CDXCompiler.IDxcBlobEncoding>?
      try CHECKED(pThis.pointee.lpVtbl.pointee.CreateBlob(
        pThis, pData, size, codePage, &pEncoding))

      guard let pEncoding else {
        fatalError("pEncoding was nil.")
      }
      let casted = UnsafeMutablePointer<UnsafeMutableRawPointer>(
        OpaquePointer(pEncoding))
      return IDxcBlobEncoding(pUnk: casted.pointee)
    }
  }
  
  public func intReturnFunction() throws -> Int {
    let intReturn = try perform(as: WinSDK.IUnknown.self) {   pThis in
      print(pThis.pointee.lpVtbl.pointee.AddRef)
      
      print(pThis.pointee.lpVtbl.pointee.AddRef(pThis))
      return Int(2)
    }
    return intReturn
  }
}

// MARK: - DXC_OUT_KIND

@_exported import var CDXCompiler.DXC_OUT_NONE
@_exported import var CDXCompiler.DXC_OUT_OBJECT
@_exported import var CDXCompiler.DXC_OUT_ERRORS
@_exported import var CDXCompiler.DXC_OUT_PDB
@_exported import var CDXCompiler.DXC_OUT_SHADER_HASH
@_exported import var CDXCompiler.DXC_OUT_DISASSEMBLY
@_exported import var CDXCompiler.DXC_OUT_HLSL
@_exported import var CDXCompiler.DXC_OUT_TEXT
@_exported import var CDXCompiler.DXC_OUT_REFLECTION
@_exported import var CDXCompiler.DXC_OUT_ROOT_SIGNATURE
@_exported import var CDXCompiler.DXC_OUT_EXTRA_OUTPUTS
@_exported import var CDXCompiler.DXC_OUT_REMARKS
@_exported import var CDXCompiler.DXC_OUT_TIME_REPORT
@_exported import var CDXCompiler.DXC_OUT_TIME_TRACE

// MARK: - IDxcResult

public let IID_IDxcResult = GUID(
  Data1: 0x58346CDA,
  Data2: 0xDDE7,
  Data3: 0x4497,
  Data4: (0x94, 0x61, 0x6F, 0x87, 0xAF, 0x5E, 0x06, 0x59))

public class IDxcResult: IDxcOperationResult {
  public override class var IID: IID { IID_IDxcResult }
}

// MARK: - IDxcCompiler3

public let IID_IDxcCompiler3 = GUID(
  Data1: 0x228B4687,
  Data2: 0x5A6A,
  Data3: 0x4730,
  Data4: (0x90, 0x0C, 0x97, 0x02, 0xB2, 0x20, 0x3F, 0x54))

public let CLSID_DxcCompiler = GUID(
  Data1: 0x73e22d93,
  Data2: 0xe6ce,
  Data3: 0x47f3,
  Data4: (0xb5, 0xbf, 0xf0, 0x66, 0x4f, 0x39, 0xc1, 0xb0))

public class IDxcCompiler3: SwiftCOM.IUnknown {
  public override class var IID: IID { IID_IDxcCompiler3 }

  public func Compile(
    _ pSource: UnsafePointer<DxcBuffer>,
    _ pArguments: [String],
    _ pIncludeHandler: UnsafeMutablePointer<IDxcIncludeHandler>? = nil
  ) throws -> IDxcResult {
    fatalError("Not implemented.")
  }
}
