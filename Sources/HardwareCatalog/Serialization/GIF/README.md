# GIF

This dependency will still be important in future efforts. It is clear that GIF images are the only viable way to export time-series data from the app. Screen recording software was attempted many times and all solutions were broken. There is no known API that writes directly to MP4 videos from Swift; it would be insightful to discover such an API.

https://github.com/philipturner/swift-gif

A fork of the `swift-gif` repository that uses multiple CPU cores. GIF encoding is extremely computationally intensive, often taking just as long as rendering images of the same resolution on GPU.

This dependency introduced a lot of secondary dependencies, which are not even related to the project. This includes libfreetype, libpng, SwiftSoup, and XMLCoder. Removing the GIF serializer from the project erased these dependencies.
