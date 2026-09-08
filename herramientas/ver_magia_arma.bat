@echo off
REM Doble clic aqui para comprobar el HECHIZO DE SERIE del arma: el baston y la varita prestan el
REM Pulso menor mientras los lleves, pero no te lo enseñan. Comprueba que entra al equipar, que si
REM lo quitas a mano NO vuelve, que al soltar el arma se va, y que nunca se cuela en lo APRENDIDO
REM (que es lo unico que se guarda). No saca capturas: escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_magia_arma.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." res://tools/visores/dev_magia_arma.tscn
pause
