# Serialization

The code in this archive is about serializing molecular dynamics trajectories to the disk. The pipeline went from an Apple-specific binary MRSimulation codec, to generating a pre-scripted camera trajectory, to exporting a massive GIF. The GIF was at 50 FPS, the largest framerate supported by the codec. It could be converted to 60 FPS in Shotcut.

The code was archived because the APIs grew very unwieldy. The code was outdated, often project-specific, and needs to be redone in a fresh way. There is a new MRSimulation text codec. In addition, a version 2 of the binary codec can be created. It would be cross-platform from the start, using vectorized CPU code instead of GPU code. This design approach will make it easier to port to non-Apple platforms. It was also questionable whether GPU was needed in the first place, other than Metal being easier than vectorized Swift code at the time.

The following dependency will still be important in future efforts. It is clear that GIF images are the only viable way to export time-series data from the app. Screen recording software was attempted many times and all solution were broken. There is no known API that writes directly to MP4 files from Swift; it would be insightful to discover such an API.

https://github.com/philipturner/swift-gif

> A fork of the `swift-gif` repository that uses multiple CPU cores. GIF encoding is extremely computationally intensive, often taking just as long as rendering images of the same resolution on GPU.
>
> This dependency introduced a lot of secondary dependencies, which are not even related to the project. This includes libfreetype, libpng, SwiftSoup, and XMLCoder. Removing the GIF serializer from the project erased these dependencies.
