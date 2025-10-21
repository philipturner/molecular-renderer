mkdir .build
cd .build

:: Download each binary dependency from the Internet.
copy /Y ..\openmm-windows.zip "./openmm-windows.zip"

:: Decompress each ZIP file into a hierarchy of folders.
powershell -c "Import-Module Microsoft.Powershell.Archive"
powershell -c "Expand-Archive -Force 'openmm-windows.zip' 'openmm-windows'"

:: Workaround for issue with the linker on Windows: binaries must all reside
:: in the top-level folder.
copy /Y openmm-windows\OpenMM.dll "../OpenMM.dll"
copy /Y openmm-windows\OpenMM.lib "../OpenMM.lib"
copy /Y openmm-windows\OpenMMOpenCL.dll "../OpenMMOpenCL.dll"
