# Hardware Catalog

The hardware catalog contains various images, Markdown files, and snippets of source code. They are organized into a file directory. On GitHub, the Markdown files transform into web pages with images and formatted text. This is the preferred method for reading the hardware catalog.

Table of Contents
- [Materials](./Materials/README.md)
- [Miscellaneous](./Miscellaneous/README.md)
- [Parts](./Parts/README.md)
- [Serialization](./Serialization/README.md)
- [Simulation](./Simulation/README.md)
- [Systems](./Systems/README.md)

## About

This is an archive to organize a large volume of nanomechanical experiments, designs, and demos. It was originally intended to be a software library, where parts could be instantiated from an API with parametric dimensions. It would reduce the amount of human effort to design large systems. Design a part once, catalogue it, and recycle in future projects with no effort.

However, that approach proved inappropriate for a mechanical engineering context. The article below explains how this approach - the VLSI approach of reusing functional blocks - does not work for mechanical engineering. Molecular nanotechnology is partially immune to the claims from the article. Nanofactories are designed to be modular. There's separation of variables and separation of concerns. Housing is extremely stiff, removing the coupling between nearby parts. Subsystems can genuinely be isolated. This does not happen at macroscale where the immense amount of matter required, and tight profit margins, motivate practices that couple numerous parts in non-scalable ways.

https://diyhpl.us/~bryan/papers2/Why%20mechanical%20design%20cannot%20be%20like%20VLSI%20design%20-%20Whitney%20-%201996.pdf

This reference relates to a quote from Nanosystems 14.6.5. It constitutes study of the rise of VLSI, which reached its peak in the 1980's and 1990's. Afterward, the materials science part got increasingly complex. Progress slowed and finally halted because the laws of physics were reached. This is why Moore's Law cannot continue anymore.

> This section has given only a rough sketch of past developments. A more detailed study of the evolution from lower-level CAD systems ot silicon compilers could yield further insights into the likely path from today's molecular modeling and mechanical CAD packages toward future compiler-style support for the engineering of nanomechanical systems.

There is another topic that constitutes "study of...evolution" proposed in the quote. Analyzing the failure of the original design goal for the hardware catalog. It was an idea conceived under extreme time constraints. The author wanted to enjoy nanomechanical design, but faced an immense roadblock: lacking the right software. Recycling previous designs seemed like the easiest approach to overcoming a "person hours bottleneck" in generating molecular structures. That approach clearly failed. Reading the VLSI paper was the nail in the coffin.

Instead, the author carefully gathered spare time across many months. He worked on making software the right way, even if development was time-consuming. It was discovered that simple, well-principled software is the key to scaling. He created a compiler that actualized several design constraints proposed in Nanosystems Chapter 14.6.

For reference, the section headings of that chapter are enumerated:
- <b>14.6.1</b> Part counts and automation in design and computation
- <b>14.6.2</b> Design of components and small systems
- <b>14.6.3</b> Automated generation of synthesis and assembly procedures
- <b>14.6.4</b> Shape description languages and part arrays
- <b>14.6.5</b> Compilers
  - <b>a)</b> Assembly-process compilers
  - <b>b)</b> Design compilers
  - <b>c)</b> The economics of compiler development
- <b>14.6.6</b> Relative complexities

## Usage

When using the Molecular Renderer app, you can add source code files to the Xcode target. Go to the banner on the right (<b>Identity and Type</b>) > <b>Target Membership</b> > <b>MolecularRendererApp</b> > check the box. Not every code sample compiles, but most should with minor modifications.
