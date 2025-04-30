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

// Prototype for the final form of the C interface.
extern "C"
__declspec(dllexport)
int8_t dxcompiler_compile(const char *shaderSource, uint32_t shaderSourceLength) {
  ComPtr<IDxcUtils> pUtils;
  DxcCreateInstance(CLSID_DxcUtils, IID_PPV_ARGS(pUtils.GetAddressOf()));
  
  ComPtr<IDxcBlobEncoding> pSource;
  pUtils->CreateBlob(shaderSource, shaderSourceLength, CP_UTF8, pSource.GetAddressOf());
  
  ComPtr<IDxcCompiler3> pCompiler;
  DxcCreateInstance(CLSID_DxcCompiler, IID_PPV_ARGS(pCompiler.GetAddressOf()));
  
  return shaderSourceLength;
}
