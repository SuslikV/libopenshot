REM Packing build into archive

REM If building fails do not pack files
IF NOT EXIST "%OPENSHOT_INST_DIR%" GOTO:EOF

REM Went to installation folder
CD "%OPENSHOT_INST_DIR%"

ECHO Creating archive...

7z a -bsp2 -t7z libopenshot-win-%PLATFORM%.7z * -xr!.gitignore

DIR
