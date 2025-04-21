#include <iostream>
#include "dxcapi.h"
#include <wrl.h>
using namespace Microsoft::WRL;



extern "C"
__declspec(dllexport)
int8_t function(int8_t argument) {
  int8_t* shaderSource = (int8_t*)malloc(5);
  shaderSource[0] = 'h';
  shaderSource[1] = 'j';
  shaderSource[2] = 'k';
  shaderSource[3] = '\n';
  shaderSource[4] = '0';
  
  // TODO: Save this file to GitHub. Then, create a new Swift package and copy
  // over the files from molecular-renderer. Narrow down the crash as much as
  // possible, even reimplementing SwiftCOM if needed.
  //
  // The file works just fine with Clang:
  // clang++ File.cpp -ldxcompiler -o File
  // ./File.exe
  //
  // I wonder if we can spin up a C library that's compiled on the fly,
  // linked to the Swift module at runtime, and simply does any compilation
  // tasks we need. That would take so much less effort than porting the
  // DirectXShaderCompiler C API to Swift.
  
  ComPtr<IDxcUtils> pUtils;
  DxcCreateInstance(CLSID_DxcUtils, IID_PPV_ARGS(pUtils.GetAddressOf()));
  ComPtr<IDxcBlobEncoding> pSource;
  pUtils->CreateBlob(shaderSource, 4, CP_UTF8, pSource.GetAddressOf());
  
  std::cout << "Hello, world!" << std::endl;
  std::cout << pSource->GetBufferSize() << std::endl;
  
  return argument * argument;
}
