# KIM-1 Development on MacOS
Getting started with a MacOS **KIM-1** 6502 development environment.

I spent an evening with Claude getting a 6502 development environment and workflow set up on MacOS so that I could write/compile 6502 assembly and test it on the **PAL-2** (**KIM-1** clone). This repository captures that work, makes it easy for someone to also get started easily.

## Instructions

1) Pull down this repository. The directory becomes your working directory where you will create your assembly files and where build results will appear. (Assembly files have `.s` for an extension.)

2) Install command-line tools `ca65` (assembler), `ld65` (linker) and `srec_cat` (to turn binaries into paper-tape format).

   The following is a **homebrew** (https://brew.sh) command (homebrew is a package installer for MacOS). Running the command will install the three command-line tools.

   `brew install cc65 srecord`

3) Install **Visual Studio Code** (VSCode) (https://code.visualstudio.com/download). This is your IDE—text editor for the assembly programs. It also allows for “tasks” that you can define to enable kicking off the build tools to compile/link…

4) Launch **VSCode** and `File`→`Open Folder…` and select the `KIM-1_Development` folder. This becomes your workspace for developing **KIM-1** programs.

5) In **VSCode** open the Extensions panel (`View`→`Extensions`, ⇧⌘X) and search “6502”. **6502汇编语法高亮** by **chengbin** is what you want. It will give you *syntax highlighting* in **VS Code**.

6) Switch back to the Explorer view (`View`→`Explorer`, ⇧⌘E) in **VSCode**, select the file `blinken.s`. If it shows `Plain Text` as the language mode (in the lower right corner of the window) and no syntax highlighting, you may have to first *trust* the workspace/directory.

7) With `blinken.s` selected, build (`Terminal`→`Run Build Task…`, ⇧⌘B).

   What should happen is that a **Terminal** panel should open in the bottom portion of your main window and display several commands executing. `Executing task: mkdir -p build && ca65`… etc.
   
   A new `build` folder should appear in your **Explorer** view. Opening it should reveal `blinken.tape` (other intermediate targets are built but are deleted as part of a clean-up task).

   Selecting `blinken.tape` should show you the paper tape version of the binary you just compiled and linked:

   ```
   ;180200A97F8D4117A93F8D4317A9E18501A9AC8502203702A91E850987
   ;18021800A200A0098C4217BD69028D4017206102E8C8C8E006D0ED0A0C
   ;180230C600D0E54C1202A205204D022907C907B0F7A8B96F029D6909BA
   ;18024802CA10ED60A008460266019006A50249B4850288D0F1A5010992
   ;1602606098A0C888D0FDA8600000000000000102040810204006B4
   ;0000050005
8) Download and install *CoolTerm* (https://coolterm.macupdate.com) for MacOS. Launching the app on MacOS is problematic because of Apple quarantining apps that are not signed by Apple. If you know how to get around this in `System Settings→Privacy & Security`, you may go that route. There is a command-line way to do it as well. In **Terminal** (in MacOS) enter:

   `xattr -d com.apple.quarantine /Applications/CoolTerm.app`

   That should remove the quarantine and allow you to launch **CoolTerm**.

9) Connect to your **PAL-2** (**KIM-1** clone) from **CoolTerm**.

   First though select `Connection→Options…→Serial Port` and find the `usbserial` port under `Port:`. This should be the **PAL-2** you have connected. Select `Baudrate:` of **1200**, `Data Bits:` of **8**, `Parity:` **None** and `Stop Bits:` **1**.

   Second, under the `Transmit` setting, you want to check (turn on) `Use transmit character delay` and `Use transmit line delay`. This slows down the transfer of text to the **PAL-2** so it can keep up.

   Finally, click `OK` in the options panel and connect to the **PAL-2** (`Connection→Connect`, ⌘K). If you hit `ENTER` (`Return` key) **PAL-2** should come back with `KIM` in **CoolTerm**.

10) Copy and paste the paper tape text.

    Back in **VS Code**, select the text from `blinken.tape` and `Edit→Copy` to the clipboard.

    Back in **CoolTerm**, connected to **PAL-2**, enter `L` to indicate you want to **L**oad a paper tape, and then `Edit→Paste` the paper tape text. You should see it slowly being *typed* by **CoolTerm** as it is sent to **PAL-2**. It should take less than a minute.

11) Finally, run the program. In **CoolTerm** type `0200` and then `SPACEBAR` to go to address 0200. Then type `G` to tell **PAL-2** to "GO".

    If everything works, **PAL-2** should start displaying *blinkenlights* across its LED display. (Make sure the `SST` switch is slid to the right!).

**Note: not *every* program starts at address 0200. Check a program's header for info specific to it.**

From this point on your workflow is to launch **VS Code** and open the folder where your code is (step 4, above), launch **CoolTerm** and connect to your **PAL-2** (step 9), and then go back and forth editing assembly, compiling/linking (step 7), copying/pasting the paper tape code to **CoolTerm** (step 10) and running on **Pal-2** (step 11).

Enjoy!
