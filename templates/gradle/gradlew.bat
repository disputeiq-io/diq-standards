@echo off
setlocal

set "DIQ_JDK21=%USERPROFILE%\.jdks\temurin-21"
if exist "%DIQ_JDK21%\bin\java.exe" set "JAVA_HOME=%DIQ_JDK21%"
if exist "%DIQ_JDK21%\bin\java.exe" set "PATH=%DIQ_JDK21%\bin;%PATH%"

set "LOCAL_GRADLE=%USERPROFILE%\.gradle\gradle-8.10.2\bin\gradle.bat"
if exist "%LOCAL_GRADLE%" goto run_local

set "FALLBACK_GRADLE=D:\Projects\diple-engine\backend\tools\gradle-8.10.2\bin\gradle.bat"
if exist "%FALLBACK_GRADLE%" goto run_fallback

where gradle >nul 2>nul
if errorlevel 1 goto not_found
call gradle %*
exit /b %ERRORLEVEL%

:run_local
call "%LOCAL_GRADLE%" %*
exit /b %ERRORLEVEL%

:run_fallback
call "%FALLBACK_GRADLE%" %*
exit /b %ERRORLEVEL%

:not_found
echo ERROR: Neither local Gradle 8.10.2 (%LOCAL_GRADLE%) nor global 'gradle' was found. 1>&2
exit /b 1
