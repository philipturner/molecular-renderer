# Windows Instructions

Prerequisites: [Swift (Manual Installation)](https://www.swift.org/install/windows/#alternative-install-options), [VS Code](https://code.visualstudio.com/download), [Swift Extension](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html), [Git Bash](https://gitforwindows.org)

Minimum OS version: Windows 10

## Downloading Binaries

Run `./install-libraries.bat` in Git Bash, at the repo directory.

Go to the [Google Drive](https://drive.google.com/drive/folders/1zLNHuiN0CINJoaOwDX03eWMMOwJ3ljzW?usp=drive_link) folder in your browser. Download `openmm-windows.zip` and `xtb-windows.zip`. Move these ZIP files into the repo directory. Be careful to not drag and drop them directly over a script file, as that will trigger a command prompt window that executes the script.

Run `./install-openmm.bat` in Git Bash, at the repo directory.

Run `./install-xtb.bat` in Git Bash, at the repo directory.

If you have trouble installing the simulators, comment out the following lines of `Package.swift`:

```swift
workspaceDependencies += [
  .product(name: "MM4", package: "MM4"),
  .product(name: "OpenMM", package: "swift-openmm"),
]
workspaceLinkerSettings += [
  .linkedLibrary("OpenMM"),
]
```

## Program Startup

Open the source code in VS Code by double-clicking `Package.swift`. Navigate to the file tree and open the package's parent directory (<b>EXPLORER</b> > <b>Open Folder</b> > <b>Select Folder</b>).

Go to <b>Terminal</b> > <b>New Terminal</b> in the top menu bar, then <b>TERMINAL</b> in the sub-window that appears at the bottom of the IDE. Run `./run.bat` in the interactive terminal. Run on every program startup.

On the first ever program startup, it is normal for the compilation to take over a minute on older hardware. `-Xswiftc -Ounchecked` allows these build products to be reused on subsequent program runs.

The first time the code compiles and executes, the renderer window may be hidden behind the VS Code window. Check for something new appearing in the task bar at the bottom of your screen.
