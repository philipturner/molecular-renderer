# Windows Instructions

Prerequisites: [Swift (Manual Installation)](https://www.swift.org/install/windows/#alternative-install-options), [VS Code](https://code.visualstudio.com/download), [Swift Extension](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html), [Git Bash](https://gitforwindows.org)

Minimum OS version: Windows 10

Minimum GPU architecture: [Maxwell 2.0 (NVIDIA)](https://en.wikipedia.org/wiki/Maxwell_(microarchitecture)), [RDNA 1.0 (AMD)](https://en.wikipedia.org/wiki/RDNA_(microarchitecture))

## Downloading Binaries

Run `./install-libraries.bat` in Git Bash, at the repo directory.

## Program Startup

Open the source code in VS Code by double-clicking `Package.swift`. Navigate to the file tree and open the package's parent directory (<b>EXPLORER</b> > <b>Open Folder</b> > <b>Select Folder</b>).

Go to <b>Terminal</b> > <b>New Terminal</b> in the top menu bar, then <b>TERMINAL</b> in the sub-window that appears at the bottom of the IDE. Run `./run.bat` in the interactive terminal. Run on every program startup.

On the first ever program startup, it is normal for the compilation to take over a minute on older hardware. `-Xswiftc -Ounchecked` allows these build products to be reused on subsequent program runs.

During some program startups, the renderer window is hidden behind the VS Code window. Check for something new appearing in the task bar at the bottom of your screen. Click that icon to bring the renderer into focus.
