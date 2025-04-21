// Imports for DXC symbols.
#include "dxcapi.h"

// Imports for ComPtr<>.
#include <wrl.h>
using namespace Microsoft::WRL;

// Imports for debugging.
#include <iostream>

// Function for testing a tutorial for DXCompiler.
extern "C"
__declspec(dllexport)
int8_t function(int8_t argument) {
  // Specify the shader source code.
  int8_t* shaderSource = (int8_t*)malloc(5);
  shaderSource[0] = 'h';
  shaderSource[1] = 'j';
  shaderSource[2] = 'k';
  shaderSource[3] = '\n';
  shaderSource[4] = '0';
  
  // MARK: - Code Snippet 1
  
  ComPtr<IDxcUtils> pUtils;
  DxcCreateInstance(CLSID_DxcUtils, IID_PPV_ARGS(pUtils.GetAddressOf()));
  ComPtr<IDxcBlobEncoding> pSource;
  pUtils->CreateBlob(shaderSource, 4, CP_UTF8, pSource.GetAddressOf());
  
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
  
  return argument * argument;
}
