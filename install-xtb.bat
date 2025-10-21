mkdir .build
cd .build

:: Download each binary dependency from the Internet.
powershell -c "Invoke-WebRequest -Uri 'https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.0/xtb-windows.zip' -OutFile 'xtb-windows.zip'"

:: Decompress each ZIP file into a hierarchy of folders.
powershell -c "Import-Module Microsoft.Powershell.Archive"
powershell -c "Expand-Archive -Force 'xtb-windows.zip' 'xtb-windows'"

copy /Y xtb-windows\xtb-windows\xtb.dll "../xtb.dll"
copy /Y xtb-windows\xtb-windows\libgcc_s_seh-1.dll "../libgcc_s_seh-1.dll"
copy /Y xtb-windows\xtb-windows\libgfortran-5.dll "../libgfortran-5.dll"
copy /Y xtb-windows\xtb-windows\libgomp-1.dll "../libgomp-1.dll"
copy /Y xtb-windows\xtb-windows\libopenblas.dll "../libopenblas.dll"
copy /Y xtb-windows\xtb-windows\libquadmath-0.dll "../libquadmath-0.dll"
copy /Y xtb-windows\xtb-windows\libwinpthread-1.dll "../libwinpthread-1.dll"
