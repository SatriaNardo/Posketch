import SwiftUI
import PhotosUI

struct ARBodyScreen: View {
    @AppStorage("selectedMannequin") private var selectedMannequin: String = "WireframeRobot1"
    
    @Environment(\.dismiss) var dismiss
    
    @Binding var isShowingAR: Bool
    var initialReferenceImage: UIImage? = nil
    
    @StateObject private var arManager: ARManager
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var referenceImage: UIImage? = nil
    @State private var refPosition: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var showRefImage: Bool = false
    
    @State private var capturedImage: UIImage? = nil
    @State private var navigateToDraw = false
    @State private var isProcessingImage = false
    
    init(isShowingAR: Binding<Bool>, initialReferenceImage: UIImage? = nil, modelName: String) {
        self._isShowingAR = isShowingAR
        self.initialReferenceImage = initialReferenceImage
        self._arManager = StateObject(wrappedValue: ARManager(modelName: modelName))
    }
    
    var body: some View {
        ZStack {
            // 1. AR BACKGROUND
            PosketchARView(manager: arManager)
                .edgesIgnoringSafeArea(.all)
            
            // 2. REFERENCE IMAGE OVERLAY
            if let ref = referenceImage, showRefImage {
                Image(uiImage: ref)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 260)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                    .offset(x: refPosition.width + dragOffset.width, y: refPosition.height + dragOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { dragOffset = $0.translation }
                            .onEnded {
                                refPosition.width += $0.translation.width
                                refPosition.height += $0.translation.height
                                dragOffset = .zero
                            }
                    )
                    .onTapGesture(count: 2) { showRefImage = false }
                    .position(x: 106, y: 210)
            }
            
            // 3. UI LAYER
            VStack {
                // TOP BAR: Back Button stays at the top
                HStack {
                    GlassButton(title: "Back", icon: "chevron.left", tint: .white) { dismiss() }
                    Spacer()
                    Menu {
                        Picker("Mannequin", selection: $selectedMannequin) {
                            Text("Standard").tag("WireframeRobot1")
                            Text("LowPoly").tag("WireframeRobotNew")
                        }
                    } label: {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // BOTTOM BAR: Tight "Control Pod" Layout
                HStack(alignment: .center) {
                    Spacer()
                    
                    HStack(spacing: 20) {
                        // LEFT: Reference Picker
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            SideControlButton(icon: referenceImage == nil ? "photo" : "photo.on.rectangle")
                        }
                        .onChange(of: selectedItem) { newItem in
                            guard let newItem = newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                                    await MainActor.run {
                                        referenceImage = img
                                        showRefImage = true
                                        selectedItem = nil
                                    }
                                }
                            }
                        }
                        
                        // CENTER: Primary Action (Freeze / Draw)
                        ZStack {
                            if arManager.isPaused {
                                // The DRAW Button
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    showRefImage = false
                                    isProcessingImage = true
                                    arManager.takeSnapshot { img in
                                        guard let img = img else { isProcessingImage = false; return }
                                        Task.detached(priority: .userInitiated) {
                                            let processed = await cropRobotCenteredBackground(from: img)
                                            await MainActor.run {
                                                capturedImage = processed
                                                isProcessingImage = false
                                                navigateToDraw = true
                                            }
                                        }
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "pencil.and.outline")
                                            .font(.system(size: 30, weight: .bold))
                                        Text("DRAW")
                                            .font(.custom("Noteworthy-Bold", size: 14))
                                    }
                                    .foregroundColor(.black)
                                    .frame(width: 88, height: 88)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                                }
                                .transition(.scale.combined(with: .opacity))
                            } else {
                                // The SHUTTER / FREEZE Button
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    arManager.toggleFreeze()
                                }) {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: 4)
                                            .frame(width: 80, height: 80)
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 66, height: 66)
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 100)
                        
                        // RIGHT: Resume Button (Only when paused)
                        if arManager.isPaused {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                arManager.toggleFreeze()
                            }) {
                                SideControlButton(icon: "play.fill")
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Empty space holder to keep center button perfectly centered
                            Color.clear.frame(width: 54, height: 54)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 50)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: arManager.isPaused)
            }
            
            // 4. LOADING OVERLAY
            if isProcessingImage {
                ZStack {
                    Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.black)
                        Text("Preparing Canvas...")
                            .font(.custom("Noteworthy-Bold", size: 18))
                            .foregroundColor(.black)
                    }
                    .padding(40)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            referenceImage = initialReferenceImage
            showRefImage = (initialReferenceImage != nil)
        }
        .onChange(of: selectedMannequin) { newModel in
            arManager.updateMannequin(to: newModel)
        }
        .fullScreenCover(isPresented: $navigateToDraw) {
            if let img = capturedImage {
                DrawingScreen(backgroundImage: img, sourceURL: nil) { isShowingAR = false }
                .onDisappear {
                    capturedImage = nil
                }
            }
        }
    }
}


