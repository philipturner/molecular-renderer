// Imports for DXC symbols.
#include "dxcapi.h"

// Imports for ComPtr<>.
#include <wrl.h>
using namespace Microsoft::WRL;

// Imports for debugging.
#include <iostream>
#include <vector>

// Function for testing a tutorial for DXCompiler:
// https://simoncoenen.com/blog/programming/graphics/DxcCompiling
extern "C"
__declspec(dllexport)
int8_t function(int8_t argument) {
  // Specify the shader source code.
  std::string shaderSource = R"(
  //--------------------------------------------------------------------------------------
  // File: BasicCompute11.hlsl
  //
  // This file contains the Compute Shader to perform array A + array B
  //
  // Copyright (c) Microsoft Corporation.
  // Licensed under the MIT License (MIT).
  //--------------------------------------------------------------------------------------
  
  #ifdef USE_STRUCTURED_BUFFERS
  
  struct BufType
  {
      int i;
      float f;
  };
  
  StructuredBuffer<BufType> Buffer0 : register(t0);
  StructuredBuffer<BufType> Buffer1 : register(t1);
  RWStructuredBuffer<BufType> BufferOut : register(u0);
  
  [numthreads(1, 1, 1)]
  void CSMain( uint3 DTid : SV_DispatchThreadID )
  {
      BufferOut[DTid.x].i = Buffer0[DTid.x].i + Buffer1[DTid.x].i;
      BufferOut[DTid.x].f = Buffer0[DTid.x].f + Buffer1[DTid.x].f;
  }
  
  #else // The following code is for raw buffers
  
  ByteAddressBuffer Buffer0 : register(t0);
  ByteAddressBuffer Buffer1 : register(t1);
  RWByteAddressBuffer BufferOut : register(u0);
  
  [numthreads(1, 1, 1)]
  void CSMain( uint3 DTid : SV_DispatchThreadID )
  {
      int i0 = asint( Buffer0.Load( DTid.x*8 ) );
      float f0 = asfloat( Buffer0.Load( DTid.x*8+4 ) );
      int i1 = asint( Buffer1.Load( DTid.x*8 ) );
      float f1 = asfloat( Buffer1.Load( DTid.x*8+4 ) );
      
      BufferOut.Store( DTid.x*8, asuint(i0 + i1) );
      BufferOut.Store( DTid.x*8+4, asuint(f0 + f1) );
  }
  
  #endif // USE_STRUCTURED_BUFFERS
  
  )";
  
  // MARK: - Code Snippet 1
  
  ComPtr<IDxcUtils> pUtils;
  DxcCreateInstance(CLSID_DxcUtils, IID_PPV_ARGS(pUtils.GetAddressOf()));
  ComPtr<IDxcBlobEncoding> pSource;
  pUtils->CreateBlob(shaderSource.data(), shaderSource.size(), CP_UTF8, pSource.GetAddressOf());
  std::cout << "pUtils = " << pUtils.Get() << std::endl;
  std::cout << "pSource = " << pSource.Get() << std::endl;
  
  std::cout << "pSource->GetBufferPointer() = " << pSource->GetBufferPointer() << std::endl;
  std::cout << "pSource->GetBufferSize() = " << pSource->GetBufferSize() << std::endl;
  {
    BOOL known;
    UINT32 codePage;
    HRESULT result = pSource->GetEncoding(&known, &codePage);
    std::cout << "pSource->GetEncoding = (" << known;
    std::cout << ", " << codePage;
    std::cout << ", " << result;
    std::cout << ")" << std::endl;
  }
  
  // MARK: - Code Snippet 2
  
  // Initialize the arguments used in subsequent code.
  std::vector<LPCWSTR> arguments;
  
  // Initialize the defines used in subsequent code.
  std::vector<std::wstring> defines = {
    L"USE_STRUCTURED_BUFFERS",
  };
  
  // Initialize the compiler used in subsequent code.
  ComPtr<IDxcCompiler3> pCompiler;
  DxcCreateInstance(CLSID_DxcCompiler, IID_PPV_ARGS(pCompiler.GetAddressOf()));
  std::cout << "pCompiler = " << pCompiler.Get() << std::endl;
  
  // -E for the entry point (eg. 'main')
  arguments.push_back(L"-E");
  arguments.push_back(L"CSMain");
  
  // -T for the target profile (eg. 'ps_6_6')
  arguments.push_back(L"-T");
  arguments.push_back(L"cs_6_6");
  
  // Strip reflection data and pdbs (see later)
  arguments.push_back(L"-Qstrip_debug");
  arguments.push_back(L"-Qstrip_reflect");
  
  arguments.push_back(DXC_ARG_WARNINGS_ARE_ERRORS); // -WX
  arguments.push_back(DXC_ARG_DEBUG); // -Zi
  
  for (const std::wstring& define : defines) {
    arguments.push_back(L"-D");
    arguments.push_back(define.c_str());
  }
  
  DxcBuffer sourceBuffer;
  sourceBuffer.Ptr = pSource->GetBufferPointer();
  sourceBuffer.Size = pSource->GetBufferSize();
  sourceBuffer.Encoding = 0;
  
  ComPtr<IDxcResult> pCompileResult;
  {
    HRESULT result = pCompiler->Compile(&sourceBuffer, arguments.data(), (UINT32)arguments.size(), nullptr, IID_PPV_ARGS(pCompileResult.GetAddressOf()));
    std::cout << "pCompiler->Compile = " << result << std::endl;
  }
  std::cout << "pCompileResult = " << pCompileResult.Get() << std::endl;
  
  // Error Handling. Note that this will also include warnings unless disabled.
  ComPtr<IDxcBlobUtf8> pErrors;
  pCompileResult->GetOutput(DXC_OUT_ERRORS, IID_PPV_ARGS(pErrors.GetAddressOf()), nullptr);
  std::cout << "pErrors = " << pErrors.Get() << std::endl;
  
  if (pErrors && pErrors->GetStringLength() > 0) {
    std::cout << "There was an error." << std::endl;
    std::cout << (char*)pErrors->GetBufferPointer() << std::endl;
  }
  
  // MARK: - Code Snippet 3
  
  ComPtr<IDxcBlob> pDebugData;
  ComPtr<IDxcBlobUtf16> pDebugDataPath;
  pCompileResult->GetOutput(DXC_OUT_PDB, IID_PPV_ARGS(pDebugData.GetAddressOf()), pDebugDataPath.GetAddressOf());
  std::cout << "pDebugData = " << pDebugData.Get() << std::endl;
  std::cout << "pDebugDataPath = " << pDebugDataPath.Get() << std::endl;
  std::cout << "pDebugData->GetBufferSize() = " << pDebugData->GetBufferSize() << std::endl;
  std::cout << (char*)pDebugData->GetBufferPointer() << std::endl;
  std::cout << "pDebugDataPath->GetBufferSize() = " << pDebugDataPath->GetBufferSize() << std::endl;
  std::cout << "pDebugDataPath->GetStringLength() = " << pDebugDataPath->GetStringLength() << std::endl;
  std::cout << pDebugDataPath->GetBufferPointer() << std::endl;
  {
    std::wstring string1((wchar_t*)pDebugDataPath->GetBufferPointer());
    std::wstring string2(pDebugDataPath->GetStringPointer());
    std::wcout << string1 << std::endl;
    std::wcout << string2 << std::endl;
  }
  
  return argument * argument;
}
