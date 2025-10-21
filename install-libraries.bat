mkdir .build
cd .build

:: Download each binary dependency from the Internet.
powershell -c "Invoke-WebRequest -Uri 'https://github.com/microsoft/DirectXShaderCompiler/releases/download/v1.8.2505.1/dxc_2025_07_14.zip' -OutFile 'dxc_2025_07_14.zip'"
powershell -c "Invoke-WebRequest -Uri 'https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/raw/main/Kits/FidelityFX/signedbin/amd_fidelityfx_upscaler_dx12.dll' -OutFile 'amd_fidelityfx_upscaler_dx12.dll'"
powershell -c "Invoke-WebRequest -Uri 'https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/raw/main/Kits/FidelityFX/signedbin/amd_fidelityfx_upscaler_dx12.lib' -OutFile 'amd_fidelityfx_upscaler_dx12.lib'"

:: Decompress each ZIP file into a hierarchy of folders.
powershell -c "Import-Module Microsoft.Powershell.Archive"
powershell -c "Expand-Archive -Force 'dxc_2025_07_14.zip' 'dxc_2025_07_14'"

copy /Y dxc_2025_07_14\bin\x64\dxcompiler.dll "../dxcompiler.dll"
copy /Y dxc_2025_07_14\lib\x64\dxcompiler.lib "../dxcompiler.lib"
copy /Y amd_fidelityfx_upscaler_dx12.dll "../amd_fidelityfx_upscaler_dx12.dll"
copy /Y amd_fidelityfx_upscaler_dx12.lib "../amd_fidelityfx_upscaler_dx12.lib"
