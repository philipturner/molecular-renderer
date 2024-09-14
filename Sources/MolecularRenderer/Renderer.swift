import Metal
import QuartzCore

public class Renderer {
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var computePipelineState: MTLComputePipelineState
  
  var frameID: Int = .zero
  
  init() {
    device = MTLCreateSystemDefaultDevice()!
    commandQueue = device.makeCommandQueue()!
    computePipelineState = Renderer
      .createComputePipelineState(device: device)
  }
  
  public func render(
    encoder: MTLComputeCommandEncoder,
    renderTarget: MTLTexture
  ) {
    frameID += 1
    
    // Bind the buffers.
    do {
      func setTime(_ time: Double, index: Int) {
        let fractionalTime = time - floor(time)
        var time32 = Float(fractionalTime)
        encoder.setBytes(&time32, length: 4, index: index)
      }
      
      let frameIDTime = Double(frameID) / 120
      
      setTime(frameIDTime, index: 0)
      setTime(Double.zero, index: 1)
      setTime(Double.zero, index: 2)
    }
    
    // Bind the textures.
    encoder.setTexture(renderTarget, index: 0)
    
    // Dispatch
    do {
      encoder.setComputePipelineState(computePipelineState)
      
      let width = Int(renderTarget.width)
      let height = Int(renderTarget.height)
      encoder.dispatchThreads(
        MTLSize(width: width, height: height, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    }
  }
}

extension Renderer {
  static func createSource() -> String {
    """
    
    #include <metal_stdlib>
    using namespace metal;
    
    half convertToChannel(
      half hue,
      half saturation,
      half lightness,
      ushort n
    ) {
      half k = half(n) + hue / 30;
      k -= 12 * floor(k / 12);
      
      half a = saturation;
      a *= min(lightness, 1 - lightness);
    
      half output = min(k - 3, 9 - k);
      output = max(output, half(-1));
      output = min(output, half(1));
      output = lightness - a * output;
      return output;
    }
    
    kernel void renderImage(
      constant float *time0 [[buffer(0)]],
      constant float *time1 [[buffer(1)]],
      constant float *time2 [[buffer(2)]],
      texture2d<half, access::write> drawableTexture [[texture(0)]],
      ushort2 tid [[thread_position_in_grid]]
    ) {
      half4 color;
      if (tid.y < 1600) {
        color = half4(0.707, 0.707, 0.00, 1.00);
      } else {
        float progress = float(tid.x) / 1920;
        if (tid.y < 1600 + 107) {
          progress += *time0;
        } else if (tid.y < 1600 + 213) {
          progress += *time1;
        } else {
          progress += *time2;
        }
        
        half hue = half(progress) * 360;
        half saturation = 1.0;
        half lightness = 0.5;
        
        half red = convertToChannel(hue, saturation, lightness, 0);
        half green = convertToChannel(hue, saturation, lightness, 8);
        half blue = convertToChannel(hue, saturation, lightness, 4);
        color = half4(red, green, blue, 1.00);
      }
      
      drawableTexture.write(color, tid);
    }
    
    """
  }
  
  static func createComputePipelineState(
    device: MTLDevice
  ) -> MTLComputePipelineState {
    let shaderSource = Renderer.createSource()
    let library = try! device.makeLibrary(source: shaderSource, options: nil)
    
    let function = library.makeFunction(name: "renderImage")
    guard let function else {
      fatalError("Could not make function.")
    }
    let pipeline = try! device.makeComputePipelineState(function: function)
    return pipeline
  }
}
