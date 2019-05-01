REM Packing build into archive

SET OpenShotFilesPath=%ProgramFiles(x86)%
IF NOT DEFINED ProgramFiles(x86) SET OpenShotFilesPath=%ProgramFiles%

echo %OpenShotFilesPath%
REM Went to installation folder
cd "%OpenShotFilesPath%\libopenshot"

dir /s

7z a -t7z libopenshot-win-%PLATFORM%.7z * -xr!.gitignore

dir
