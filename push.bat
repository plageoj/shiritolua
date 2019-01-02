@ECHO OFF

luvit test/test.lua

IF "%ERRORLEVEL%" == "0" (
    git push origin master
) else (
    ECHO TEST FAILED!
)