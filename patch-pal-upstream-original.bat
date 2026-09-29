assembler\bass.exe -d MAKE_PAL -o "ssb64asm-pal.z64" main.asm -sym logfile-pal.log
assembler\chksum64.exe "ssb64asm-pal.z64" > nul
assembler\rn64crc.exe -u > nul
@echo %cmdcmdline%|find /i """%~f0""">nul && pause