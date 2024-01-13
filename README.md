
![image](https://github.com/philipturner/molecular-renderer/assets/71743241/d5585c84-7e4e-4507-841a-452fb68615d3)

# Molecular Renderer

Molecular Renderer is a CAD program for molecular nanotechnology. It enabled the development of several related projects. Some evolved into distinct libraries, while one contributes to a UI experience based on existing IDEs.

Projects:
- [Hardware Catalog](./Sources/HardwareCatalog/README.md) - catalog of code samples and archived experiments (23,000 LoC)
- [HDL](https://github.com/philipturner/HDL) - domain-specific language and geometry compiler (8,000 LoC)
- [MM4](https://github.com/philipturner/MM4) - molecular mechanics simulator (12,000 LoC)
- [Molecular Renderer](./Sources/MolecularRenderer/README.md) - programmable renderer with real-time ray tracing (3,000 LoC)

## Overview

Until 2024, NanoEngineer was the most capable platform for designing molecular nanotechnology. It had an interactive UI, but also simulators that ran slowly at >5000 atoms. This restricted the design to colorful strained shell structures [in order to minimize atom count](http://www.imm.org/research/parts/controller). Several projects sought to improve on this aspect&mdash;the difficulty performing iterative design on nanomachines.

The most well-funded projects (Atomic Machines, CBN Nano Technologies) are closed-source. As a result, aspiring engineers had to rely on the 15-year old NanoEngineer. The successor needed to follow a more modern [approach](https://github.com/atomCAD/atomCAD/wiki) than close-sourcing:

> ...for a molecular nanotechnology industry to exist, there must be such a society of engineers that transcends any single company, and a public body of knowledge capturing best practices for nano-mechanical engineering design. Other companies are training engineers on in-house tools where they create designs never to be seen by the outside world. We believe strongly that needs to change...

Out of all the [ongoing efforts](https://astera.org/molecular-systems) to succeed NanoEngineer, Molecular Renderer was the first to reach [million-atom scale](https://www.youtube.com/watch?v=AC34BQt2ODM). It was built from the ground up to enable engineering of massive systems. The scale of general-purpose computers, replicating machines, and medical nanobots.

## Installation

Dependencies (Mac)
- macOS 14
- Xcode
- [Metal Plugin](https://github.com/philipturner/openmm-metal) for OpenMM

Dependencies (Linux)
- Ubuntu 18&ndash;22
- Visual Studio Code
- [Swift Extension](https://www.swift.org/blog/vscode-extension) for Visual Studio Code

Dependencies (Windows)
- Windows 10&ndash;11
- Visual Studio Code
- [Swift Extension](https://www.swift.org/blog/vscode-extension) for Visual Studio Code
