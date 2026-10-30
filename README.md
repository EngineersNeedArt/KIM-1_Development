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

7) With `wave.asm` selected, build (`Terminal`→`Run Build Task…`, ⇧⌘B).

   What should happen is that a **Terminal** panel should open in the bottom portion of your main window and display several commands executing. `Executing task: mkdir -p build && ca65`… etc.
   
   A new `build` folder should appear in your **Explorer** view. Opening it should reveal `wave.bin`, `wave.lst`, `wave.o`, and `wave.tape`.

   Selecting `wave.tape` should show you the paper tape version of the binary you just compiled and linked:

   ```
   ;180200A97F8D4117A93F8D4317A90A8500A200A0098C4217BD47020864
   ;1802188D4017203F02E8C8C8E007D0EDC600D0E5AC4702A200BD480BAA
   ;180230029D4702E8E006D0F58C4D024C0A0298A0C888D0FDA860080B5D
   ;06024840014008080800E9
   ;0000040004

8) Download and install *CoolTerm* (https://coolterm.macupdate.com) for MacOS. Launching the app on MacOS is problematic because of Apple quarantining apps that are not signed by Apple. If you know how to get around this in `System Settings→Privacy & Security`, you may go that route. There is a command-line way to do it as well. In **Terminal** (in MacOS) enter:

   `xattr -d com.apple.quarantine /Applications/CoolTerm.app`

   That should remove the quarantine and allow you to launch **CoolTerm**.

9) Connect to your PAL-2 (KIM-1 clone) from **CoolTerm**.

   First though select `Connection→Options…→Serial Port` and find the `usbserial` port under `Port:`. This should be the PAL-2 you have connected. Select `Baudrate:` of **1200**, `Data Bits:` of **8**, `Parity:` **None** and `Stop Bits:` **1**.

   Second, under the `Transmit` setting, you want to check (turn on) `Use transmit character delay` and `Use transmit line delay`. This slows down the transfer of text to the PAL-2 so it can keep up.

   Finally, click `OK` in the options panel and connect to the PAL-2 (`Connection→Connect`, ⌘K).

11) Copy and paste the paper tape text.

    Back in VS Code, select the text from wave.tape and `Edit→Copy` to the clipboard.

    Back in **CoolTerm**
