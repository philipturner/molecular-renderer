# macOS Instructions

Prerequisites: [Xcode](https://developer.apple.com/xcode)

Minimum OS version: macOS 15

Minimum GPU architecture: [M1 (Apple)](https://en.wikipedia.org/wiki/Apple_silicon)

## Setting Up IDE

Open Terminal in a location convenient for accessing in Finder. Run the following commands:

```
git clone https://github.com/philipturner/molecular-renderer
cd molecular-renderer
bash install-libraries.sh
```

Follow the program startup instructions. Confirm that the template in `main.swift` prints "Hello, world." to Terminal.

## Program Startup

Open the source code in Xcode by double-clicking `Package.swift`. Do not run the code from within the Xcode UI. If you do this, the code will fail to link to OpenMM and/or run very slowly.

Instead, open a Terminal window at the package directory. Run `bash run.sh` on every program startup.
