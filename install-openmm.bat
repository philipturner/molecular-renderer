:: Step into the build folder, to isolate the immediate effects of file
:: processing operations from the top-level folder.
mkdir .build
cd .build

:: Download each binary dependency from the Internet.
::
:: Strange Google Drive bug: fails on the first ever download for this PC,
:: works on the second one.
::
:: Because of this problem, it's better to isolate this install script from
:: the one for DXC and FidelityFX.
::
:: Is the solution reproducible?
::
:: No!
::powershell -c "Invoke-WebRequest -Uri 'https://drive.google.com/uc?id=178baamEi-Dy85nLUkjCAK0HgtIHtIsfG&authuser=0&export=download' -OutFile 'openmm-windows.zip'"
copy /Y "../openmm-windows.zip" "openmm-windows.zip"

:: Decompress each ZIP file into a hierarchy of folders.
powershell -c "Import-Module Microsoft.Powershell.Archive"
powershell -c "Expand-Archive -Force 'openmm-windows.zip' 'openmm-windows'"

:: Workaround for issue with the linker on Windows: binaries must all reside
:: in the top-level folder.
copy /Y openmm-windows\OpenMM.dll "../OpenMM.dll"
copy /Y openmm-windows\OpenMM.lib "../OpenMM.lib"
copy /Y openmm-windows\OpenMMOpenCL.dll "../OpenMMOpenCL.dll"
