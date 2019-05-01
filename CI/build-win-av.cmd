REM Build script for appveyor (Windows)

REM Echo status
ECHO
REM Some space
ECHO:
REM Print commands
ECHO on

REM Python module path of the libopenshot installation
SET P_MODULE_PATH=python

REM Make new building dir
MKDIR %APPVEYOR_BUILD_FOLDER%\build
CD %APPVEYOR_BUILD_FOLDER%\build

cmake --version
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=6.1 -DPYTHON_EXECUTABLE:FILEPATH="%PYTHONHOME%\python.exe" -DPYTHON_INCLUDE_DIR:PATH="%PYTHONHOME%\include" -DPYTHON_LIBRARY:FILEPATH="%PYTHONHOME%\libs\libpython37.a" -DCMAKE_INSTALL_PREFIX:PATH="%OPENSHOT_INST_DIR%" -DPYTHON_MODULE_PATH="%P_MODULE_PATH%" ..
mingw32-make --version
mingw32-make VERBOSE=1
mingw32-make install
