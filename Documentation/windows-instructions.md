# Windows Instructions

Prerequisites: [Swift (Manual Installation)](https://www.swift.org/install/windows/#alternative-install-options), [VS Code](https://code.visualstudio.com/download), [Swift Extension](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html), [Git Bash](https://gitforwindows.org)

Minimum OS version: Windows 10

---

TODO: Separate Google Drive links and install scripts for OpenMM and xTB. ZIP files should be placed in the top-level folder and gracefully handled by the install script, which copies them into `.build`. List the expected binary size of each.

Run `./install-libraries.bat` in Git Bash, at the repo directory. Only run once, the first time the repo is downloaded.

Open the source code in VS Code by double-clicking `Package.swift`. Navigate to the file tree and open the package's parent directory.

Go to <b>Terminal</b> > <b>New Terminal</b> in the top menu bar, then <b>TERMINAL</b> in the sub-window that appears at the bottom of the IDE. Run `./run.bat` in the interactive terminal. Run on every program startup.

> The very first time the code is compiled and executed, the renderer window is hidden by the VS Code window. Check for something new appearing in the task bar at the bottom of your screen.
