REM Install script before build; for appveyor.com
REM mute output
@ECHO on

CD %APPVEYOR_BUILD_FOLDER%

REM leave some space
ECHO:
ECHO Platform: %PLATFORM%
ECHO Default build folder: %APPVEYOR_BUILD_FOLDER%
ECHO Dependencies folder: %OPENSHOT_DEPS_DIR%
ECHO Install folder: %OPENSHOT_INST_DIR%
ECHO Python folder: %PYTHONHOME%
ECHO Qt is %OPENSHOT_QT_SOURCE%
ECHO:

REM We need to update PATH with MSYS2 dirs, also it resolves ZLIB dependency and finds static one at C:/msys64/mingw64/lib/libz.dll.a,
REM while dynamic zlib is in C:\msys64\mingw64\bin\zlib1.dll
SET PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%
REM cmake will unable to compile without "MinGW\bin" path to PATH
SET OPENSHOT_COMPILER_BINDIR=C:\mingw-w64\x86_64-7.3.0-posix-seh-rt_v5-rev0\mingw64\bin
SET PATH=%OPENSHOT_COMPILER_BINDIR%;%PATH%

REM Create downloads folder for external dependencies
IF NOT EXIST "%APPVEYOR_BUILD_FOLDER%\downloads" MKDIR %APPVEYOR_BUILD_FOLDER%\downloads

REM Restore cached Python folder, with some PyQt5 modules installed
CD %PYTHONHOME%
DIR
CD "%APPVEYOR_BUILD_FOLDER%\downloads"
IF NOT EXIST "%APPVEYOR_BUILD_FOLDER%\downloads\python-%PLATFORM%.7z" curl -kL https://github.com/SuslikV/libopenshot/raw/build-deps/win-x64/Python3-x64-withPyQt5-5122-win-N456.7z -f --retry 4 --output python-%PLATFORM%.7z
CD C:\
IF EXIST "%APPVEYOR_BUILD_FOLDER%\downloads\python-%PLATFORM%.7z" (
    REM Wipe destination dir silently, suppress the message that process is using current folder
    CD %PYTHONHOME% & RMDIR /s /q %PYTHONHOME% 2> NUL
    DIR
    ECHO Restoring Python with PyQt5 package to %PYTHONHOME%
    CD "%APPVEYOR_BUILD_FOLDER%\downloads"
    7z x python-%PLATFORM%.7z -aoa -o%PYTHONHOME%
    CD %PYTHONHOME%
    DIR
) ELSE (
    ECHO Unable to download/install Python files
    EXIT 1
)

REM Resolve libopenshot-audio dependency
REM We build it first because it requires less dependencies in comparison to libopenshot library
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
IF errorlevel 1 GOTO InstLibAudio
IF EXIST "%OPENSHOT_DEPS_DIR%\libopenshot-audio" GOTO LibAudioInstalled
:InstLibAudio
REM Remove libopenshot-audio destination folder for clear install
IF EXIST "%OPENSHOT_DEPS_DIR%\libopenshot-audio" RMDIR "%OPENSHOT_DEPS_DIR%\libopenshot-audio" /s /q
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
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=6.1 -DCMAKE_INSTALL_PREFIX:PATH="%OPENSHOT_DEPS_DIR%\libopenshot-audio" ..
mingw32-make --version
mingw32-make
mingw32-make install
REM Here libopenshot-audio already installed
:LibAudioInstalled
SET LIBOPENSHOT_AUDIO_DIR=%OPENSHOT_DEPS_DIR%\libopenshot-audio

REM new MSYS2 holders
bash -lc "curl -O http://repo.msys2.org/msys/x86_64/msys2-keyring-r21.b39fb11-1-any.pkg.tar.xz"
bash -lc "curl -O http://repo.msys2.org/msys/x86_64/msys2-keyring-r21.b39fb11-1-any.pkg.tar.xz.sig"
bash -lc "pacman-key --verify msys2-keyring-r21.b39fb11-1-any.pkg.tar.xz.sig"

REM Update MSYS2 itself
bash -lc "pacman -Syu --noconfirm"

REM Remove python2, just to not mess up the things later
bash -lc "pacman -Rsc --noconfirm python2"
REM Remove python2 from PATH
SET PATH=%PATH:C:\Python27;=%
SET PATH=%PATH:C:\Python27\Scripts;=%

IF "%OPENSHOT_QT_SOURCE%" == "DEPS_FOLDER" GOTO unpackQtDeps

REM Download FFmpeg dependencies, libopenshot
CD %APPVEYOR_BUILD_FOLDER%\downloads
IF NOT EXIST "ffmpeg-3.4.2-win64-dev.zip" curl -kLO https://ffmpeg.zeranoe.com/builds/win64/dev/ffmpeg-3.4.2-win64-dev.zip -f --retry 4
IF NOT EXIST "ffmpeg-3.4.2-win64-shared.zip" curl -kLO https://ffmpeg.zeranoe.com/builds/win64/shared/ffmpeg-3.4.2-win64-shared.zip -f --retry 4
DIR
7z x ffmpeg-3.4.2-win64-dev.zip -offmpeg
7z x ffmpeg-3.4.2-win64-shared.zip -offmpeg -aoa
REM
REM Keep all in one folder
REM
REM First archive
CD %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg\ffmpeg-3.4.2-win64-dev
REM Move folders
FOR /d %%I IN (*) DO (MOVE "%%I" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM Move files
FOR %%I IN (*) DO (MOVE "%%I" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM
REM Second archive
CD %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg\ffmpeg-3.4.2-win64-shared
REM Move folders
FOR /d %%I IN (*) DO (MOVE "%%I" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM Move files
FOR %%I IN (*) DO (MOVE "%%I" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM Change current folder to move it later
CD %APPVEYOR_BUILD_FOLDER%\downloads
REM Move all stuff to one place
MOVE /y %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg %OPENSHOT_DEPS_DIR%
REM Add ffmpeg folders to PATH
SET FFMPEGDIR=%OPENSHOT_DEPS_DIR%\ffmpeg

REM Resolve ZMQ dependency
bash -lc "pacman -S --needed --noconfirm mingw64/mingw-w64-x86_64-zeromq"
REM Resolve SWIG dependency
bash -lc "pacman -S --needed --noconfirm mingw64/mingw-w64-x86_64-swig"
REM Resolve Qt depenndency
REM Insall QtWebKit and all required stuff
bash -lc "pacman -S --needed --noconfirm --disable-download-timeout mingw64/mingw-w64-x86_64-qtwebkit"
REM Workaround a MSYS2 packaging issue for Qt5, if instaled in MSYS2
REM see https://github.com/msys2/MINGW-packages/issues/5253
REM Replacing all occurrences of "C:/building/msys32" with the "C:/msys64" in C:/msys64/mingw64/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake
bash -lc "sed -i -e 's;C:\/building\/msys32;C:\/msys64;g' C:/msys64/mingw64/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake"

REM Resolve UnitTest++ Dependency, libopenshot
IF EXIST "%OPENSHOT_DEPS_DIR%\UTpp" GOTO UnitTestppInstalled
REM Remove UTpp destination folder for clear install
IF EXIST "%OPENSHOT_DEPS_DIR%\UTpp" RMDIR "%OPENSHOT_DEPS_DIR%\UTpp" /s /q
CD %APPVEYOR_BUILD_FOLDER%\downloads
SETLOCAL
SET UnitTestppSHA1=bc5d87f484cac2959b0a0eafbde228e69e828d74
ECHO %UnitTestppSHA1%
IF NOT EXIST "UnitTestpp.zip" curl -kL "https://github.com/unittest-cpp/unittest-cpp/archive/%UnitTestppSHA1%.zip" -f --retry 4 --output UnitTestpp.zip
DIR
7z x UnitTestpp.zip
RENAME "unittest-cpp-%UnitTestppSHA1%" unittest-cpp
DIR
ENDLOCAL
REM
CD unittest-cpp
DIR
MKDIR build
CD build
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=6.1 -DCMAKE_INSTALL_PREFIX:PATH="%OPENSHOT_DEPS_DIR%\UTpp" ..
mingw32-make
mingw32-make install
REM
REM Here UnitTest++ already installed
:UnitTestppInstalled
REM
REM Set environment variable
SET UNITTEST_DIR=%OPENSHOT_DEPS_DIR%\UTpp
REM Because in recent builds of libopenshot tests are not required, can be skipped as not found
REM SET UnitTest++_INCLUDE_DIRS=%OPENSHOT_DEPS_DIR%\UTpp\include
REM Here all dependencies are ready
GOTO instLibOpenShot

:unpackQtDeps
REM Unpacking Qt files and move them at default locations
CD "%APPVEYOR_BUILD_FOLDER%\downloads"
IF NOT EXIST "OpenShot-Ext-Deps-win-x64-N491m01.7z" curl -kLO https://github.com/SuslikV/libopenshot/raw/build-deps/win-x64/OpenShot-Ext-Deps-win-x64-N491m01.7z -f --retry 4
7z x OpenShot-Ext-Deps-win-x64-N491m01.7z
DIR
REM Move Qt files in place
IF NOT EXIST "C:\msys64\mingw64\bin" MKDIR "C:\msys64\mingw64\bin"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Core.dll" "C:\msys64\mingw64\bin\Qt5Core.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Gui.dll" "C:\msys64\mingw64\bin\Qt5Gui.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Widgets.dll" "C:\msys64\mingw64\bin\Qt5Widgets.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Multimedia.dll" "C:\msys64\mingw64\bin\Qt5Multimedia.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5MultimediaWidgets.dll" "C:\msys64\mingw64\bin\Qt5MultimediaWidgets.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Network.dll" "C:\msys64\mingw64\bin\Qt5Network.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5OpenGL.dll" "C:\msys64\mingw64\bin\Qt5OpenGL.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Positioning.dll" "C:\msys64\mingw64\bin\Qt5Positioning.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5PrintSupport.dll" "C:\msys64\mingw64\bin\Qt5PrintSupport.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Qml.dll" "C:\msys64\mingw64\bin\Qt5Qml.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Quick.dll" "C:\msys64\mingw64\bin\Qt5Quick.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5QuickWidgets.dll" "C:\msys64\mingw64\bin\Qt5QuickWidgets.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Sensors.dll" "C:\msys64\mingw64\bin\Qt5Sensors.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Svg.dll" "C:\msys64\mingw64\bin\Qt5Svg.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5WebChannel.dll" "C:\msys64\mingw64\bin\Qt5WebChannel.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5WebSockets.dll" "C:\msys64\mingw64\bin\Qt5WebSockets.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5WebKit.dll" "C:\msys64\mingw64\bin\Qt5WebKit.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5WebKitWidgets.dll" "C:\msys64\mingw64\bin\Qt5WebKitWidgets.dll"
REM
REM All dlls that Qt uses, but compiler dependencies
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libicuin64.dll" "C:\msys64\mingw64\bin\libicuin64.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libicuuc64.dll" "C:\msys64\mingw64\bin\libicuuc64.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libicudt64.dll" "C:\msys64\mingw64\bin\libicudt64.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libpcre2-16-0.dll" "C:\msys64\mingw64\bin\libpcre2-16-0.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\zlib1.dll" "C:\msys64\mingw64\bin\zlib1.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libharfbuzz-0.dll" "C:\msys64\mingw64\bin\libharfbuzz-0.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libfreetype-6.dll" "C:\msys64\mingw64\bin\libfreetype-6.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libbz2-1.dll" "C:\msys64\mingw64\bin\libbz2-1.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libpng16-16.dll" "C:\msys64\mingw64\bin\libpng16-16.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libglib-2.0-0.dll" "C:\msys64\mingw64\bin\libglib-2.0-0.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libintl-8.dll" "C:\msys64\mingw64\bin\libintl-8.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libiconv-2.dll" "C:\msys64\mingw64\bin\libiconv-2.dll"
REM MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libpcre-1.dll" "C:\msys64\mingw64\bin\libpcre-1.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libgraphite2.dll" "C:\msys64\mingw64\bin\libgraphite2.dll"
REM
REM Few unique dependencies for QtWebKit, about the Qt own, as Qt5Multimedia etc., see above
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libjpeg-8.dll" "C:\msys64\mingw64\bin\libjpeg-8.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libsqlite3-0.dll" "C:\msys64\mingw64\bin\libsqlite3-0.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libwebp-7.dll" "C:\msys64\mingw64\bin\libwebp-7.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libxml2-2.dll" "C:\msys64\mingw64\bin\libxml2-2.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\liblzma-5.dll" "C:\msys64\mingw64\bin\liblzma-5.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libxslt-1.dll" "C:\msys64\mingw64\bin\libxslt-1.dll"
REM
REM Copy exe files, that cmake looks for when building Qt
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\qmake.exe" "C:\msys64\mingw64\bin\qmake.exe"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\moc.exe" "C:\msys64\mingw64\bin\moc.exe"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\rcc.exe" "C:\msys64\mingw64\bin\rcc.exe"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\uic.exe" "C:\msys64\mingw64\bin\uic.exe"
REM
IF NOT EXIST "C:\msys64\mingw64\include" MKDIR "C:\msys64\mingw64\include"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtCore" "C:\msys64\mingw64\include\QtCore"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtGui" "C:\msys64\mingw64\include\QtGui"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWidgets" "C:\msys64\mingw64\include\QtWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtMultimedia" "C:\msys64\mingw64\include\QtMultimedia"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtMultimediaWidgets" "C:\msys64\mingw64\include\QtMultimediaWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtNetwork" "C:\msys64\mingw64\include\QtNetwork"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtOpenGL" "C:\msys64\mingw64\include\QtOpenGL"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtPositioning" "C:\msys64\mingw64\include\QtPositioning"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtPrintSupport" "C:\msys64\mingw64\include\QtPrintSupport"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtQml" "C:\msys64\mingw64\include\QtQml"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtQuick" "C:\msys64\mingw64\include\QtQuick"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtQuickWidgets" "C:\msys64\mingw64\include\QtQuickWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtSensors" "C:\msys64\mingw64\include\QtSensors"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtSvg" "C:\msys64\mingw64\include\QtSvg"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWebChannel" "C:\msys64\mingw64\include\QtWebChannel"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWebSockets" "C:\msys64\mingw64\include\QtWebSockets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWebKit" "C:\msys64\mingw64\include\QtWebKit"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWebKitWidgets" "C:\msys64\mingw64\include\QtWebKitWidgets"
REM
REM Probably it is instalation dependent files, maybe will be modified later
IF NOT EXIST "C:\msys64\mingw64\lib\cmake" MKDIR "C:\msys64\mingw64\lib\cmake"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5" "C:\msys64\mingw64\lib\cmake\Qt5"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Core" "C:\msys64\mingw64\lib\cmake\Qt5Core"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Gui" "C:\msys64\mingw64\lib\cmake\Qt5Gui"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Widgets" "C:\msys64\mingw64\lib\cmake\Qt5Widgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Multimedia" "C:\msys64\mingw64\lib\cmake\Qt5Multimedia"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5MultimediaWidgets" "C:\msys64\mingw64\lib\cmake\Qt5MultimediaWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Network" "C:\msys64\mingw64\lib\cmake\Qt5Network"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5OpenGL" "C:\msys64\mingw64\lib\cmake\Qt5OpenGL"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Positioning" "C:\msys64\mingw64\lib\cmake\Qt5Positioning"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5PrintSupport" "C:\msys64\mingw64\lib\cmake\Qt5PrintSupport"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Qml" "C:\msys64\mingw64\lib\cmake\Qt5Qml"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Quick" "C:\msys64\mingw64\lib\cmake\Qt5Quick"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5QuickWidgets" "C:\msys64\mingw64\lib\cmake\Qt5QuickWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Sensors" "C:\msys64\mingw64\lib\cmake\Qt5Sensors"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Svg" "C:\msys64\mingw64\lib\cmake\Qt5Svg"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5WebChannel" "C:\msys64\mingw64\lib\cmake\Qt5WebChannel"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5WebSockets" "C:\msys64\mingw64\lib\cmake\Qt5WebSockets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5WebKit" "C:\msys64\mingw64\lib\cmake\Qt5WebKit"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5WebKitWidgets" "C:\msys64\mingw64\lib\cmake\Qt5WebKitWidgets"
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Core.dll.a" "C:\msys64\mingw64\lib\libQt5Core.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Gui.dll.a" "C:\msys64\mingw64\lib\libQt5Gui.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Widgets.dll.a" "C:\msys64\mingw64\lib\libQt5Widgets.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Multimedia.dll.a" "C:\msys64\mingw64\lib\libQt5Multimedia.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5MultimediaWidgets.dll.a" "C:\msys64\mingw64\lib\libQt5MultimediaWidgets.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Network.dll.a" "C:\msys64\mingw64\lib\libQt5Network.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5OpenGL.dll.a" "C:\msys64\mingw64\lib\libQt5OpenGL.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Positioning.dll.a" "C:\msys64\mingw64\lib\libQt5Positioning.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5PrintSupport.dll.a" "C:\msys64\mingw64\lib\libQt5PrintSupport.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Qml.dll.a" "C:\msys64\mingw64\lib\libQt5Qml.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Quick.dll.a" "C:\msys64\mingw64\lib\libQt5Quick.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5QuickWidgets.dll.a" "C:\msys64\mingw64\lib\libQt5QuickWidgets.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Sensors.dll.a" "C:\msys64\mingw64\lib\libQt5Sensors.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Svg.dll.a" "C:\msys64\mingw64\lib\libQt5Svg.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5WebChannel.dll.a" "C:\msys64\mingw64\lib\libQt5WebChannel.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5WebSockets.dll.a" "C:\msys64\mingw64\lib\libQt5WebSockets.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5WebKit.dll.a" "C:\msys64\mingw64\lib\libQt5WebKit.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5WebKitWidgets.dll.a" "C:\msys64\mingw64\lib\libQt5WebKitWidgets.dll.a"
REM
IF NOT EXIST "C:\msys64\mingw64\share\qt5" MKDIR "C:\msys64\mingw64\share\qt5"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\mkspecs" "C:\msys64\mingw64\share\qt5\mkspecs"
REM
REM All dlls from Qt plugins, qsvg.dll draws images on tool buttons if any, other can be skipped
IF NOT EXIST "C:\msys64\mingw64\share\qt5\plugins\imageformats" MKDIR "C:\msys64\mingw64\share\qt5\plugins\imageformats"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qgif.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qgif.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qicns.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qicns.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qico.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qico.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qjp2.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qjp2.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qjpeg.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qjpeg.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qmng.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qmng.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qsvg.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qsvg.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qtga.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qtga.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qtiff.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qtiff.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qwbmp.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qwbmp.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qwebp.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qwebp.dll"
REM
IF NOT EXIST "C:\msys64\mingw64\share\qt5\plugins\platforms" MKDIR "C:\msys64\mingw64\share\qt5\plugins\platforms"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\platforms\qwindows.dll" "C:\msys64\mingw64\share\qt5\plugins\platforms\qwindows.dll"
REM
IF NOT EXIST "%OPENSHOT_DEPS_DIR%" MKDIR "%OPENSHOT_DEPS_DIR%"
REM Remove existing FFmpeg deps folder (Force FFmpeg update)
IF EXIST "%OPENSHOT_DEPS_DIR%\ffmpeg" RMDIR "%OPENSHOT_DEPS_DIR%\ffmpeg" /s /q
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\ffmpeg" MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg" "%OPENSHOT_DEPS_DIR%"
REM Add ffmpeg folders to PATH
SET FFMPEGDIR=%OPENSHOT_DEPS_DIR%\ffmpeg
REM
REM Zmq dependency dlls, the compiler dependencies are in Qt\bin folder
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\bin\libzmq.dll" "C:\msys64\mingw64\bin\libzmq.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\bin\libsodium-23.dll" "C:\msys64\mingw64\bin\libsodium-23.dll"
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\lib\libzmq.dll.a" "C:\msys64\mingw64\lib\libzmq.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\lib\libsodium.dll.a" "C:\msys64\mingw64\lib\libsodium.dll.a"
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\zmq.h" "C:\msys64\mingw64\include\zmq.h"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\zmq.hpp" "C:\msys64\mingw64\include\zmq.hpp"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\zmq_utils.h" "C:\msys64\mingw64\include\zmq_utils.h"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\sodium.h" "C:\msys64\mingw64\include\sodium.h"
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\sodium" "C:\msys64\mingw64\include\sodium"
REM
REM Resolve UnitTest++ Dependency, libopenshot
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\UTpp" MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\UTpp" "%OPENSHOT_DEPS_DIR%"
REM Set environment variable
SET UNITTEST_DIR=%OPENSHOT_DEPS_DIR%\UTpp
REM
REM Resolve SWIG dependency, used to create import file of libopenshot into Python, these libs would be freezed
REM so use any allowed here.
bash -lc "pacman -S --needed --noconfirm mingw64/mingw-w64-x86_64-swig"
REM Here all dependencies are ready

:instLibOpenShot

REM unmute output
@ECHO on
