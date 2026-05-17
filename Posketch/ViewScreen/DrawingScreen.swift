import SwiftUI
import PencilKit

struct DrawingScreen: View {
    @Environment(\.dismiss) var dismiss
    var backgroundImage: UIImage?
    var onSaveComplete: (() -> Void)?
    
    @StateObject var drawingManager: DrawingManager
    
    @State var currentSourceURL: URL?
    
    @State var showSaveDialog = false
    @State var isShowingAddCategoryAlert = false
    @State var isCategoryDropdownExpanded = false
    @State var newCategoryName = ""
    
    @State var poseName: String
    @State var selectedCategory: String
    @State var categories: [String] = []
    
    @State var pendingExport: Bool = false
    @State var isShowingShareSheet = false
    @State var exportedImageToShare: UIImage? = nil
    
    // NEW: A dynamic string so we can show "Saving..." or "Preparing Image..."
    @State var loadingMessage: String? = nil
    @State var rotationAngle: Double = 0
    
    init(backgroundImage: UIImage?, sourceURL: URL? = nil, onSaveComplete: (() -> Void)? = nil) {
        self.backgroundImage = backgroundImage
        self.onSaveComplete = onSaveComplete
        _currentSourceURL = State(initialValue: sourceURL)
        _drawingManager = StateObject(wrappedValue: DrawingManager(sourceURL: sourceURL))
        
        if let url = sourceURL {
            let filename = url.deletingPathExtension().lastPathComponent
            let parts = filename.components(separatedBy: "---")
            if parts.count >= 2 {
                _selectedCategory = State(initialValue: parts[0])
                _poseName = State(initialValue: parts[1])
            } else {
                _selectedCategory = State(initialValue: "Action")
                _poseName = State(initialValue: "")
            }
        } else {
            _selectedCategory = State(initialValue: "Action")
            _poseName = State(initialValue: "")
        }
    }
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            if let bg = backgroundImage {
                Image(uiImage: bg)
                    .resizable()
                    .scaledToFit()
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Pass the image directly into our new wrapper!
                        PKCanvasContainer(manager: drawingManager, backgroundImage: backgroundImage)
                            .rotationEffect(.degrees(rotationAngle))
                            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    
                    HStack(spacing: 8) {
                        GlassButton(title: "Exit", icon: "xmark", tint: .red) { dismiss() }
                        
                        GlassButton(
                            title: drawingManager.isEraserActive ? "Pen" : "Erase",
                            icon: drawingManager.isEraserActive ? "pencil.tip" : "eraser",
                            tint: drawingManager.isEraserActive ? .orange : .white
                        ) {
                            drawingManager.toggleEraser()
                        }
                        
                        GlassButton(title: "Share", icon: "square.and.arrow.up", tint: .white) {
                            if currentSourceURL != nil {
                                loadingMessage = "Preparing Image..."
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let img = createExportImage() {
                                        exportedImageToShare = img
                                        isShowingShareSheet = true
                                    }
                                    loadingMessage = nil
                                }
                            } else {
                                pendingExport = true
                                categories = UserDefaults.standard.stringArray(forKey: "SavedCategories") ?? ["Action", "Idle", "Sitting"]
                                if !categories.contains(selectedCategory) { selectedCategory = categories.first ?? "Action" }
                                showSaveDialog = true
                            }
                        }
                        
                        if currentSourceURL != nil {
                            GlassButton(title: "Update", icon: "checkmark", tint: .blue) { processAutoSave() }
                        } else {
                            GlassButton(title: "Save", icon: "checkmark", tint: .blue) {
                                pendingExport = false
                                categories = UserDefaults.standard.stringArray(forKey: "SavedCategories") ?? ["Action", "Idle", "Sitting"]
                                if !categories.contains(selectedCategory) { selectedCategory = categories.first ?? "Action" }
                                showSaveDialog = true
                            }
                        }
                    }
                    .padding(6)
                    .background(Color.clear)
                    
                    Spacer()
                }
                .padding(.top, 16)
                Spacer()
            }
            
            // --- UPDATED DYNAMIC LOADING OVERLAY ---
            if let message = loadingMessage {
                ZStack {
                    Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.black)
                        Text(message)
                            .font(.custom("Noteworthy-Bold", size: 18))
                            .foregroundColor(.black)
                    }
                    .padding(40)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: loadingMessage != nil)
        .onDisappear {
            drawingManager.canvasView.drawing = PKDrawing()
            drawingManager.canvasView.removeFromSuperview()
        }
        .sheet(isPresented: $showSaveDialog) {
            NavigationStack {
                Form {
                    Section(header: Text(pendingExport ? "Save Details Before Exporting" : "Pose Details")) {
                        TextField("Pose Name (e.g. Jumping Kick)", text: $poseName)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Category")
                                Spacer()
                                
                                Button(action: {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    withAnimation(.easeInOut(duration: 0.2)) { isCategoryDropdownExpanded.toggle() }
                                }) {
                                    HStack(spacing: 4) {
                                        Text(selectedCategory).foregroundColor(.gray)
                                        Image(systemName: "chevron.down").foregroundColor(.gray).rotationEffect(.degrees(isCategoryDropdownExpanded ? 180 : 0))
                                    }
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                
                                Button(action: { isShowingAddCategoryAlert = true }) {
                                    Image(systemName: "plus.circle.fill").foregroundColor(.black).font(.system(size: 22))
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 4)
                            
                            if isCategoryDropdownExpanded {
                                Divider().padding(.vertical, 8)
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(categories, id: \.self) { category in
                                            Button(action: {
                                                selectedCategory = category
                                                withAnimation(.easeInOut(duration: 0.2)) { isCategoryDropdownExpanded = false }
                                            }) {
                                                HStack {
                                                    Text(category).foregroundColor(.primary)
                                                    Spacer()
                                                    if category == selectedCategory {
                                                        Image(systemName: "checkmark").foregroundColor(.blue).fontWeight(.bold)
                                                    }
                                                }
                                                .padding(.vertical, 12)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                            
                                            if category != categories.last { Divider().padding(.leading, 4) }
                                        }
                                    }
                                }
                                .frame(maxHeight: 220)
                            }
                        }
                    }
                }
                .navigationTitle(currentSourceURL == nil ? (pendingExport ? "Export Pose" : "Save Pose") : "Save As New Pose")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showSaveDialog = false; pendingExport = false }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { processSave() } }
                }
                .alert("New Category", isPresented: $isShowingAddCategoryAlert) {
                    TextField("Category Name", text: $newCategoryName)
                    Button("Cancel", role: .cancel) { newCategoryName = "" }
                    Button("Add") {
                        if !newCategoryName.isEmpty && !categories.contains(newCategoryName) {
                            categories.append(newCategoryName)
                            UserDefaults.standard.set(categories, forKey: "SavedCategories")
                            selectedCategory = newCategoryName
                            NotificationCenter.default.post(name: NSNotification.Name("CategoriesUpdated"), object: nil)
                        }
                        newCategoryName = ""
                    }
                }
            }
            .presentationDetents([.height(isCategoryDropdownExpanded ? 450 : 250)])
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let imgToShare = exportedImageToShare {
                ShareSheet(items: [imgToShare]) {
                    if let returnToMenu = onSaveComplete {
                        returnToMenu()
                    } else {
                        dismiss()
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}
