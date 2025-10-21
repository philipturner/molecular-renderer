mkdir .build
cd .build

:: Download each binary dependency from the Internet.
powershell -c "Invoke-WebRequest -Uri 'https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.0/openmm-windows.zip' -OutFile 'openmm-windows.zip'"

:: Decompress each ZIP file into a hierarchy of folders.
powershell -c "Import-Module Microsoft.Powershell.Archive"
powershell -c "Expand-Archive -Force 'openmm-windows.zip' 'openmm-windows'"

:: I don't know why, but ZIP files packaged myself always have an extra level
:: of directory hierarchy than the ZIP for DXCompiler. If I try to work around
:: this, the OS marks 'openmm-windows.zip' as a virus and removes it before I
:: can do anything with it. The way the binaries are now, it doesn't detect as
:: a virus. However, downloading from Microsoft Edge causes some strange
:: waiting period within the OS UI, before it can be unzipped.
copy /Y openmm-windows\openmm-windows\OpenMM.dll "../OpenMM.dll"
copy /Y openmm-windows\openmm-windows\OpenMM.lib "../OpenMM.lib"
copy /Y openmm-windows\openmm-windows\OpenMMOpenCL.dll "../OpenMMOpenCL.dll"
