::	Ionity Bench
::	URLs: https://www.ionity.today | https://github.com/Ionity-Global/ionity-bench
::	Copyright (C) 2018 - 2026, Antwerp Designs | Ionity (Pty) Ltd - AEDI
::	ionity-bench.bat: Windows launcher for Ionity Bench, built on the Phoronix Test Suite engine
::	(Phoronix Test Suite: Copyright (C) 2008 - 2026, Phoronix Media / Michael Larabel)
::
::	This program is free software; you can redistribute it and/or modify
::	it under the terms of the GNU General Public License as published by
::	the Free Software Foundation; either version 3 of the License, or
::	(at your option) any later version.
::
::	This program is distributed in the hope that it will be useful,
::	but WITHOUT ANY WARRANTY; without even the implied warranty of
::	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
::	GNU General Public License for more details.
::
::	You should have received a copy of the GNU General Public License
::	along with this program. If not, see <http://www.gnu.org/licenses/>.
::
::	Governance: Policy 986 AED. Brand marks are not covered by the GPL - see NOTICE-IONITY.md.

@echo off
set IONITY_BENCH=1
set IONITY_BENCH_LAUNCHER=%0

if "%~1"=="" goto Help
if /I "%~1"=="help" goto Help
if /I "%~1"=="--help" goto Help

set FIRST=%~1
if /I "%FIRST%"=="edge-node" goto Suite
if /I "%FIRST%"=="iot-gateway" goto Suite
if /I "%FIRST%"=="ai-edge" goto Suite
if /I "%FIRST%"=="storage" goto Suite
if /I "%FIRST%"=="timeseries-db" goto Suite
if /I "%FIRST%"=="server-rms" goto Suite
if /I "%FIRST%"=="workstation-design" goto Suite
if /I "%FIRST%"=="quick-check" goto Suite
if /I "%FIRST%"=="full-spectrum" goto Suite
if /I "%FIRST%"=="power-thermal" goto Suite
if /I "%FIRST:~0,3%"=="io-" goto Suite

call "%~dp0phoronix-test-suite.bat" %*
goto :EOF

:Suite
shift
set REST=
:Loop
if "%~1"=="" goto RunSuite
set REST=%REST% %1
shift
goto Loop
:RunSuite
call "%~dp0phoronix-test-suite.bat" benchmark ionity/%FIRST%%REST%
goto :EOF

:Help
call "%~dp0phoronix-test-suite.bat" ionity
