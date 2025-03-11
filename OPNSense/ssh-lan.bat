@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0ssh-opnsense.ps1" -Target lan
