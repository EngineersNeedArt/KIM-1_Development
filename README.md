# KIM-1_Development
Getting started with a MacOS KIM-1 6502 development workflow.

I spent an evening with Claude getting a 6502 development environment and workflow set up on MacOS so that I could write/compile 6502 assembly and test it on the PAL-2 (KIM-1 clone). This repository captures that work, makes it easy for someone to also get started easily.

## Instructions

1) Pull down this repository. The directory becomes your working directory where you will create your assembly files and where build results will appear.

2) Install command-line tools `ca65` (assembler), `ld65` (linker) and `srec_cat` (to turn binaries into paper-tape format).

   The following is a **homebrew** (https://brew.sh) command (homebrew is a package installer for MacOS). Running the command will install the three command-line tools.

   `brew install cc65 srecord`

3) Install **Visual Studio Code** (VSCode) (https://code.visualstudio.com/download). This is your IDE—text editor for the assembly programs.

4) Launch **VSCode** and `File`→`Open Folder…` and select the `KIM-1_Development` folder. This becomes your workspace for developing KIM-1 programs.

5) In **VSCode** open the Extensions panel (`View`→`Extensions`, ⇧⌘X) and search “6502”. **6502汇编语法高亮** by **chengbin** is what you want. It will give you *syntax highlighting* in **VS Code**.

6) Switch back to the Explorer view (`View`→`Explorer`, ⇧⌘E) in **VSCode**, select the file `wave.asm`. If it shows `Plain Text` as the language mode (in the lower right corner of the window) and no syntax highlighting, you may have to first *trust* the workspace/directory.

7) With wave.asm selected, build (`Terminal`→`Run Build Task…`, ⇧⌘B).
