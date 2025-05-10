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

// Compiles the function and returns an error code.
//
// WARNING: The caller must deallocate any pointers returned by this function.
// On the Swift side, use 'Data.init(bytesNoCopy:)' with the deallocator set to
// '.free'.
extern "C"
__declspec(dllexport)
uint8_t dxcompiler_compile(
  const char *source,
  uint32_t sourceLength,
  uint8_t **object,
  uint32_t *objectLength,
  uint8_t **rootSignature,
  uint32_t *rootSignatureLength
) {
  ComPtr<IDxcUtils> utils;
  DxcCreateInstance(CLSID_DxcUtils, IID_PPV_ARGS(utils.GetAddressOf()));
  
  ComPtr<IDxcBlobEncoding> sourceBlob;
  utils->CreateBlob(source, sourceLength, CP_UTF8, sourceBlob.GetAddressOf());
  
  ComPtr<IDxcCompiler3> compiler;
  DxcCreateInstance(CLSID_DxcCompiler, IID_PPV_ARGS(compiler.GetAddressOf()));
  
  return 0;
}
