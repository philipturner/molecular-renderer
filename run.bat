@echo off
powershell -c "& 'C:\Program Files\Git\bin\bash.exe' compile-dxc-wrapper.sh"
powershell -c "& 'C:\Program Files\Git\bin\bash.exe' run.sh"
