// Imports for DXC symbols.
#include "dxcapi.h"

// Imports for ComPtr<>.
#include <wrl.h>
using namespace Microsoft::WRL;

// Imports for debugging.
#include <iostream>
#include <vector>

// Function for testing a tutorial for DXCompiler.
extern "C"
__declspec(dllexport)
int8_t function(int8_t argument) {
  // Specify the shader source code.
  std::string shaderSource = R"(
  hjk
  
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
    L"MACRO1",
    L"MACRO2",
  };
  
  // Initialize the compiler used in subsequent code.
  ComPtr<IDxcCompiler3> pCompiler;
  DxcCreateInstance(CLSID_DxcCompiler, IID_PPV_ARGS(pCompiler.GetAddressOf()));
  std::cout << "pCompiler = " << pCompiler.Get() << std::endl;
  
  // -E for the entry point (eg. 'main')
  arguments.push_back(L"-E");
  arguments.push_back(L"main");

  // -T for the target profile (eg. 'ps_6_6')
  arguments.push_back(L"-T");
  arguments.push_back(L"ps_6_6");

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
  
  // Next steps:
  // - Create a valid HLSL shader.
  // - Proceed to the parts of the tutorial about stripping debug data and
  //   shader reflection.
  
  return argument * argument;
}
