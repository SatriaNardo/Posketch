import UIKit
import RealityKit
import ARKit
import Combine

class ARBodyViewController: UIViewController, ARSessionDelegate {

    var arView: ARView!
    
    // The 3D character to display.
    var character: BodyTrackedEntity?
    let characterOffset: SIMD3<Float> = [-1.0, 0, 0] // Offset the character by one meter to the left
    let characterAnchor = AnchorEntity()
    
    // Track the loading process
    var loadingCancellable: AnyCancellable? = nil
    
    // Track the pause state
    var isPaused: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Programmatically setup the visual ARView only
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        // Add the freeze button to the screen on top of the ARView
        setupFreezeButton()
    }
    
    // 2. We moved all the AR logic back to viewDidAppear, exactly like your old code!
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        arView.session.delegate = self
        
        // Guard for hardware support
        guard ARBodyTrackingConfiguration.isSupported else {
            print("This feature is only supported on devices with an A12 chip")
            return
        }

        // Run the body tracking configuration
        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
        
        arView.scene.addAnchor(characterAnchor)
        
        // REVERTED: We removed the ".usdz" so it perfectly matches your working code
        loadingCancellable = Entity.loadBodyTrackedAsync(named: "WireframeRobot")
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Error: Unable to load model: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] (entity: Entity) in
                guard let self = self else { return }
                
                if let bodyTrackedEntity = entity as? BodyTrackedEntity {
                    // Scale to human size
                    bodyTrackedEntity.scale = [1.0, 1.0, 1.0]
                    
                    // Apply the Anime "Inverted Hull" Effect
                    self.applyAnimeEffect(to: bodyTrackedEntity)
                    
                    self.character = bodyTrackedEntity
                    print("SUCCESS: Mannequin loaded and ready!")
                } else {
                    print("Error: Loaded entity is not a BodyTrackedEntity")
                }
            })
    }
    
    // MARK: - Freeze Logic
    @objc func toggleFreeze() {
        isPaused.toggle()
        let button = view.subviews.compactMap { $0 as? UIButton }.first
        
        if isPaused {
            // --- FREEZE MODE ---
            button?.setTitle("Resume Tracking", for: .normal)
            button?.backgroundColor = .systemRed
            
            // Switch to World Tracking. This turns off the body detection camera feed.
            let config = ARWorldTrackingConfiguration()
            arView.session.run(config, options: [])
            
            // --- TELEPORT TO CENTER OF SCREEN ---
            let cameraTransform = arView.cameraTransform
            let offset = SIMD3<Float>(0, -0.5, -2.0)
            let worldPosition = cameraTransform.matrix * SIMD4<Float>(offset.x, offset.y, offset.z, 1.0)
            
            characterAnchor.position = SIMD3<Float>(worldPosition.x, worldPosition.y, worldPosition.z)
            
        } else {
            // --- LIVE MODE ---
            button?.setTitle("Freeze Pose", for: .normal)
            button?.backgroundColor = .systemBlue
            
            // Switch back to Body Tracking. ARKit resumes looking for human poses.
            let config = ARBodyTrackingConfiguration()
            arView.session.run(config, options: [])
        }
    }
    
    // MARK: - Anime Shading Logic
    func applyAnimeEffect(to entity: Entity) {
        if var modelComponent = entity.components[ModelComponent.self] {
            let bodyMaterial = UnlitMaterial(color: .black)
            var outlineMaterial = UnlitMaterial(color: .white)
            outlineMaterial.faceCulling = .front
            modelComponent.materials = [outlineMaterial, bodyMaterial]
            entity.components.set(modelComponent)
        }
        for child in entity.children {
            applyAnimeEffect(to: child)
        }
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard !isPaused else { return }
        
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            let targetPosition = bodyPosition + characterOffset
            let targetOrientation = Transform(matrix: bodyAnchor.transform).rotation
    
            if let character = character, character.parent == nil {
                characterAnchor.position = targetPosition
                characterAnchor.orientation = targetOrientation
                characterAnchor.addChild(character)
            } else {
                let smoothingFactor: Float = 0.1
                characterAnchor.position = simd_mix(characterAnchor.position, targetPosition, SIMD3<Float>(repeating: smoothingFactor))
                characterAnchor.orientation = simd_slerp(characterAnchor.orientation, targetOrientation, smoothingFactor)
            }
        }
    }
    
    // MARK: - UI Setup
    func setupFreezeButton() {
        let button = UIButton(type: .system)
        button.setTitle("Freeze Pose", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(toggleFreeze), for: .touchUpInside)
        
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            button.widthAnchor.constraint(equalToConstant: 200),
            button.heightAnchor.constraint(equalToConstant: 55)
        ])
    }
}
