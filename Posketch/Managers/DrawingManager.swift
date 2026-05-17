import PencilKit
import SwiftUI
import Combine

class DrawingManager: ObservableObject {
    var canvasView = PKCanvasView()
    var toolPicker = PKToolPicker()
    @Published var isEraserActive = false
    var previousTool: PKTool?
    
    // We removed the zoom and image hacks from here!
    init(sourceURL: URL?) {
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.drawingPolicy = .anyInput
        canvasView.overrideUserInterfaceStyle = .light
        
        if let url = sourceURL, let data = try? Data(contentsOf: url.appendingPathExtension("pkdrawing")), let savedDrawing = try? PKDrawing(data: data) {
            canvasView.drawing = savedDrawing
        }
    }
    
    func setupToolPicker() {
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
    }
    
    func toggleEraser() {
        isEraserActive.toggle()
        if isEraserActive {
            previousTool = canvasView.tool; canvasView.tool = PKInkingTool(.marker, color: .white, width: 40)
        } else {
            if let prev = previousTool { canvasView.tool = prev } else { canvasView.tool = PKInkingTool(.pen, color: .black, width: 5) }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
struct PKCanvasContainer: UIViewRepresentable {
    @ObservedObject var manager: DrawingManager
    var backgroundImage: UIImage? // We pass the image directly to the container now!
    
    func makeUIView(context: Context) -> UIScrollView {
        // 1. The Master Scroll View that handles perfect pinching
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        // Ensure 1-finger draws, 2-fingers pan/zoom
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        
        // 2. The Container that holds everything
        let containerView = UIView()
        let screenBounds = UIScreen.main.bounds
        containerView.frame = screenBounds
        
        // 3. Layer 0: The Background Image
        if let bg = backgroundImage {
            let imageView = UIImageView(image: bg)
            imageView.contentMode = .scaleAspectFit
            imageView.frame = screenBounds
            containerView.addSubview(imageView)
        }
        
        // 4. Layer 1: The Drawing Canvas
        let canvas = manager.canvasView
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.frame = screenBounds
        
        // Disable the canvas's internal scrolling so it doesn't fight our Master ScrollView
        canvas.isScrollEnabled = false
        
        containerView.addSubview(canvas)
        scrollView.addSubview(containerView)
        scrollView.contentSize = screenBounds.size
        
        DispatchQueue.main.async { manager.setupToolPicker() }
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        // Tells the ScrollView exactly which view to zoom in on
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }
    }
}
