REM Build script for appveyor (Windows)

REM echo status
echo
REM Some space
echo:

REM Let us see what we have as environment here
echo %PATH%
echo:
cd 

REM cmake will unable to compile without "MinGW\bin" path to PATH
REM set PATH=C:\MinGW\bin;%PATH%
REM set PATH=C:\mingw-w64\x86_64-8.1.0-posix-seh-rt_v6-rev0\bin;%PATH%
REM echo:
REM echo PATH environment variable was updated.
REM echo %PATH%
REM echo:

REM Make new building dir
mkdir %APPVEYOR_BUILD_FOLDER%\build
cd %APPVEYOR_BUILD_FOLDER%\build

cmake --version
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DPYTHON_EXECUTABLE="C:/Python36-x64/python.exe" -DPYTHON_INCLUDE_DIR="C:/Python36-x64/include/" -DPYTHON_LIBRARY="C:/Python36-x64/libs/libpython36.a" ..
mingw32-make --version
mingw32-make
mingw32-make install
