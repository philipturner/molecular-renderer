mkdir .build
cd .build

:: Download each binary dependency from the Internet.
copy /Y ..\xtb-windows.zip "./xtb-windows.zip"

:: Decompress each ZIP file into a hierarchy of folders.
powershell -c "Import-Module Microsoft.Powershell.Archive"
powershell -c "Expand-Archive -Force 'xtb-windows.zip' 'xtb-windows'"

:: Workaround for issue with the linker on Windows: binaries must all reside
:: in the top-level folder.
copy /Y xtb-windows\xtb.dll "../xtb.dll"
copy /Y xtb-windows\libgcc_s_seh-1.dll "../libgcc_s_seh-1.dll"
copy /Y xtb-windows\libgfortran-5.dll "../libgfortran-5.dll"
copy /Y xtb-windows\libgomp-1.dll "../libgomp-1.dll"
copy /Y xtb-windows\libopenblas.dll "../libopenblas.dll"
copy /Y xtb-windows\libquadmath-0.dll "../libquadmath-0.dll"
copy /Y xtb-windows\libwinpthread-1.dll "../libwinpthread-1.dll"
