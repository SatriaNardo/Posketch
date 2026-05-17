import SwiftUI
import PhotosUI
import PencilKit

struct PosketchMainMenuView: View {
    @AppStorage("selectedMannequin") private var selectedMannequin: String = "WireframeRobot1"
    
    @State var allPoses: [PoseModel] = []
    @State var categories: [String] = []
    @State var selectedCategory: String = "All"
    @State var currentSort: SortType = .newest
    
    @State var isShowingAddCategory = false
    @State var newCategoryName = ""
    @State var isShowingDeleteAlert = false
    @State var categoryToDelete: String? = nil
    
    @State var arContext: ARContext? = nil
    @State var selectedGalleryItem: PhotosPickerItem? = nil
    
    @Namespace var tabAnimation
    @State var isSelectionMode = false
    @State var selectedPoseURLs: Set<URL> = []
    @State var isMenuExpanded = false
    
    // NEW: Handles the main menu loading popup strings
    @State var loadingStatus: String? = nil
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    
    var columns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [GridItem(.adaptive(minimum: 160), spacing: 0)]
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)
        }
    }
    
    var filteredPoses: [PoseModel] {
        let filtered = selectedCategory == "All" ? allPoses : allPoses.filter { $0.category == selectedCategory }
        
        switch currentSort {
        case .newest:
            return filtered.sorted { $0.dateAdded > $1.dateAdded }
        case .oldest:
            return filtered.sorted { $0.dateAdded < $1.dateAdded }
        case .az:
            return filtered.sorted { $0.poseName.localizedStandardCompare($1.poseName) == .orderedAscending }
        case .za:
            return filtered.sorted { $0.poseName.localizedStandardCompare($1.poseName) == .orderedDescending }
        }
    }
    
    var allTabs: [String] {
        return ["All"] + categories
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(UIColor.systemGray6) : Color(white: 1))
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    
                    HStack {
                        if horizontalSizeClass == .regular
                        {
                        Text("Posketch")
                            .font(.custom("Noteworthy-Bold", size: 42))
                            .foregroundColor(.primary)
                        }
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Menu {
                                Picker("Mannequin", selection: $selectedMannequin) {
                                    Text("Standard").tag("WireframeRobot1")
                                    Text("LowPoly").tag("WireframeRobotNew")
                                }
                            } label: {
                                Image(systemName: "figure.stand")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(Color.primary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            if !allPoses.isEmpty {
                                Button(action: {
                                    withAnimation {
                                        isSelectionMode.toggle()
                                        selectedPoseURLs.removeAll()
                                    }
                                }) {
                                    Text(isSelectionMode ? "Cancel" : "Select")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.black.opacity(0.8))
                                        .clipShape(Capsule())
                                }
                            }
                            
                            if isMenuExpanded {
                                PhotosPicker(selection: $selectedGalleryItem, matching: .images) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(.primary)
                                        .frame(width: 44, height: 44)
                                }
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                .onChange(of: selectedGalleryItem) { newItem in
                                    guard let newItem = newItem else { return }
                                    Task {
                                        if let data = try? await newItem.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                                            await MainActor.run {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                    arContext = ARContext(image: img)
                                                }
                                                withAnimation(.spring()) { isMenuExpanded = false }
                                            }
                                        }
                                        await MainActor.run {
                                            selectedGalleryItem = nil
                                        }
                                    }
                                }
                                
                                Button(action: {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        arContext = ARContext(image: nil)
                                    }
                                    withAnimation(.spring()) { isMenuExpanded = false }
                                }) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(.primary)
                                        .frame(width: 44, height: 44)
                                }
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                
                                Button(action: {
                                    withAnimation(.spring()) { isMenuExpanded = false }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(.primary)
                                        .frame(width: 44, height: 44)
                                }
                                .transition(.scale.combined(with: .opacity))
                                
                            } else {
                                Button(action: {
                                    withAnimation(.spring()) { isMenuExpanded = true }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(.primary)
                                        .frame(width: 44, height: 44)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    
                    HStack(spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(allTabs, id: \.self) { tab in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.5)) {
                                            selectedCategory = tab
                                        }
                                    }) {
                                        Text(tab)
                                            .font(.system(size: 15, weight: .bold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .foregroundColor(selectedCategory == tab ? .black : .white)
                                            .background(
                                                ZStack {
                                                    if selectedCategory == tab {
                                                        Capsule()
                                                            .fill(Color.white)
                                                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                                            .matchedGeometryEffect(id: "ActiveTab", in: tabAnimation)
                                                    }
                                                }
                                            )
                                    }
                                    .buttonStyle(NoHighlightButtonStyle())
                                    .contextMenu {
                                        if tab != "All" && selectedCategory == tab {
                                            Button(role: .destructive) {
                                                categoryToDelete = tab
                                                isShowingDeleteAlert = true
                                            } label: {
                                                Label("Delete Category", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Divider()
                            .frame(height: 20)
                            .background(Color.white.opacity(0.5))
                            .padding(.horizontal, 2)
                        
                        Menu {
                            Picker("Sort Options", selection: $currentSort) {
                                ForEach(SortType.allCases, id: \.self) { sortType in
                                    Text(sortType.rawValue).tag(sortType)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 6)
                        
                        Button(action: {
                            isShowingAddCategory = true
                        }) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: colorScheme == .dark ? [Color(white: 0.15), Color(white: 0.3), Color(white: 0.5)] : [Color.black, Color(white: 0.2), Color(white: 0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    
                    ScrollView {
                        if filteredPoses.isEmpty {
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(0.05))
                                        .frame(width: 90, height: 90)
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 40, weight: .light))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.bottom, 8)
                                
                                Text("Empty Category")
                                    .font(.custom("Noteworthy-Bold", size: 28))
                                    .foregroundColor(.primary)
                                
                                Text("There's no image in \"\(selectedCategory)\"")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                            .frame(maxWidth: 350)
                            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                            .cornerRadius(30)
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.primary.opacity(0.08), lineWidth: 1.5))
                            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 10)
                            .padding(.top, 60)
                            .frame(maxWidth: .infinity, minHeight: 400)
                            
                        } else {
                            LazyVGrid(columns: columns, spacing: 0) {
                                ForEach(filteredPoses) { pose in
                                    if isSelectionMode {
                                        Button(action: {
                                            if let url = pose.fileURL {
                                                if selectedPoseURLs.contains(url) {
                                                    selectedPoseURLs.remove(url)
                                                } else {
                                                    selectedPoseURLs.insert(url)
                                                }
                                            }
                                        }) {
                                            PoseCardView(pose: pose, isSelected: pose.fileURL != nil && selectedPoseURLs.contains(pose.fileURL!))
                                        }
                                        .buttonStyle(NoHighlightButtonStyle())
                                    } else {
                                        NavigationLink(value: pose) {
                                            PoseCardView(pose: pose, isSelected: false)
                                        }
                                        .buttonStyle(NoHighlightButtonStyle())
                                        .contextMenu {
                                            if let url = pose.fileURL {
                                                Button(role: .destructive) {
                                                    deletePose(at: url)
                                                } label: {
                                                    Label("Delete Pose", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(0)
                            .padding(.bottom, isSelectionMode ? 100 : 40)
                        }
                    }
                }
                .background(Color.clear)
                .ignoresSafeArea(edges: .bottom)
                .navigationDestination(for: PoseModel.self) { pose in
                    let loadedImage = pose.fileURL != nil ? UIImage(contentsOfFile: pose.fileURL!.path) : UIImage(named: "Pose")
                    DrawingScreen(backgroundImage: loadedImage, sourceURL: pose.fileURL)
                        .navigationBarBackButtonHidden(true)
                }
                
                if isSelectionMode {
                    VStack {
                        Spacer()
                        Button(action: { deleteSelectedPoses() }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete \(selectedPoseURLs.count) Selected")
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedPoseURLs.isEmpty ? Color.gray : Color.red)
                            .cornerRadius(16)
                            .shadow(radius: 5)
                        }
                        .disabled(selectedPoseURLs.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
                
                if let status = loadingStatus {
                    ZStack {
                        Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.black)
                            Text(status)
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
            .animation(.easeInOut(duration: 0.2), value: loadingStatus != nil)
            .alert("New Category", isPresented: $isShowingAddCategory) {
                TextField("Category Name", text: $newCategoryName)
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
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
            .alert("Delete Category", isPresented: $isShowingDeleteAlert, presenting: categoryToDelete) { category in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSavedCategory(category)
                }
            } message: { category in
                Text("Are you sure you want to delete '\(category)'? Any poses saved in this category will still be visible in the 'All' tab.")
            }
            .fullScreenCover(item: $arContext) { context in
                ARBodyScreen(
                    isShowingAR: Binding(
                        get: { arContext != nil },
                        set: { if !$0 { arContext = nil } }
                    ),
                    initialReferenceImage: context.image,
                    modelName: selectedMannequin
                )
                .edgesIgnoringSafeArea(.all)
            }
            .onAppear {
                self.categories = UserDefaults.standard.stringArray(forKey: "SavedCategories") ?? ["Action", "Idle", "Sitting"]
                
                // ONLY hit the hard drive if the app just launched and the array is completely empty!
                if allPoses.isEmpty {
                    reloadPosesAsync(statusText: "Loading Poses...")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CategoriesUpdated"))) { _ in
                self.categories = UserDefaults.standard.stringArray(forKey: "SavedCategories") ?? ["Action", "Idle", "Sitting"]
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshPoseList"))) { _ in
                // FIX: Stop reloading silently! Show the user we are updating the grid.
                reloadPosesAsync(statusText: "Updating Grid...")
                self.categories = UserDefaults.standard.stringArray(forKey: "SavedCategories") ?? ["Action", "Idle", "Sitting"]
            }
        }
    }
}
