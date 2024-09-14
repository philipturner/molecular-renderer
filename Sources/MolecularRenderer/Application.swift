import AppKit

public struct ApplicationDescriptor {
  public var display: Display?
  
  public init() {
    
  }
}

public class Application {
  var clock: Clock
  var display: Display
  
  public init(descriptor: ApplicationDescriptor) {
    guard let display = descriptor.display else {
      fatalError("Descriptor was incomplete.")
    }
    self.display = display
    
    clock = Clock()
  }
  
  public func run() {
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    application.activate(ignoringOtherApps: true)
    application.run()
  }
}
