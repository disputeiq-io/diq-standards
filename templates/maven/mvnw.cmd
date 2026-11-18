@echo off
setlocal

set "DIQ_JDK21=%USERPROFILE%\.jdks\temurin-21"
if exist "%DIQ_JDK21%\bin\java.exe" set "JAVA_HOME=%DIQ_JDK21%"
if exist "%DIQ_JDK21%\bin\java.exe" set "PATH=%DIQ_JDK21%\bin;%PATH%"

set "CACHED_MVN=%USERPROFILE%\.m2\wrapper\dists\apache-maven-3.9.5-bin\2adeog8mj13csp1uusqnc1f2mo\apache-maven-3.9.5\bin\mvn.cmd"
if exist "%CACHED_MVN%" goto run_cached

where mvn >nul 2>nul
if errorlevel 1 goto not_found
call mvn %*
exit /b %ERRORLEVEL%

:run_cached
call "%CACHED_MVN%" %*
exit /b %ERRORLEVEL%

:not_found
echo ERROR: Neither cached Maven 3.9.5 (%CACHED_MVN%) nor global 'mvn' was found. 1>&2
exit /b 1
