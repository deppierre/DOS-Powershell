@echo off
cls
title Installation de Winstore
color 0A
cd\
cls
echo.
echo

set Source=C:\scriptrg

cls
echo.
echo        ######################################################
echo        #                                                    #
echo        #        Section Install Winstore Rouge Gorge        #
echo        #                                                    #
echo        ######################################################
cls
type %Source%\path.txt
echo.
echo.

rem L'utilisateur choisit sa typologie
set /p CHOICE=Selectionner la version client � descendre :
for /f "tokens=1,2,3,4 delims=," %%i in (%Source%\path.txt) do if %CHOICE%==%%i set Enseigne=%%j&&set MS=%%k&&set PathPatch=%%l

rem On teste la presence (ou pas) de la derniere version installee
IF EXIST C:\Partage\ goto BEGIN
goto SKIPBEGIN

rem Si c'est le cas : recuperation de la typologie installee
:BEGIN
@for /f "tokens=1 delims=" %%i in (%Source%\lastinstall.txt) do set lastinstall=%%i
echo Winstore %Enseigne% va etre descendu.
echo.
taskkill /F /IM bddcom.exe

rem Sauvegarde des donnees 
move /y c:\Partage\data\Winstore.ldf %Source%\%lastinstall%\Winstore.ldf
move /y c:\Partage\data\Winstore.mdf %Source%\%lastinstall%\Winstore.mdf

rem Suppression de l'ancienne version
rd c:\Partage /S /Q
rd c:\winstore /S /Q

:SKIPBEGIN
net stop mssqlserver

rem Decompression de la nouvelle version
%Source%\unrar x -y %Source%\%MS%\winstore.rar c:\ 
%Source%\unrar x -y %Source%\%MS%\Partage.rar c:\

rem Parametrage de la nouvelle config et rapatriement des anciennes donnees
copy /y C:\sqlcnx.ini c:\winstore\ini\sqlcnx.ini
copy /y C:\sqlexplorer.ini c:\winstore\ini\sqlexplorer.ini
copy /y C:\sqlcnx.ini c:\Partage\ini\sqlcnx.ini
copy /y %Source%\%PathPatch%\Winstore.mdf c:\Partage\data\Winstore.mdf
copy /y %Source%\%PathPatch%\Winstore.ldf c:\Partage\data\Winstore.ldf

rem On attache les nouvelles donnees
osql -E -i %Source%\detach_base_winstore.sql
osql -E -i %Source%\Attache_base_winstore_axeC.sql
net share Partage=c:\Partage

rem Mise a jour de Winstore en fonction de la typologie choisie
copy /y %Source%\%PathPatch%\Winstore.zip c:\Winstore\Arrivee\Winstore.zip
net start mssqlserver
start c:\Winstore\Majver.exe
ping 0.0.0.0 -n 10 > NUL

rem Suite des modifications
echo sqlamdin >>c:\winstore\sqladmin.tem
echo nofisc >>c:\winstore\nofisc.tem
echo previsu >>c:\winstore\previsu.tem
echo centsql >>c:\winstore\centsql.tem

rem Mise a jour de la derniere version installee
echo %PathPatch%>%Source%\lastinstall.txt

cls
echo.
echo.
set /p CHOICE=Lancement Bddcom (o/n) ? 
if '%CHOICE%'=='o' goto LanceBddcom
goto FinInstallWinstore

:LanceBddcom
if exist c:\Partage\bddcom.exe start c:\Partage\bddcom.exe

:FinInstallWinstore
cls
echo.
echo L'installation de la typologie %PathPatch% est terminee
pause
exit