
![image](https://github.com/philipturner/molecular-renderer/assets/71743241/d5585c84-7e4e-4507-841a-452fb68615d3)

# Molecular Renderer

Molecular Renderer is a minimal renderer for molecular nanotechnology. It does not have UI features like buttons and dropdowns; instead, the user codes the structures and trajectories to render. This design provides more flexibility and reduces the technical requirements to maintain the renderer. It enabled the development of several related projects.

Projects:
- [Hardware Catalog](./Sources/HardwareCatalog/README.md) - catalog of code samples and archived experiments (25,000 LoC)
- [HDL](https://github.com/philipturner/HDL) - domain-specific language and geometry compiler (8,000 LoC)
- [MM4](https://github.com/philipturner/MM4) - molecular mechanics simulator (13,000 LoC)
- [Molecular Renderer](./Sources/MolecularRenderer/README.md) - programmable renderer with real-time ray tracing (3,000 LoC)
- [Rod Logic](https://github.com/philipturner/rod-logic) - compact, efficient, and manufacturable computing

## Overview

Until 2024, NanoEngineer was the most capable platform for designing molecular nanotechnology. It had an interactive UI, but also simulators that ran slowly at >5000 atoms. This restricted the design to colorful strained shell structures [in order to minimize atom count](http://www.imm.org/research/parts/controller). Several projects sought to improve on this aspect&mdash;the difficulty performing iterative design on nanomachines.

The most well-funded projects (Atomic Machines, CBN Nano Technologies) are closed-source. As a result, aspiring engineers had to rely on the 15-year old NanoEngineer. The successor needed to follow a more modern [approach](https://github.com/atomCAD/atomCAD/wiki) than close-sourcing:

> ...for a molecular nanotechnology industry to exist, there must be such a society of engineers that transcends any single company, and a public body of knowledge capturing best practices for nano-mechanical engineering design. Other companies are training engineers on in-house tools where they create designs never to be seen by the outside world. We believe strongly that needs to change...

Out of all the [ongoing efforts](https://astera.org/molecular-systems) to succeed NanoEngineer, Molecular Renderer was the first to reach [million-atom scale](https://www.youtube.com/watch?v=AC34BQt2ODM). It was built from the ground up to enable engineering of massive systems. The scale of general-purpose computers, replicating machines, and medical nanobots.

## Installation

There are only two simulator dependencies. Everything else is implemented from scratch in Swift.

| Library | Type | Mac | Linux | Windows |
| :-----: | :--: | :-: | :---: | :-----: |
| OpenMM  | Molecular Mechanics | [Conda](https://anaconda.org/conda-forge/openmm) | [Conda](https://anaconda.org/conda-forge/openmm) | [Conda](https://anaconda.org/conda-forge/openmm) |
| xTB     | Quantum Mechanics   | [Homebrew](https://github.com/grimme-lab/homebrew-qc) | [GitHub Releases](https://github.com/grimme-lab/xtb/releases) | [GitHub Releases](https://github.com/grimme-lab/xtb/releases) |

There are also platform-specific dependencies:

Dependencies (Mac)
- macOS 14
- Xcode
- [Metal Plugin](https://github.com/philipturner/openmm-metal) for OpenMM
- xTB dynamic library with [OpenBLAS replaced by Accelerate](https://github.com/philipturner/swift-xtb)

Dependencies (Linux)
- Ubuntu 18&ndash;22
- Visual Studio Code
- [Swift Extension](https://www.swift.org/blog/vscode-extension) for Visual Studio Code

Dependencies (Windows)
- Windows 10&ndash;11
- Visual Studio Code
- [Swift Extension](https://www.swift.org/blog/vscode-extension) for Visual Studio Code

The renderer itself <b>does not run on Linux or Windows</b>. Support for Windows is being planned, through Microsoft Direct3D and AMD FidelityFX.

## Documentation

TODO: Document the controls.

Known issues:
- The UI often freezes unpredictably. You then have to wait ~10 seconds for it to become responsive again. The freeze is very difficult to reproduce.
- There is a graphical glitch with high-quality screenshots, when objects are very far away.
- MetalFX upscaling quality degrades when motion vectors are incorrect. Need better documentation of when this might happen.

> Build failed because HDL.swiftmodule is not built for arm64e. Please try a run destination with a different architecture.

This error occurs often when downloading the renderer from the internet. Click <b>Change run destination</b> to switch from <b>My Mac (arm64e)</b> to <b>My Mac (arm64)</b>.
