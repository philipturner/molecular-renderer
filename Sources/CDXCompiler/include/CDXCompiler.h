
///////////////////////////////////////////////////////////////////////////////
//                                                                           //
// dxcapi.h                                                                  //
// Copyright (C) Microsoft Corporation. All rights reserved.                 //
// This file is distributed under the University of Illinois Open Source     //
// License. See LICENSE.TXT for details.                                     //
//                                                                           //
// Provides declarations for the DirectX Compiler API entry point.           //
//                                                                           //
///////////////////////////////////////////////////////////////////////////////

// MARK: - Macros

#ifndef __DXC_API__
#define __DXC_API__

#ifdef _WIN32
#ifndef DXC_API_IMPORT
#define DXC_API_IMPORT __declspec(dllimport)
#endif
#else
#ifndef DXC_API_IMPORT
#define DXC_API_IMPORT __attribute__((visibility("default")))
#endif
#endif

#ifdef _WIN32

#include <windows.h>

#else

#include "WinAdapter.h"
#include <dlfcn.h>
#endif

struct IMalloc;

typedef HRESULT(__stdcall *DxcCreateInstanceProc)(_In_ REFCLSID rclsid,
                                                  _In_ REFIID riid,
                                                  _Out_ LPVOID *ppv);

DXC_API_IMPORT
    HRESULT __stdcall DxcCreateInstance(_In_ REFCLSID rclsid, _In_ REFIID riid,
                                        _Out_ LPVOID *ppv);

#define DXC_CP_UTF8 65001
#define DXC_CP_UTF16 1200
#define DXC_CP_UTF32 12000
#define DXC_CP_ACP 0

/// Feedback that SwiftPM is registering changes.
#define DXC_CP_UTF88 16

// MARK: - Simple Data Structures

typedef struct DxcShaderHash {
  UINT32 Flags;
  BYTE HashDigest[16];
} DxcShaderHash;

typedef struct DxcBuffer {
  LPCVOID Ptr;
  SIZE_T Size;
  UINT Encoding;
} DxcBuffer;

typedef struct DxcDefine {
  LPCWSTR Name;
  LPCWSTR Value;
} DxcDefine;

// MARK: - IDxcBlob

struct IDxcBlob;

typedef struct IDxcBlobVtbl {
  // IUnknown
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    struct IDxcBlob *pThis,
    REFIID riid,
    void **ppvObject);
  ULONG (STDMETHODCALLTYPE *AddRef)(
    struct IDxcBlob *pThis);
  ULONG (STDMETHODCALLTYPE *Release)(
    struct IDxcBlob *pThis);

  // IDxcBlob
  LPVOID (STDMETHODCALLTYPE *GetBufferPointer)(
    struct IDxcBlob *pThis);
  SIZE_T (STDMETHODCALLTYPE *GetBufferSize)(
    struct IDxcBlob *pThis);
} IDxcBlobVtbl;

typedef struct IDxcBlob {
  const struct IDxcBlobVtbl *lpVtbl;
} IDxcBlob;

// MARK: - IDxcBlobEncoding

struct IDxcBlobEncoding;

typedef struct IDxcBlobEncodingVtbl {
  // IUnknown
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    struct IDxcBlobEncoding *pThis,
    REFIID riid,
    void **ppvObject);
  ULONG (STDMETHODCALLTYPE *AddRef)(
    struct IDxcBlobEncoding *pThis);
  ULONG (STDMETHODCALLTYPE *Release)(
    struct IDxcBlobEncoding *pThis);

  // IDxcBlob
  LPVOID (STDMETHODCALLTYPE *GetBufferPointer)(
    struct IDxcBlobEncoding *pThis);
  SIZE_T (STDMETHODCALLTYPE *GetBufferSize)(
    struct IDxcBlobEncoding *pThis);

  // IDxcBlobEncoding
  HRESULT (STDMETHODCALLTYPE *GetEncoding)(
    struct IDxcBlobEncoding *pThis,
    BOOL *pKnown,
    UINT32 *pCodePage);
} IDxcBlobEncodingVtbl;

typedef struct IDxcBlobEncoding {
  const struct IDxcBlobEncodingVtbl *lpVtbl;
} IDxcBlobEncoding;

// MARK: - IDxcBlobWide

struct IDxcBlobWide;

// MARK: - IDxcBlobUtf8

struct IDxcBlobUtf8;

typedef struct IDxcBlobUtf8Vtbl {
  // IUnknown
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    struct IDxcBlobUtf8 *pThis,
    REFIID riid,
    void **ppvObject);
  ULONG (STDMETHODCALLTYPE *AddRef)(
    struct IDxcBlobUtf8 *pThis);
  ULONG (STDMETHODCALLTYPE *Release)(
    struct IDxcBlobUtf8 *pThis);

  // IDxcBlob
  LPVOID (STDMETHODCALLTYPE *GetBufferPointer)(
    struct IDxcBlobUtf8 *pThis);
  SIZE_T (STDMETHODCALLTYPE *GetBufferSize)(
    struct IDxcBlobUtf8 *pThis);

  // IDxcBlobEncoding
  HRESULT (STDMETHODCALLTYPE *GetEncoding)(
    struct IDxcBlobUtf8 *pThis,
    BOOL *pKnown,
    UINT32 *pCodePage);

  // IDxcBlobUtf8
  LPCSTR (STDMETHODCALLTYPE *GetStringPointer)(
    struct IDxcBlobUtf8 *pThis);
  SIZE_T (STDMETHODCALLTYPE *GetStringLength)(
    struct IDxcBlobUtf8 *pThis);
} IDxcBlobUtf8Vtbl;

typedef struct IDxcBlobUtf8 {
  const struct IDxcBlobUtf8Vtbl *lpVtbl;
} IDxcBlobUtf8;

// MARK: - IDxcIncludeHandler

struct IDxcIncludeHandler;

typedef struct IDxcIncludeHandlerVtbl {
  // IUnknown
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    struct IDxcIncludeHandler *pThis,
    REFIID riid,
    void **ppvObject);
  ULONG (STDMETHODCALLTYPE *AddRef)(
    struct IDxcIncludeHandler *pThis);
  ULONG (STDMETHODCALLTYPE *Release)(
    struct IDxcIncludeHandler *pThis);

  // IDxcIncludeHandler
  HRESULT (STDMETHODCALLTYPE *LoadSource)(
    struct IDxcIncludeHandler *pThis,
    LPCWSTR pFileName,
    struct IDxcBlob **ppIncludeSource);
} IDxcIncludeHandlerVtbl;

typedef struct IDxcIncludeHandler {
  const struct IDxcIncludeHandlerVtbl *lpVtbl;
} IDxcIncludeHandler;

// MARK: - IDxcCompilerArgs

struct IDxcCompilerArgs;

// MARK: - IDxcOperationResult

struct IDxcOperationResult;

typedef struct IDxcOperationResultVtbl {
  // IUnknown
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    struct IDxcOperationResult *pThis,
    REFIID riid,
    void **ppvObject);
  ULONG (STDMETHODCALLTYPE *AddRef)(
    struct IDxcOperationResult *pThis);
  ULONG (STDMETHODCALLTYPE *Release)(
    struct IDxcOperationResult *pThis);

  // IDxcOperationResult
  HRESULT (STDMETHODCALLTYPE *GetStatus)(
    struct IDxcOperationResult *pThis,
    HRESULT *pStatus);
  HRESULT (STDMETHODCALLTYPE *GetResult)(
    struct IDxcOperationResult *pThis,
    IDxcBlob **ppResult);
  HRESULT (STDMETHODCALLTYPE *GetErrorBuffer)(
    struct IDxcOperationResult *pThis,
    struct IDxcBlobEncoding *ppErrors);
} IDxcOperationResultVtbl;

typedef struct IDxcOperationResult {
  const struct IDxcOperationResultVtbl *lpVtbl;
} IDxcOperationResult;

// MARK: - IDxcUtils

struct IDxcUtils;

typedef struct IDxcUtilsVtbl {
  // IUnknown
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    struct IDxcUtils *pThis,
    REFIID riid,
    void **ppvObject);
  ULONG (STDMETHODCALLTYPE *AddRef)(
    struct IDxcUtils *pThis);
  ULONG (STDMETHODCALLTYPE *Release)(
    struct IDxcUtils *pThis);

  // IDxcUtils
  HRESULT (STDMETHODCALLTYPE *CreateBlobFromBlob)(
    struct IDxcUtils *pThis,
    struct IDxcBlob *pBlob,
    UINT32 offset,
    UINT32 length,
    struct IDxcBlob **ppResult);
  HRESULT (STDMETHODCALLTYPE *CreateBlobFromPinned)(
    struct IDxcUtils *pThis,
    LPCVOID pData,
    UINT32 size, UINT32 codePage,
    struct IDxcBlobEncoding **ppBlobEncoding);
  HRESULT (STDMETHODCALLTYPE *MoveToBlob)(
    struct IDxcUtils *pThis,
    LPCVOID pData,
    struct IMalloc *pIMalloc,
    UINT32 size,
    UINT32 codePage,
    struct IDxcBlobEncoding **ppBlobEncoding);
  HRESULT (STDMETHODCALLTYPE *CreateBlob)(
    struct IDxcUtils *pThis,
    LPCVOID pData,
    UINT32 size,
    UINT32 codePage,
    struct IDxcBlobEncoding **ppBlobEncoding);
  HRESULT (STDMETHODCALLTYPE *LoadFile)(
    struct IDxcUtils *pThis,
    LPCWSTR pFileName,
    UINT32 *pCodePage,
    struct IDxcBlobEncoding **ppBlobEncoding);
  HRESULT (STDMETHODCALLTYPE *CreateReadOnlyStreamFromBlob)(
    struct IDxcUtils *pThis,
    struct IDxcBlob *pBlob,
    struct IStream **ppStream);
  HRESULT (STDMETHODCALLTYPE *CreateDefaultIncludeHandler)(
    struct IDxcUtils *pThis,
    struct IDxcIncludeHandler **ppResult);
  HRESULT (STDMETHODCALLTYPE *GetBlobAsUtf8)(
    struct IDxcUtils *pThis,
    struct IDxcBlob *pBlob,
    struct IDxcBlobUtf8 **ppBlobEncoding);
  HRESULT (STDMETHODCALLTYPE *GetBlobAsWide)(
    struct IDxcUtils *pThis,
    struct IDxcBlob *pBlob,
    struct IDxcBlobWide **ppBlobEncoding);
  HRESULT (STDMETHODCALLTYPE *GetDxilContainerPart)(
    struct IDxcUtils *pThis,
    const struct DxcBuffer *pShader,
    UINT32 DxcPart,
    void **ppPartData,
    UINT32 *pPartSizeInBytes);
  HRESULT (STDMETHODCALLTYPE *CreateReflection)(
    struct IDxcUtils *pThis,
    const struct DxcBuffer *pData,
    REFIID iid,
    void **ppvReflection);
  HRESULT (STDMETHODCALLTYPE *BuildArguments)(
    struct IDxcUtils *pThis,
    LPCWSTR pSourceName,
    LPCWSTR pEntryPoint,
    LPCWSTR pTargetProfile,
    LPCWSTR *pArguments,
    UINT32 argCount,
    const struct DxcDefine *pDefines,
    UINT32 defineCount,
    struct IDxcCompilerArgs **ppArgs);
  HRESULT (STDMETHODCALLTYPE *GetPDBContents)(
    struct IDxcUtils *pThis,
    struct IDxcBlob *pPDBBlob,
    struct IDxcBlob **ppHash,
    struct IDxcBlob **ppContainer);
 } IDxcUtilsVtbl;

typedef struct IDxcUtils {
  const struct IDxcUtilsVtbl *lpVtbl;
} IDxcUtils;

// MARK: - DXC_OUT_KIND

typedef enum DXC_OUT_KIND {
  DXC_OUT_NONE = 0,
  DXC_OUT_OBJECT = 1,
  DXC_OUT_ERRORS = 2,
  DXC_OUT_PDB = 3,
  DXC_OUT_SHADER_HASH = 4,

  DXC_OUT_DISASSEMBLY = 5,
  DXC_OUT_HLSL = 6,
  DXC_OUT_TEXT = 7,

  DXC_OUT_REFLECTION = 8,
  DXC_OUT_ROOT_SIGNATURE = 9,
  DXC_OUT_EXTRA_OUTPUTS = 10,
  DXC_OUT_REMARKS = 11,
  DXC_OUT_TIME_REPORT = 12,
  DXC_OUT_TIME_TRACE = 13
} DXC_OUT_KIND;

// MARK: - IDxcResult

struct IDxcResult;

typedef struct IDxcResultVtbl {
  // IUnknown
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    struct IDxcResult *pThis,
    REFIID riid,
    void **ppvObject);
  ULONG (STDMETHODCALLTYPE *AddRef)(
    struct IDxcResult *pThis);
  ULONG (STDMETHODCALLTYPE *Release)(
    struct IDxcResult *pThis);

  // IDxcOperationResult
  HRESULT (STDMETHODCALLTYPE *GetStatus)(
    struct IDxcResult *pThis,
    HRESULT *pStatus);
  HRESULT (STDMETHODCALLTYPE *GetResult)(
    struct IDxcResult *pThis,
    struct IDxcBlob **ppResult);
  HRESULT (STDMETHODCALLTYPE *GetErrorBuffer)(
    struct IDxcResult *pThis,
    struct IDxcBlobEncoding *ppErrors);

  // IDxcResult
  BOOL (STDMETHODCALLTYPE *HasOutput)(
    struct IDxcResult *pThis,
    DXC_OUT_KIND dxcOutKind);
  HRESULT (STDMETHODCALLTYPE *GetOutput)(
    struct IDxcResult *pThis,
    DXC_OUT_KIND dxcOutKind,
    REFIID iid,
    void **ppvObject,
    struct IDxcBlobWide **ppOutputName);
} IDxcResultVtbl;

typedef struct IDxcResult {
  const struct IDxcResultVtbl *lpVtbl;
} IDxcResult;

// MARK: - IDxcCompiler3

struct IDxcCompiler3;

typedef struct IDxcCompiler3Vtbl {
  // IUnknown
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    struct IDxcCompiler3 *pThis,
    REFIID riid,
    void **ppvObject);
  ULONG (STDMETHODCALLTYPE *AddRef)(
    struct IDxcCompiler3 *pThis);
  ULONG (STDMETHODCALLTYPE *Release)(
    struct IDxcCompiler3 *pThis);

  // IDxcCompiler3
  HRESULT (STDMETHODCALLTYPE *Compile)(
    struct IDxcCompiler3 *pThis,
    const struct DxcBuffer *pSource,
    LPCWSTR *pArguments,
    UINT32 argCount,
    struct IDxcIncludeHandler *pIncludeHandler,
    REFIID riid,
    LPVOID *ppResult);
  HRESULT (STDMETHODCALLTYPE *Disassemble)(
    struct IDxcCompiler3 *pThis,
    const struct DxcBuffer *pObject,
    REFIID riid,
    LPVOID *ppResult);
} IDxcCompiler3Vtbl;

typedef struct IDxcCompiler3 {
  const struct IDxcCompiler3Vtbl *lpVtbl;
} IDxcCompiler3;

#endif
