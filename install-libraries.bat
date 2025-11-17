mkdir .build
cd .build

:: Internet download sizes:
:: 25.9 MB | dxc_2025_07_14.zip
:: 12.8 MB | amd_fidelityfx_upscaler_dx12.dll
::  0.0 MB | amd_fidelityfx_upscaler_dx12.lib
::  2.2 MB | openmm-windows.zip
:: 19.2 MB | xtb-windows.zip

:: Download each binary dependency from the Internet.
powershell -c "Invoke-WebRequest -Uri 'https://github.com/microsoft/DirectXShaderCompiler/releases/download/v1.8.2505.1/dxc_2025_07_14.zip' -OutFile 'dxc_2025_07_14.zip'"
powershell -c "Invoke-WebRequest -Uri 'https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/raw/main/Kits/FidelityFX/signedbin/amd_fidelityfx_upscaler_dx12.dll' -OutFile 'amd_fidelityfx_upscaler_dx12.dll'"
powershell -c "Invoke-WebRequest -Uri 'https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/raw/main/Kits/FidelityFX/signedbin/amd_fidelityfx_upscaler_dx12.lib' -OutFile 'amd_fidelityfx_upscaler_dx12.lib'"

:: TODO: Update this to v1.0.1 after fixing macOS.
powershell -c "Invoke-WebRequest -Uri 'https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.0/openmm-windows.zip' -OutFile 'openmm-windows.zip'"
powershell -c "Invoke-WebRequest -Uri 'https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.0/xtb-windows.zip' -OutFile 'xtb-windows.zip'"

:: Decompress each ZIP file into a hierarchy of folders.
powershell -c "Import-Module Microsoft.Powershell.Archive"
powershell -c "Expand-Archive -Force 'dxc_2025_07_14.zip' 'dxc_2025_07_14'"
powershell -c "Expand-Archive -Force 'openmm-windows.zip' 'openmm-windows'"
powershell -c "Expand-Archive -Force 'xtb-windows.zip' 'xtb-windows'"

copy /Y dxc_2025_07_14\bin\x64\dxcompiler.dll "../dxcompiler.dll"
copy /Y dxc_2025_07_14\lib\x64\dxcompiler.lib "../dxcompiler.lib"
copy /Y amd_fidelityfx_upscaler_dx12.dll "../amd_fidelityfx_upscaler_dx12.dll"
copy /Y amd_fidelityfx_upscaler_dx12.lib "../amd_fidelityfx_upscaler_dx12.lib"

:: I don't know why, but ZIP files packaged myself always have an extra level
:: of directory hierarchy than the ZIP for DXCompiler. If I try to work around
:: this, the OS marks 'openmm-windows.zip' as a virus and removes it before I
:: can do anything with it. The way the binaries are now, the OS doesn't flag
:: OpenMM as a virus. However, downloading from Microsoft Edge causes some
:: strange waiting period within the OS UI, before it can be unzipped.
copy /Y openmm-windows\openmm-windows\OpenMM.dll "../OpenMM.dll"
copy /Y openmm-windows\openmm-windows\OpenMM.lib "../OpenMM.lib"
copy /Y openmm-windows\openmm-windows\OpenMMOpenCL.dll "../OpenMMOpenCL.dll"

copy /Y xtb-windows\xtb-windows\xtb.dll "../xtb.dll"
copy /Y xtb-windows\xtb-windows\libgcc_s_seh-1.dll "../libgcc_s_seh-1.dll"
copy /Y xtb-windows\xtb-windows\libgfortran-5.dll "../libgfortran-5.dll"
copy /Y xtb-windows\xtb-windows\libgomp-1.dll "../libgomp-1.dll"
copy /Y xtb-windows\xtb-windows\libopenblas.dll "../libopenblas.dll"
copy /Y xtb-windows\xtb-windows\libquadmath-0.dll "../libquadmath-0.dll"
copy /Y xtb-windows\xtb-windows\libwinpthread-1.dll "../libwinpthread-1.dll"
