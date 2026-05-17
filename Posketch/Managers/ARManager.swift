import RealityKit
import ARKit
import Combine
import SwiftUI

class ARManager: NSObject, ObservableObject, ARSessionDelegate {
    var arView = ARView(frame: .zero)
    var character: BodyTrackedEntity?
    let characterOffset: SIMD3<Float> = [-1.0, 0, 0]
    let characterAnchor = AnchorEntity()
    
    @Published var isPaused: Bool = false
    var isTakingSnapshot: Bool = false
    
    var loadingCancellable: AnyCancellable?
    var savedRelativeOrientation = simd_quatf(angle: 0, axis: [0, 1, 0])
    var dragOffset: SIMD3<Float> = [0, 0, 0]
    var spinOffset: Float = 0 // Tracks the two-finger rotation
    
    var modelName: String
    
    init(modelName: String) {
        self.modelName = modelName
        super.init()
        setupAR()
        setupGestures()
    }
    
    func setupAR() {
        arView.session.delegate = self
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        guard ARBodyTrackingConfiguration.isSupported else { return }
        arView.session.run(ARBodyTrackingConfiguration())
        arView.scene.addAnchor(characterAnchor)
        
        loadingCancellable = Entity.loadBodyTrackedAsync(named: modelName).sink(receiveCompletion: { _ in }, receiveValue: { [weak self] entity in
            if let body = entity as? BodyTrackedEntity {
                
                // Scale adjustment for custom models
                if self?.modelName == "WireframeRobotNew" {
                    body.scale = [0.8, 0.8, 0.8]
                } else {
                    body.scale = [1.0, 1.0, 1.0]
                }
                
                self?.applyAnimeEffect(to: body)
                self?.character = body
            }
        })
    }
    
    func setupGestures() {
        // 1. One-finger pan for moving
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        arView.addGestureRecognizer(pan)
        
        // 2. Two-finger twist for spinning
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        arView.addGestureRecognizer(rotation)
    }
    
    @objc func handlePan(_ g: UIPanGestureRecognizer) {
        guard isPaused else { return }
        let t = g.translation(in: arView)
        dragOffset.x += Float(t.x) * 0.0025
        dragOffset.y += Float(-t.y) * 0.0025
        g.setTranslation(.zero, in: arView)
    }
    
    @objc func handleRotation(_ g: UIRotationGestureRecognizer) {
        guard isPaused else { return }
        spinOffset -= Float(g.rotation)
        g.rotation = 0 // Reset gesture so spin is continuous and smooth
    }
    
    func toggleFreeze() {
        isPaused.toggle()
        if isPaused {
            arView.session.run(ARWorldTrackingConfiguration(), options: [])
            savedRelativeOrientation = simd_mul(simd_inverse(arView.cameraTransform.rotation), characterAnchor.orientation)
        } else {
            // Reset transforms when unpausing to find a new pose
            dragOffset = [0, 0, 0]
            spinOffset = 0
            arView.session.run(ARBodyTrackingConfiguration(), options: [])
        }
    }
    
    func takeSnapshot(completion: @escaping (UIImage?) -> Void) {
        isTakingSnapshot = true
        arView.environment.background = .color(.white)
        
        let savedPos = characterAnchor.position
        let savedOri = characterAnchor.orientation
        
        if isPaused {
            let cam = arView.cameraTransform
            
            // Push camera back (-4.8) to prevent cropping on export
            let worldPos = cam.matrix * SIMD4<Float>(0, -0.4, -4.8, 1.0)
            characterAnchor.position = [worldPos.x, worldPos.y, worldPos.z]
            
            // Apply the custom spin to the snapshot
            let spinQuat = simd_quatf(angle: spinOffset, axis: [0, 1, 0])
            characterAnchor.orientation = simd_mul(simd_mul(cam.rotation, savedRelativeOrientation), spinQuat)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.arView.snapshot(saveToHDR: false) { img in
                self.arView.environment.background = .cameraFeed()
                
                if self.isPaused {
                    self.characterAnchor.position = savedPos
                    self.characterAnchor.orientation = savedOri
                }
                
                self.isTakingSnapshot = false
                completion(img)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard !isPaused else { return }
        for a in anchors {
            guard let b = a as? ARBodyAnchor else { continue }
            let pos = simd_make_float3(b.transform.columns.3) + characterOffset
            let rot = Transform(matrix: b.transform).rotation
            if let c = character, c.parent == nil {
                characterAnchor.position = pos
                characterAnchor.orientation = rot
                characterAnchor.addChild(c)
            } else {
                characterAnchor.position = simd_mix(characterAnchor.position, pos, [0.1, 0.1, 0.1])
                characterAnchor.orientation = simd_slerp(characterAnchor.orientation, rot, 0.1)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isPaused && !isTakingSnapshot else { return }
        
        let cam = arView.cameraTransform
        let worldPos = cam.matrix * SIMD4<Float>(dragOffset.x, -0.5 + dragOffset.y, -2.5, 1.0)
        characterAnchor.position = simd_mix(characterAnchor.position, [worldPos.x, worldPos.y, worldPos.z], [0.08, 0.08, 0.08])
        
        // Apply the base freeze orientation PLUS the user's custom twist
        let spinQuat = simd_quatf(angle: spinOffset, axis: [0, 1, 0])
        let targetOrientation = simd_mul(simd_mul(cam.rotation, savedRelativeOrientation), spinQuat)
        
        characterAnchor.orientation = simd_slerp(characterAnchor.orientation, targetOrientation, 0.08)
    }
    
    func applyAnimeEffect(to e: Entity) {
        if var m = e.components[ModelComponent.self] {
            var out = UnlitMaterial(color: UIColor(white: 1.2, alpha: 1))
            out.faceCulling = .front
            m.materials = [out, UnlitMaterial(color: .black)]
            e.components.set(m)
        }
        for c in e.children { applyAnimeEffect(to: c) }
    }
    func updateMannequin(to newModelName: String) {
        // 1. Cancel any loading that might currently be happening
        loadingCancellable?.cancel()
        
        // 2. Update our internal tracker
        self.modelName = newModelName
        
        // 3. Remove the old 3D model from the AR World securely
        if let oldCharacter = character {
            oldCharacter.removeFromParent()
            self.character = nil
        }
        
        // 4. Load the new 3D Model
        loadingCancellable = Entity.loadBodyTrackedAsync(named: newModelName).sink(
            receiveCompletion: { _ in },
            receiveValue: { [weak self] entity in
                if let body = entity as? BodyTrackedEntity {
                    
                    // Apply your custom scale logic
                    if newModelName == "WireframeRobotNew" {
                        body.scale = [0.8, 0.8, 0.8]
                    } else {
                        body.scale = [1.0, 1.0, 1.0]
                    }
                    
                    // Apply your custom shader and save it
                    self?.applyAnimeEffect(to: body)
                    self?.character = body
                    
                    // If the AR world is currently "Frozen", we have to manually
                    // attach the new body to the frozen anchor right now.
                    // (If it's not frozen, the normal session(didUpdate:) loop handles it naturally)
                    if self?.isPaused == true {
                        self?.characterAnchor.addChild(body)
                    }
                }
            }
        )
    }
}

struct PosketchARView: UIViewRepresentable {
    @ObservedObject var manager: ARManager
    func makeUIView(context: Context) -> ARView { return manager.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
