![Banner](./Documentation/Banner.png)

# Molecular Renderer

Molecular Renderer employs a GUI-free, IDE-like workflow. You download the Swift package, open the source code in an IDE, and edit Swift files in the `Workspace` directory. These files compile on every program startup.

You open the renderer window through an API. You can also perform other operations, like running simulations, accessing files on disk, and saving rendered frames into a video file. You incorporate external Swift modules through `Package.swift`. `run.sh` can be edited to link external C libraries and set environment variables.

## Installation

[macOS Instructions](./Documentation/macos-instructions.md)

[Windows Instructions](./Documentation/windows-instructions.md)

## Usage

[Renderer Window](./Documentation/renderer-window.md)

[Tests](./Documentation/Tests/README.md)

## Documentation

[Render Process](./Documentation/render-process.md)

[BVH Update Process](./Documentation/bvh-update-process.md)
