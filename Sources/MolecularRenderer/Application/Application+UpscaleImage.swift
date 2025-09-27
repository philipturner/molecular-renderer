extension Application {
  public func upscale(image: Image) -> Image {
    guard renderTarget.upscaleFactor > 1 else {
      fatalError("Upscaling is not allowed.")
    }
    guard image.scaleFactor == 1 else {
      fatalError("Received image with incorrect scale factor.")
    }
    
    
    
    var output = Image()
    output.scaleFactor = renderTarget.upscaleFactor
    return output
  }
}
