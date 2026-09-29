@echo off
python build_current_parent.py
if errorlevel 1 (
  echo.
  echo CURRENT PARENT BUILD FAILED
  pause
  exit /b 1
)
echo.
echo Current parent build complete: ssb64asm.z64
@echo %cmdcmdline%|find /i """%~f0""">nul && pause
