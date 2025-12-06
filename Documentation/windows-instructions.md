# Windows Instructions

Prerequisites: [Swift (WinGet Installation)](https://www.swift.org/install/windows), [VS Code](https://code.visualstudio.com/download), [Swift Extension](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html)

Minimum OS version: Windows 10

Minimum GPU architecture: [Maxwell 2.0 (NVIDIA)](https://en.wikipedia.org/wiki/Maxwell_(microarchitecture)), [RDNA 1.0 (AMD)](https://en.wikipedia.org/wiki/RDNA_(microarchitecture))

> Recent commits added support for 64-bit wavefronts. GCN 5.0 and older AMD architectures may be supported now. Please try Molecular Renderer if you have GCN. Open an issue if there are errors.

## Setting Up IDE

Open Git Bash in a location convenient for accessing in File Explorer. Run the following commands:

```
git clone https://github.com/philipturner/molecular-renderer
cd molecular-renderer
./install-libraries.bat
```

Follow the program startup instructions. Confirm that the template in `main.swift` prints "Hello, world." to the VS Code terminal.

## Program Startup

Open the source code in VS Code by double-clicking `Package.swift`. Navigate to the file tree and open the package's parent directory (<b>EXPLORER</b> > <b>Open Folder</b> > <b>Select Folder</b>).

Go to <b>Terminal</b> > <b>New Terminal</b> in the top menu bar, then <b>TERMINAL</b> in the sub-window that appears at the bottom of the IDE. Run `./run.bat` in the interactive terminal. Run on every program startup.

## Issues

Ensure developer mode is turned on in the Windows settings. Also, check the SDKs installed in <b>Control Panel</b> > <b>Programs</b> > <b>Programs and Features</b>. Ensure there is only a single SDK, named "22621".

On the first ever program startup, compilation may take over a minute on older CPUs. To be precise, one compilation instance measured 180.44 seconds on the Intel Core i5-4460, compared to 11.63 seconds on the M1 Max CPU. `-Xswiftc -Ounchecked` allows these build products to be reused on subsequent program runs.

During some program startups, the renderer window is hidden behind the VS Code window. Check for something new appearing in the task bar at the bottom of your screen. Click that icon to bring the renderer into focus.
