# Renderer Window

With the renderer API, a window of your chosen resolution appears at program startup. You specify the monitor on which it appears, upscale factor (1x, 2x, 3x), and resolution after upscaling. The window displays the contents of real-time renders.

To close the window, click the "X" button at the top. You can also use `Cmd + W` (macOS) or `Ctrl + W` (Windows). On macOS, the window is typically out of focus when it first appears. Do not use `Cmd + W` until you click the window and bring it into focus.

The window does not register keyboard/mouse events or forward them to the program. Interactive WASD-type navigation of scenes is not a target use case. Users should learn how to use scripted camera movements for all animations, both real-time and offline.

## Metal Performance HUD

The Metal Performance HUD is enabled by default on macOS. This serves as an important guide for users with ProMotion displays, which can dynamically switch between various frame rates. If the scene is set up with the wrong settings, the display downgrades the refresh rate from 120 Hz to 60 Hz.
