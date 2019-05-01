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
set PATH=C:\MinGW\bin;%PATH%
echo:
echo PATH environment variable was updated.
echo %PATH%
echo:

REM Make new building dir
mkdir %APPVEYOR_BUILD_FOLDER%\build
cd %APPVEYOR_BUILD_FOLDER%\build

cmake --version
REM cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DUSE_CXX_GNU_EXTENSIONS:BOOL=ON ..
REM mingw32-make --version
REM mingw32-make VERBOSE=1
REM mingw32-make install
