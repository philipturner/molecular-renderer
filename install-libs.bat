:: Download the latest version of DirectXShaderCompiler.
cd .build
powershell -c "Invoke-WebRequest -Uri 'https://github.com/microsoft/DirectXShaderCompiler/releases/download/v1.8.2502/dxc_2025_02_20.zip' -OutFile 'dxc_2025_02_20.zip'"

:: Decompress the ZIP into a hierarchy of folders.
powershell -c "Expand-Archive -Force 'dxc_2025_02_20.zip' 'dxc_2025_02_20'"

:: Copy the DLL into the top-level folder (for now).
copy /Y dxc_2025_02_20\bin\x64\dxcompiler.dll "../"
copy /Y dxc_2025_02_20\lib\x64\dxcompiler.lib "../"

:: TODO: Redirect the library links to the build folder, if possible. Currently,
:: we use a workaround. The libraries go into the top-level folder, and the
:: '.gitignore' explicitly ignores '.dll' and '.lib'.
