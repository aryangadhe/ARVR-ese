@echo off
echo ====================================================================
echo   VR HUMANOID ROBOT SIMULATOR - LAUNCHER
echo   Engineering ESE Project - Aryan and Vilas
echo ====================================================================

REM Locate Godot Executable
set GODOT_BIN=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT_BIN%" (
    for /r "%LOCALAPPDATA%\Microsoft\WinGet\Packages" %%f in (*godot*.exe) do (
        set GODOT_BIN=%%f
        goto found_godot
    )
)
:found_godot

echo Locating Python Interpreter...
set PYTHON_BIN=python
if exist "C:\Users\aryan\anaconda3\python.exe" (
    set PYTHON_BIN=C:\Users\aryan\anaconda3\python.exe
)
echo Using Python: %PYTHON_BIN%

echo Starting Python Physics Simulation Backend on port 9099...
start "Humanoid Physics Backend" cmd /k ""%PYTHON_BIN%" -m python.main"

echo Waiting for backend server initialization...
ping 127.0.0.1 -n 3 >nul

echo Starting Godot 4.x Desktop Application...
if exist "%GODOT_BIN%" (
    start "Godot Humanoid Visualizer" "%GODOT_BIN%" --path godot
) else (
    echo [ERROR] Godot executable not found at %GODOT_BIN%
    echo Please install or run Godot manually pointing to the godot/ directory.
)

echo Simulation running.

