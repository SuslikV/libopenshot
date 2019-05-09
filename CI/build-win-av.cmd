REM Build script for appveyor (Windows)

REM echo status
ECHO
REM Some space
ECHO:

REM Make new building dir
MKDIR %APPVEYOR_BUILD_FOLDER%\build
CD %APPVEYOR_BUILD_FOLDER%\build

cmake --version
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DPYTHON_EXECUTABLE="C:/Python36-x64/python.exe" -DPYTHON_INCLUDE_DIR="C:/Python36-x64/include/" -DPYTHON_LIBRARY="C:/Python36-x64/libs/libpython36.a" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=10 ..
mingw32-make --version
mingw32-make VERBOSE=1
REM Look for shared lib
DIR /s libopenshot.dll
mingw32-make install
