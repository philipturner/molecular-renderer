# Other Documentation

## Render Process Diagram

![Render Process Diagram](./RenderProcessDiagram.png)

<details>
<summary>Personal notes about the async raw pixel buffer, which was out of scope for the latest PR</summary>

```swift
// Implement the "asynchronous raw pixel buffer handler" functionality promised
// in the render process diagram.
// - [IMPORTANT] Decide on the best name for the API function that exposes
//   this functionality.
// - Handlers should be executed on a sequential dispatch queue. Although it's
//   not thread safe with the main or @MainActor thread, it's thread safe
//   between sequential calls to itself.
// - Implement an equivalent of 3 frames in flight DispatchSemaphore for the
//   asynchronous handlers, to avoid overflowing the dispatch queue for this.
// - Guarantee that all asynchronous handlers have executed before
//   'application.run' returns.
//
// Can probably make this feature very far down the priority list; offline
// rendering is not the primary use case of interactive CAD programs. It will
// be needed to make professional YouTube videos from rendered animations.
```

</details>

## Ambient Occlusion Sample Count

The most computationally intensive part of rendering is estimating the degree of self-shadowing, or how "occluded" / crowded a location is. A place wedged between two atoms should appear darker than an unobstructed surface exposed directly to open space. In practice, this is achieved by randomly choosing a set of ray directions, then following the rays until they hit a nearby surface.

A default of 7 secondary rays results in sufficient quality for any general use case. However, in cases prone to high divergence (non-uniform control flow, disorder or random memory access patterns), GPU performance may degrade so much that the FPS target cannot be reached. Divergence happens more often in regions far away from the camera. At large distances, each atom appears smaller, which (long story short) means higher divergence.

There is a highly tuned heuristic that reduces the sample count to 3, at a certain distance from the user. This particular case can afford lower rendering quality anyway. This heuristic will be implemented in the acceleration structure PR.

## Atom Count Limitation

In its current state, the cross-platform Molecular Renderer lacks an acceleration structure to speed up ray-sphere intersections. Therefore, the compute cost of rendering scales linearly with the atom count. Until an acceleration structure is implemented, you can try tweaking a few settings to render as many atoms as possible.

The time to render a frame is a multiplication of many variables. Like the Drake Equation, changing a few by 2x could change the end result by 10x. The code base has always been tested at a "reasonable" window size for general applications, but you can squint at a 480x480 window for structures in the 100&ndash;1000 atom range.

| Multiplicative Factor | Explanation |
| --------------------- | ----------- |
| GPU model             | More powerful GPUs render a scene faster |
| FPS target            | Lower refresh-rate displays permit more render time (in ms/frame) |
| Window resolution     | Less pixels means less compute cost |
| Upscale factor        | Make this as high as possible without graphical quality issues |
| Atom count            | $O(n)$ with the current implementation. In the future, more like $O(1)$. |
| AO sample count       | Number of rays cast/pixel = (1 + AO sample count). Primary ray will be more expensive than AO rays because it must travel extremely large distances through the uniform grid. |
| Acceleration structure update | (In the future) GPU time spent updating the acceleration structure will eat into time available for rendering. The cost of this scales linearly with atom count (atoms that are moving, not atom count of the entire scene). |
| Coverage of FOV       | Images with mostly empty space will not incur the cost of AO rays. This makes it look like the renderer supports larger atom counts than it actually does, in general applications. |

These combinations of settings are known to run smoothly (or predicted to).

| Multiplicative Factor | macOS     | macOS (target audience) | Windows |
| --------------------- | :-------: | :-------: | :-------: |
| GPU model             | M1 Max    | M1        | GTX 970   |
| FPS target            | 120 Hz    | 60 Hz     | 60 Hz     |
| Window resolution     | 1920x1920 | 1200x1200 | 1200x1200 |
| Upscale factor        | 1x        | 1x        | 1x        |
| Atom count            | 12        | 12        | 12        |
| AO sample count       | 7         | 7         | 7         |

## MetalFX Latency Issues

On macOS, there is a problem with the MetalFX framework that may lead to massive program startup times. These appear as if Swift switched from `-Xswiftc -Ounchecked` to true release mode, making the user wait up to 10 seconds to compile after the tiniest change to the code.

The source of this problem was narrowed down to ANECompilerService, which is invoked when creating `MTLFXTemporalUpscaler` for the first time after the Swift program has been recompiled with changes. The first-time latency is dictated by the graph below, where the intermediate size is the texture size prior to upscaling. The second-time latency is 0.2&ndash;0.3 seconds.

![ANECompilerService Latency](./ANECompilerServiceLatency.png)

In a typical use case, the upscaled size is 1920x1920 and the intermediate size is 640x640. The user faces a 2-second delay on every program startup, which would typically be hard to notice. The upscale factor is then switched from 3x to 2x, making the intermediate size 960x960. The delay skyrockets to 10 seconds. This is the exact scenario that led to discovery of the problem. It may have been around since 2023, as the earliest upscaling went from 640x640 -> 1280x1280.

## FidelityFX Quality Issues

Molecular Renderer was originally developed with MetalFX, an ML-based upscaler. AMD FSR 3 (the version portable to a wide variety of GPU models) is not ML-based. The first major difference is ghosting when atoms suddenly disappear/appear in the scene. For an animation switching between isopropanol and silane, the ghosting is worst when the molecules aren't moving, and they alternate every 1 second. Waiting 3&ndash;10 seconds before switching, or including a 0.5 Hz rotation animation, makes the ghosting hard to notice.

The next major difference is the need for higher AO sample count. This may be coupled with the fact that the macOS setup runs at 120 Hz, while the Windows setup runs at 60 Hz. With no upscaling, the higher refresh rate created more temporal averaging from perception of the human viewer. 120 Hz @ 7 AO samples could "average" as well as 60 Hz @ 15 AO samples. The shaders should be exactly the same on both platforms; this is the best explanation for the quality drop on 60 Hz @ 7 AO samples.

With upscaling turned on, FidelityFX struggled to accurately denoise the AO. It was very pixelated or grainy when atoms moved fast. Switching from 7 to 15 samples massively improved this graininess. While graininess is still present, the degree of severity is now tolerable. 15 samples are needed, regardless of whether the upscale factor is 2x or 3x.

> The default AO sample count has risen to 15 on all platforms, for fairness/equality between platforms. For members of the macOS target audience (base M1 chip), you probably want to reduce this to 7. AO sample count is specified in `RenderShader.swift`.

There are a few other, minor artifacts. Along the border between a silicon and hydrogen atom, white pixels can appear sporadically on the silicon side. Also, when atoms move quickly (isopropanol rotating at 0.5 Hz), the border between atoms can be a bit jumpy. In the MM4 carbosilane test, FSR shows noticeable artifacts at the borders between slowly moving atoms, while MetalFX does not.

Despite its downsides, FSR 3 makes it possible to bring Molecular Renderer to the Windows target audience (GTX 970 and later, RDNA 1 and later). Older hardware works precisely because FSR 3 does not rely on computationally intensive neural networks, and it does not require hardware FP16 arithmetic.

## 16-Bit Data Types Optimization

It is possible to reduce the memory costs of the acceleration structure, by taking advantage of the small number of atoms per 2 nm voxel (less than 2<sup>16</sup>) and compressing atom positions to FP16. This optimization slightly speeds up the BVH update process and ray-sphere intersection tests.

This optimization has been deferred to a future PR. It adds more complexity to the BVH construction process and may require OS-specific profilers to confirm performance improvements.
