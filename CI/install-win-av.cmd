REM Install script before build; for appveyor.com
REM mute output
@ECHO on

CD %APPVEYOR_BUILD_FOLDER%

REM leave some space
ECHO:
ECHO Platform: %PLATFORM%
ECHO Default build folder: %APPVEYOR_BUILD_FOLDER%
ECHO:

REM we need to update PATH with MSYS2 dirs, also it resolves ZLIB dependency and finds static one at C:/msys64/mingw64/lib/libz.dll.a,
REM while dynamic zlib is in C:\msys64\mingw64\bin\zlib1.dll
SET PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%
REM cmake will unable to compile without "MinGW\bin" path to PATH
REM set PATH=C:\MinGW\bin;%PATH% - is 32bit
SET PATH=C:\mingw-w64\x86_64-7.2.0-posix-seh-rt_v5-rev1\mingw64\bin;%PATH%
CD C:\mingw-w64
DIR
CD C:\mingw-w64\x86_64-7.2.0-posix-seh-rt_v5-rev1
DIR
CD mingw64
DIR
CD bin
DIR

REM get rid of _hypot in Phyton 3.6
CD C:\Python36-x64\include
FINDSTR  /v /c:"#define hypot _hypot" pyconfig.h > pyconfig2.h
RENAME pyconfig.h pyconfig_old.h
RENAME pyconfig2.h pyconfig.h
TYPE pyconfig.h

REM let us see what is installed within MSYS2
bash -lc "pacman -Q"

REM Remove python2
bash -lc "pacman -Rsc --noconfirm python2"
REM Remove python2 from PATH
SET PATH=%PATH:C:\Python27;=%
SET PATH=%PATH:C:\Python27\Scripts;=%

REM Do not build all stuff, just terminate here
REM exit 1

REM Create downloads folder for external dependencies
IF NOT EXIST "%APPVEYOR_BUILD_FOLDER%\downloads" mkdir %APPVEYOR_BUILD_FOLDER%\downloads

REM Download FFmpeg dependencies
CD %APPVEYOR_BUILD_FOLDER%\downloads
IF NOT EXIST "ffmpeg-20190429-ac551c5-win64-dev.zip" curl -kLO https://ffmpeg.zeranoe.com/builds/win64/dev/ffmpeg-20190429-ac551c5-win64-dev.zip -f --retry 4
IF NOT EXIST "ffmpeg-20190429-ac551c5-win64-shared.zip" curl -kLO https://ffmpeg.zeranoe.com/builds/win64/shared/ffmpeg-20190429-ac551c5-win64-shared.zip -f --retry 4
DIR
7z x ffmpeg-20190429-ac551c5-win64-dev.zip -offmpeg
7z x ffmpeg-20190429-ac551c5-win64-shared.zip -offmpeg -aoa
REM
REM Keep all in one folder
REM
REM First archive
CD %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg\ffmpeg-20190429-ac551c5-win64-dev
REM Move folders
FOR /d %%x IN (*) do (move "%%x" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM Move files
FOR %%x IN (*) do (move "%%x" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM
REM Second archive
CD %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg\ffmpeg-20190429-ac551c5-win64-shared
REM Move folders
FOR /d %%x IN (*) do (move "%%x" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM Move files
FOR %%x IN (*) do (move "%%x" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM
CD %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg
REM Add ffmpeg folders to PATH
SET FFMPEGDIR=%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg

REM Resolve Qt depenndency
REM set QTDIR=C:\Qt\5.12.2
CD C:\Qt\5.12.2\mingw73_64
DIR
REM update PATH
SET PATH=C:\Qt\5.12.2\mingw73_64\bin;%PATH%

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
IF EXIST "C:\OPS\UTpp" goto :UnitTestppInstalled
CD %APPVEYOR_BUILD_FOLDER%\downloads
SETLOCAL
SET UnitTestppSHA1=bc5d87f484cac2959b0a0eafbde228e69e828d74
ECHO %UnitTestppSHA1%
IF NOT EXIST "UnitTestpp.zip" curl -kL "https://github.com/unittest-cpp/unittest-cpp/archive/%UnitTestppSHA1%.zip" -f --retry 4 --output UnitTestpp.zip
DIR
REM RENAME %UnitTestppSHA1%.zip UnitTestpp.zip
7z x UnitTestpp.zip
RENAME "unittest-cpp-%UnitTestppSHA1%" unittest-cpp
DIR
ENDLOCAL
REM
REM Build it with MinGW
REM
CD unittest-cpp
DIR
MKDIR build
CD build
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=10 -DCMAKE_INSTALL_PREFIX=C:/OPS/UTpp ..
mingw32-make
mingw32-make install
REM
REM Here UnitTest++ already installed
:UnitTestppInstalled
REM
REM Set environment variable
SET UNITTEST_DIR=C:\OPS\UTpp
REM IF NOT DEFINED ProgramFiles(x86) set UNITTEST_DIR=%ProgramFiles%\UnitTest++

REM Resolve libopenshot-audio dependency
CD %APPVEYOR_BUILD_FOLDER%\downloads
REM Get current hash
git ls-remote https://github.com/SuslikV/libopenshot-audio.git patch-1 > current-head.txt
IF EXIST current-head.txt (
  ECHO libopenshot-audio current:
  TYPE current-head.txt
)
IF EXIST last-libopenshot-audio.txt (
  ECHO libopenshot-audio cached:
  TYPE last-libopenshot-audio.txt
)
REM Compare current to cached hash, recompile if hash fails
FC current-head.txt last-libopenshot-audio.txt > NUL
IF errorlevel 1 GOTO :InstLibAudio
IF EXIST "C:\OPS\libopenshot-audio" GOTO :LibAudioInstalled
:InstLibAudio
REM Store last compiled hash value to cache it later
git ls-remote https://github.com/SuslikV/libopenshot-audio.git patch-1 > last-libopenshot-audio.txt
REM clone and checkout patch-1 branch
git clone --branch patch-1 https://github.com/SuslikV/libopenshot-audio.git
DIR
CD libopenshot-audio
DIR
REM Make new building dir
MKDIR build
CD build
cmake --version
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=10 -DCMAKE_INSTALL_PREFIX=C:/OPS/libopenshot-audio ..
mingw32-make --version
mingw32-make
mingw32-make install
REM Here libopenshot-audio already installed
:LibAudioInstalled
SET LIBOPENSHOT_AUDIO_DIR=C:\OPS\libopenshot-audio

REM Resolve Python3 dependency
SET PYTHONHOME=C:\Python36-x64
SET PATH=C:\Python36-x64;C:\Python36-x64\Scripts;%PATH%
CD C:\Python36-x64
DIR
CD C:\Python36-x64\libs
DIR
CD C:\Python36-x64\include
DIR


REM unmute output
@ECHO on
