@echo off
setlocal enabledelayedexpansion
REM start.bat - Windows entry-point formatki Szem (adapter-omp). ZAMYKA gap#5:
REM   tooly gitolite/workspace MUSZA isc w WSL/Linux; ten .bat routuje Cie do WSL,
REM   zeby outsider na Windows NIE utknal na git-bash (bash -> WSL-relay pada: /bin/bash not found).
REM
REM Uzycie:
REM   start.bat setup ^<manifest.conf^>                  - postaw instancje (sudo bootstrap-instancji.sh w WSL)
REM   start.bat agent ^<manifest.conf^> ^<imie^> ^<rola^>    - zbuduj workspace agenta (workspace-builder.sh w WSL)
REM   start.bat wsl                                     - wejdz do WSL w katalogu formatki
REM
REM Env (opcjonalne): SZEM_WSL_DISTRO=Ubuntu-24.04 (domyslnie: domyslna dystrybucja WSL;
REM   jesli domyslna nie ma sudo/apt - ustaw na pelna dystrybucje Linuksa).

where wsl >nul 2>nul
if errorlevel 1 (
  echo BLAD: brak WSL. Zainstaluj: wsl --install ^&^& restart.
  exit /b 1
)

set "DISTRO_ARG="
if defined SZEM_WSL_DISTRO set "DISTRO_ARG=-d %SZEM_WSL_DISTRO%"
set "HERE=%~dp0"
set "CMD=%~1"

if /i "%CMD%"=="setup" goto :do_setup
if /i "%CMD%"=="agent" goto :do_agent
if /i "%CMD%"=="wsl"   goto :do_wsl
goto :usage

:do_setup
if "%~2"=="" (
  echo Uzycie: start.bat setup ^<manifest.conf^>
  exit /b 1
)
for /f "usebackq delims=" %%p in (`wsl %DISTRO_ARG% wslpath -a "%~2"`) do set "MAN=%%p"
for /f "usebackq delims=" %%p in (`wsl %DISTRO_ARG% wslpath -a "%HERE%bootstrap-instancji.sh"`) do set "BS=%%p"
echo [start.bat] WSL: sudo bash bootstrap-instancji.sh !MAN!
wsl %DISTRO_ARG% -e sudo bash "!BS!" "!MAN!"
exit /b !errorlevel!

:do_agent
if "%~4"=="" (
  echo Uzycie: start.bat agent ^<manifest.conf^> ^<imie^> ^<rola^>
  exit /b 1
)
for /f "usebackq delims=" %%p in (`wsl %DISTRO_ARG% wslpath -a "%~2"`) do set "MAN=%%p"
for /f "usebackq delims=" %%p in (`wsl %DISTRO_ARG% wslpath -a "%HERE%workspace-builder.sh"`) do set "WB=%%p"
echo [start.bat] WSL: bash workspace-builder.sh !MAN! %~3 %~4
wsl %DISTRO_ARG% -e bash "!WB!" "!MAN!" "%~3" "%~4"
exit /b !errorlevel!

:do_wsl
for /f "usebackq delims=" %%p in (`wsl %DISTRO_ARG% wslpath -a "%HERE%"`) do set "HH=%%p"
wsl %DISTRO_ARG% --cd "!HH!"
exit /b !errorlevel!

:usage
echo Szem Windows-entry (adapter-omp) - zamyka gap#5 (tooly wymagaja WSL/Linux).
echo   start.bat setup ^<manifest.conf^>
echo   start.bat agent ^<manifest.conf^> ^<imie^> ^<rola^>
echo   start.bat wsl
exit /b 1
