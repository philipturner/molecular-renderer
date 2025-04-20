:: Step into the build folder, to isolate the immediate effects of file
:: processing operations from the top-level folder.
mkdir .build
cd .build

:: Download each binary dependency from the Internet.
powershell -c "Invoke-WebRequest -Uri 'https://github.com/microsoft/DirectXShaderCompiler/releases/download/v1.8.2502/dxc_2025_02_20.zip' -OutFile 'dxc_2025_02_20.zip'"
powershell -c "Invoke-WebRequest -Uri 'https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/raw/main/PrebuiltSignedDLL/amd_fidelityfx_dx12.dll' -OutFile 'amd_fidelityfx_dx12.dll'"
powershell -c "Invoke-WebRequest -Uri 'https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/raw/main/PrebuiltSignedDLL/amd_fidelityfx_dx12.lib' -OutFile 'amd_fidelityfx_dx12.lib'"

:: Decompress each ZIP file into a hierarchy of folders.
powershell -c "Expand-Archive -Force 'dxc_2025_02_20.zip' 'dxc_2025_02_20'"

:: Workaround for issue with the linker on Windows: binaries must all reside
:: in the top-level folder.
copy /Y dxc_2025_02_20\bin\x64\dxcompiler.dll "../dxcompiler.dll"
copy /Y dxc_2025_02_20\lib\x64\dxcompiler.lib "../dxcompiler.lib"
copy /Y amd_fidelityfx_dx12.dll "../amd_fidelityfx_dx12.dll"
copy /Y amd_fidelityfx_dx12.lib "../amd_fidelityfx_dx12.lib"
