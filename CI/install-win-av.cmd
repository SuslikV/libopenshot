REM Install script before build; for appveyor.com
REM mute output
@echo off

cd %APPVEYOR_BUILD_FOLDER%

REM leave some space
echo:
echo Platform: %PLATFORM%
echo Default build folder: %APPVEYOR_BUILD_FOLDER%
echo:

REM look for python 3.6
bash -lc "pacman -Ss python3"

exit 1

REM we need to update PATH with MSYS2 dirs, also it resolves ZLIB dependency and finds static one at C:/msys64/mingw64/lib/libz.dll.a,
REM while dynamic zlib is in C:\msys64\mingw64\bin\zlib1.dll
set PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%
REM cmake will unable to compile without "MinGW\bin" path to PATH
REM set PATH=C:\MinGW\bin;%PATH% - is 32bit
set PATH=C:\mingw-w64\x86_64-8.1.0-posix-seh-rt_v6-rev0\bin;%PATH%

REM let us see what is installed within MSYS2
bash -lc "pacman -Q"

REM Create downloads folder for external dependencies
IF NOT EXIST "%APPVEYOR_BUILD_FOLDER%\downloads" mkdir %APPVEYOR_BUILD_FOLDER%\downloads

REM Download FFmpeg dependencies
cd %APPVEYOR_BUILD_FOLDER%\downloads
IF NOT EXIST "ffmpeg-20190429-ac551c5-win64-dev.zip" curl -kLO https://ffmpeg.zeranoe.com/builds/win64/dev/ffmpeg-20190429-ac551c5-win64-dev.zip -f --retry 4
IF NOT EXIST "ffmpeg-20190429-ac551c5-win64-shared.zip" curl -kLO https://ffmpeg.zeranoe.com/builds/win64/shared/ffmpeg-20190429-ac551c5-win64-shared.zip -f --retry 4
dir
7z x ffmpeg-20190429-ac551c5-win64-dev.zip -offmpeg
7z x ffmpeg-20190429-ac551c5-win64-shared.zip -offmpeg -aoa
REM
REM Keep all in one folder
REM
REM first archive
cd %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg\ffmpeg-20190429-ac551c5-win64-dev
REM move folders
for /d %%x in (*) do (move "%%x" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM move files
for %%x in (*) do (move "%%x" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM
REM second archive
cd %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg\ffmpeg-20190429-ac551c5-win64-shared
REM move folders
for /d %%x in (*) do (move "%%x" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM move files
for %%x in (*) do (move "%%x" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM
cd %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg
REM Add ffmpeg folders to PATH
set FFMPEGDIR=%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg

REM Resolve Qt depenndency
REM set QTDIR=C:\Qt\5.12.2
cd C:\Qt\5.12.2\mingw73_64
dir
REM update PATH
set PATH=C:\Qt\5.12.2\mingw73_64\bin;%PATH%

REM Resolve ZMQ dependency
bash -lc "pacman -S --needed --noconfirm mingw64/mingw-w64-x86_64-zeromq"
REM
REM let us see what is installed now within MSYS2
REM bash -lc "pacman -Q"

REM Resolve SWIG dependency
bash -lc "pacman -S --needed --noconfirm mingw64/mingw-w64-x86_64-swig"
REM
REM let us see what is installed now within MSYS2
bash -lc "pacman -Q"

REM Resolve UnitTest++ Dependency
IF EXIST "%ProgramFiles(x86)%\UnitTest++" goto :UnitTestppInstalled
cd %APPVEYOR_BUILD_FOLDER%\downloads
SETLOCAL
set UnitTestppSHA1=bc5d87f484cac2959b0a0eafbde228e69e828d74
echo %UnitTestppSHA1%
IF NOT EXIST "UnitTestpp.zip" curl -kL "https://github.com/unittest-cpp/unittest-cpp/archive/%UnitTestppSHA1%.zip" -f --retry 4 --output UnitTestpp.zip
dir
REM ren %UnitTestppSHA1%.zip UnitTestpp.zip
7z x UnitTestpp.zip
ren "unittest-cpp-%UnitTestppSHA1%" unittest-cpp
dir
ENDLOCAL
REM
REM Build it with MinGW
REM
cd unittest-cpp
dir
mkdir build
cd build
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" ..
mingw32-make
mingw32-make install
REM
REM Here UnitTest++ already installed
:UnitTestppInstalled
REM
REM Set environment variable
set UNITTEST_DIR=%ProgramFiles(x86)%\UnitTest++
IF NOT DEFINED ProgramFiles(x86) set UNITTEST_DIR=%ProgramFiles%\UnitTest++
REM Check if it was set correctly
set

REM Resolve libopenshot-audio dependency
cd %APPVEYOR_BUILD_FOLDER%\downloads
IF EXIST "%ProgramFiles(x86)%\libopenshot-audio" goto :libopenshot-audioInstalled
REM clone and checkout patch-1 branch
git clone --branch patch-1 https://github.com/SuslikV/libopenshot-audio.git
dir
cd libopenshot-audio
dir
REM Make new building dir
mkdir build
cd build
cmake --version
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" ..
mingw32-make --version
mingw32-make VERBOSE=1
mingw32-make install
REM Here libopenshot-audio already installed
:libopenshot-audioInstalled
set LIBOPENSHOT_AUDIO_DIR=%ProgramFiles(x86)%\libopenshot-audio

REM Resolve Python3 dependency
REM set PYTHONHOME=C:\Python36-x64
REM set PATH=C:\Python36-x64;C:\Python36-x64\Scripts;%PATH%
cd C:\Python36-x64
dir
cd C:\Python36-x64\libs
dir

REM unmute output
@echo on
