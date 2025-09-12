@echo off

:: TODO: Recognize the cache, avoiding the latency of downloading on every
:: startup. Perhaps Batch scripting has logic capabilities of Bash, and can do
:: this inside 'install-libraries.bat'.
CALL install-libraries.bat

powershell -c "& 'C:\Program Files\Git\bin\bash.exe' run.sh"
