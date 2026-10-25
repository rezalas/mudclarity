@echo off
rem Build, run and test Mud Clarity on Windows. The commands live in
rem tools\build\build.odin (shared with build.sh on macOS and Linux):
rem   build.bat help
setlocal
pushd "%~dp0"
if not exist build mkdir build
odin run tools\build -out:build\build-tool.exe -- %*
set CODE=%ERRORLEVEL%
popd
exit /b %CODE%
