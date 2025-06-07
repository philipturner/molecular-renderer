// Imports for DXC symbols.
#include "dxcapi.h"
#include <d3d12shader.h>

// Imports for ComPtr<>.
#include <wrl.h>
using namespace Microsoft::WRL;

// Other miscellaneous imports.
#include <cstdint>
#include <iostream>
#include <vector>

// Reduce the boilerplate for checking HRESULT values.
#define CHECK_HRESULT(message) \
if (errorCode != 0) { \
  std::cerr << message << std::endl; \
  return errorCode; \
} \

// Compiles the function and returns an error code.
//
// WARNING: The caller must deallocate any pointers returned by this function.
// On the Swift side, use 'Data.init(bytesNoCopy:)' with the deallocator set to
// '.free'.
extern "C"
__declspec(dllexport)
int32_t dxcompiler_compile(
  const char *source,
  uint32_t sourceLength,
  const wchar_t *name,
  uint32_t nameLength,
  uint8_t **object,
  uint32_t *objectLength,
  uint8_t **rootSignature,
  uint32_t *rootSignatureLength
) {
  // Initialize the resources.
  
  ComPtr<IDxcUtils> utils;
  DxcCreateInstance(CLSID_DxcUtils, IID_PPV_ARGS(utils.GetAddressOf()));
  
  ComPtr<IDxcBlobEncoding> sourceBlob;
  utils->CreateBlob(source, sourceLength, CP_UTF8, sourceBlob.GetAddressOf());
  
  ComPtr<IDxcCompiler3> compiler;
  DxcCreateInstance(CLSID_DxcCompiler, IID_PPV_ARGS(compiler.GetAddressOf()));
  
  // Specify the compiler arguments.
  
  std::vector<LPCWSTR> arguments;
  arguments.push_back(L"-E");
  arguments.push_back(name);
  arguments.push_back(L"-T");
  arguments.push_back(L"cs_6_5");
  arguments.push_back(L"-Qstrip_debug");
  arguments.push_back(L"-Qstrip_reflect");
  arguments.push_back(DXC_ARG_WARNINGS_ARE_ERRORS);
  arguments.push_back(DXC_ARG_DEBUG);
  
  // Invoke the compile function.
  
  DxcBuffer sourceBuffer;
  sourceBuffer.Ptr = sourceBlob->GetBufferPointer();
  sourceBuffer.Size = sourceBlob->GetBufferSize();
  sourceBuffer.Encoding = 0;
  
  ComPtr<IDxcResult> result;
  {
    HRESULT errorCode = compiler->Compile(&sourceBuffer, arguments.data(), uint32_t(arguments.size()), nullptr, IID_PPV_ARGS(result.GetAddressOf()));
    CHECK_HRESULT("IDxcCompiler3::Compile failed.")
  }
  
  // Check for errors. If there are any, return an error code.
  
  ComPtr<IDxcBlobUtf8> errorsBlob;
  {
    HRESULT errorCode = result->GetOutput(DXC_OUT_ERRORS, IID_PPV_ARGS(errorsBlob.GetAddressOf()), nullptr);
    CHECK_HRESULT("IDxcResult::GetOutput(DXC_OUT_ERRORS) failed.")
  }
  
  if (errorsBlob->GetStringLength() > 0) {
    std::cerr << (char*)errorsBlob->GetBufferPointer() << std::endl;
    return 1;
  }
  
  // Retrieve the object. Copy its contents to a fresh pointer.
  
  ComPtr<IDxcBlob> objectBlob;
  {
    HRESULT errorCode = result->GetOutput(DXC_OUT_OBJECT, IID_PPV_ARGS(objectBlob.GetAddressOf()), nullptr);
    CHECK_HRESULT("IDxcResult::GetOutput(DXC_OUT_OBJECT) failed.")
  }
  
  {
    // Retrieve the length of the object.
    *objectLength = objectBlob->GetBufferSize();
    if (*objectLength == 0) {
      std::cerr << "Object blob was empty." << std::endl;
      return 1;
    }
    
    // Create a pointer for the object.
    *object = (uint8_t*)malloc(*objectLength);
    
    // Copy the blob's contents to the pointer.
    void *blobPointer = objectBlob->GetBufferPointer();
    memcpy(*object, blobPointer, *objectLength);
  }
  
  // Retrieve the root signature. Copy its contents to a fresh pointer.
  
  ComPtr<IDxcBlob> rootSignatureBlob;
  {
    HRESULT errorCode = result->GetOutput(DXC_OUT_ROOT_SIGNATURE, IID_PPV_ARGS(rootSignatureBlob.GetAddressOf()), nullptr);
    CHECK_HRESULT("IDxcResult::GetOutput(DXC_OUT_ROOT_SIGNATURE) failed.")
  }
  
  {
    // Retrieve the length of the root signature.
    *rootSignatureLength = rootSignatureBlob->GetBufferSize();
    if (*rootSignatureLength == 0) {
      std::cerr << "Root signature blob was empty." << std::endl;
      return 1;
    }
    
    // Create a pointer for the object.
    *rootSignature = (uint8_t*)malloc(*rootSignatureLength);
    
    // Copy the blob's contents to the pointer.
    void *blobPointer = rootSignatureBlob->GetBufferPointer();
    memcpy(*rootSignature, blobPointer, *rootSignatureLength);
  }
  
  return 0;
}
