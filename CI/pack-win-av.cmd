REM Packing build into archive

SET OpenShotFilesPath=C:\OPS
REM IF NOT DEFINED ProgramFiles(x86) SET OpenShotFilesPath=%ProgramFiles%

ECHO Using source path: %OpenShotFilesPath%\libopenshot
REM Went to installation folder
CD "%OpenShotFilesPath%\libopenshot"

ECHO Creating archive...

7z a -bsp2 -t7z libopenshot-win-%PLATFORM%.7z * -xr!.gitignore

DIR
