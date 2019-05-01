REM Install script before build; for appveyor.com
REM mute output
@echo off

cd %APPVEYOR_BUILD_FOLDER%

REM leave some space
echo:
echo Platform: %PLATFORM%
echo Default build folder: %APPVEYOR_BUILD_FOLDER%
echo:

REM we need to update PATH with MSYS2 dirs, also it resolves ZLIB dependency and finds static one at C:/msys64/mingw64/lib/libz.dll.a,
REM while dynamic zlib is in C:\msys64\mingw64\bin\zlib1.dll
set PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%

REM let us see what is installed within MSYS2
bash -lc "pacman -Q"

REM unmute output
@echo on
