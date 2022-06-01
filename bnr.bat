@echo off
rm -f run/defend.exe defend.exe
xfbuild defend/Main.d -odefend.exe -v -- %* -debug -g -version=UseSDL -version=Tango winmm.lib tango-user-dmd.lib tango-base-dmd.lib
mv -f defend.exe run
cd run
defend.exe
pause