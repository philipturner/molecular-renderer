![Banner](./Documentation/Banner.png)

# Molecular Renderer

Molecular Renderer employs a GUI-free, IDE-like workflow. You download the Swift package, open the source code in an IDE, and edit Swift files in the `Workspace` directory. These files compile on every program startup.

You open a renderer window through an API. You can also perform other operations, like running simulations, accessing files on disk, and saving rendered frames into a video file. You incorporate external Swift modules through `Package.swift`. `run.sh` can be edited to link external C libraries and set environment variables.

## Usage

Open a terminal in a location convenient for accessing in the File Explorer. Download the source code:

```
git clone https://github.com/philipturner/molecular-renderer
```

[macOS Instructions](./Documentation/macos-instructions.md)

[Windows Instructions](./Documentation/windows-instructions.md)

[Google Drive](https://drive.google.com/drive/folders/1zLNHuiN0CINJoaOwDX03eWMMOwJ3ljzW?usp=drive_link) folder for simulator binaries

## Documentation

[User Interface](./Documentation/user-interface.md)

[Tests](./Documentation/tests.md)

[Other Documentation](./Documentation/other-documentation.md)

[BVH Update Process](./Documentation/bvh-update-process.md)
