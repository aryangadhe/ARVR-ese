@echo off
set GODOT_BIN=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT_BIN%" (
    for /r "%LOCALAPPDATA%\Microsoft\WinGet\Packages" %%f in (*godot*.exe) do (
        set GODOT_BIN=%%f
        goto found_godot
    )
)
:found_godot

echo Launching Godot 4.x Desktop Application...
"%GODOT_BIN%" --path godot %*
