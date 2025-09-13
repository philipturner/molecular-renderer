![Banner](./Documentation/Banner.png)

# Molecular Renderer

Molecular Renderer employs a GUI-free, IDE-like workflow. You download the Swift package, open the source code in an IDE, and edit Swift files in the `Workspace` directory. These files compile on every program startup.

You open a renderer window through an API. You can also perform other operations, like running simulations, accessing files on disk, and saving rendered frames into a video file. You incorporate external Swift modules through `Package.swift`. `run.sh` can be edited to link external C libraries and set environment variables.

## Usage

> TODO: Document the prerequisite of installing Swift, Xcode, VS Code, Git Bash.

Open a terminal in a location convenient for accessing in the File Explorer. Download the source code:

```
git clone --single-branch --branch windows-port https://github.com/philipturner/molecular-renderer
```

### macOS Instructions

Open the source code in Xcode by double-clicking `Package.swift`. Do not run the code from within the Xcode UI.

Instead, open a Terminal window at the package directory. Run `bash run.sh` on every program startup.

### Windows Instructions

Run `./install-libraries.bat` in Git Bash, at the repo directory. Only run once, the first time the repo is downloaded.

Open the source code in VS Code by double-clicking `Package.swift`. Navigate to the file tree and open the package's parent directory.

Go to <b>Terminal</b> > <b>New Terminal</b> in the top menu bar, then <b>TERMINAL</b> in the sub-window that appears at the bottom of the IDE. Run `./run.bat` in the interactive terminal. Run on every program startup.

### Renderer Window

With the renderer API (NOT YET CREATED), a window of your chosen resolution appears at program startup. You specify the monitor on which it appears, TAAU upscale factor (2 or 3), and resolution after upscaling.

To close the window, click the "X" button at the top. You can also use `Cmd + W` (macOS) or `Ctrl + W` (Windows).

The window does not register keyboard/mouse events or forward them to the program. This may change in the distant future, to allow interactive WASD-type navigation of a scene.

### Ambient Occlusion Sample Count

The most computationally intensive part of rendering is estimating the degree of self-shadowing, or how "occluded" / crowded a location is. A place wedged between two atoms should appear darker than an obstructed surface exposed directly to open space. In practice, this is achieved by randomly choosing a set of ray directions, then following the rays until they hit a nearby surface.

A default of 7 secondary rays results in sufficient quality for any general use case. However, in cases prone to high divergence (non-uniform control flow, disorder or random memory access patterns), GPU performance may degrade so much that the FPS target cannot be reached. In the old renderer, divergence happened more often in regions far away from the camera. At large distances, each atom appears smaller, which (long story short) means higher divergence. There was a highly tuned heuristic that reduced the sample count to 3, at a certain distance from the user. This particular case could afford lower rendering quality anyway.

To simplify the implementation, the new renderer does not yet support perspective projections. There is no singular point where all primary rays originate. There is no concept of FOV in degrees. As a result, atoms far from the camera plane appear the same size (in pixels) as very close atoms. The divergence disappears, and all atoms need 7 samples for acceptable rendering quality.

In some cases, the user may wish to render a very wide area, where each atom covers a smaller number of pixels than usual. This situation could be similar to the old renderer, when rendering atoms very far away. In such a case, the user should search for the relevant shader code in the source tree. Change the sample count from 7 to 3 (or even a number in between, if they have the patience to inspect the rendering quality and tune this parameter).
