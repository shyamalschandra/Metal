import Cocoa
import Metal
import simd

class MetalView: NSView {
    
    // MARK: Definitions
    
    private struct Vertex {
        var position : float4
        var color : float4
    }
    
    override func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }
    
    // MARK: Properties
    
    private var metalLayer : CAMetalLayer { return self.layer as! CAMetalLayer }
    private let device : MTLDevice
    private var pipeline : MTLRenderPipelineState
    private var commandQueue : MTLCommandQueue
    private var vertexBuffer : MTLBuffer
    
    // MARK: Functionality
    
    required init?(coder aDecoder: NSCoder) {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.newCommandQueue()
        
        // Setup buffer (non-transient)
        let vertices = [    // Coordinates defined in clip space: [-1,+1]
            Vertex(position: [ 0,    0.5, 0, 1], color: [1,0,0,1]),
            Vertex(position: [-0.5, -0.5, 0, 1], color: [0,1,0,1]),
            Vertex(position: [ 0.5, -0.5, 0, 1], color: [0,0,1,1])
        ]
        vertexBuffer = device.newBufferWithBytes(vertices, length: sizeof(Vertex) * vertices.count, options: .CPUCacheModeDefaultCache)
        
        // Setup shader library
        guard let library = device.newDefaultLibrary() else { fatalError("No default library") }
        guard let vertexFunc: MTLFunction   = library.newFunctionWithName("vertex_main"),
              let fragmentFunc: MTLFunction = library.newFunctionWithName("fragment_main") else { fatalError("Shader not found") }
        
        // Setup pipeline (non-transient)
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm   // 8-bit unsigned integer [0, 255]
        pipeline = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
        
        super.init(coder: aDecoder)
        
        // Setup layer (backing layer)
        self.wantsLayer = true
        self.metalLayer.device = device
        self.metalLayer.pixelFormat = .BGRA8Unorm
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let window = self.window {
            self.metalLayer.contentsScale = window.backingScaleFactor
        } else {
            // Nothing for now
        }
        self.redraw()
    }
    
    override func setBoundsSize(newSize: NSSize) {
        super.setBoundsSize(newSize)
        metalLayer.drawableSize = convertRectToBacking(bounds).size
        self.redraw()
    }
    
    override func setFrameSize(newSize: NSSize) {
        super.setFrameSize(newSize)
        metalLayer.drawableSize = convertRectToBacking(bounds).size
        self.redraw()
    }
    
    private func redraw() {
        guard let drawable = self.metalLayer.nextDrawable() else { return }
        let framebufferTexture = drawable.texture
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = framebufferTexture
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        renderPass.colorAttachments[0].loadAction = .Clear
        renderPass.colorAttachments[0].storeAction = .Store
        
        // Setup Command Buffers (transient)
        let cmdBuffer = self.commandQueue.commandBuffer()
        
        // Setup Command Encoders (transient)
        let encoder = cmdBuffer.renderCommandEncoderWithDescriptor(renderPass)
        encoder.setRenderPipelineState(self.pipeline)
        encoder.setVertexBuffer(self.vertexBuffer, offset: 0, atIndex: 0)
        encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        
        // Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
        cmdBuffer.presentDrawable(drawable)
        cmdBuffer.commit()
    }
}
