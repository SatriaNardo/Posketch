import SwiftUI
import PhotosUI
import PencilKit

extension PosketchMainMenuView {
    func reloadPosesAsync(statusText: String?) {
        loadingStatus = statusText
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = self.loadAllPoses() // Heavy Lifting happens here
            DispatchQueue.main.async {
                self.allPoses = loaded
                self.loadingStatus = nil
            }
        }
    }
    
    func deleteSelectedPoses() {
        loadingStatus = "Deleting Poses..."
        DispatchQueue.global(qos: .userInitiated).async {
            for url in selectedPoseURLs {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: url.appendingPathExtension("pkdrawing"))
            }
            let updatedPoses = self.loadAllPoses()
            DispatchQueue.main.async {
                withAnimation {
                    self.isSelectionMode = false
                    self.selectedPoseURLs.removeAll()
                    self.allPoses = updatedPoses
                }
                self.loadingStatus = nil
            }
        }
    }
    
    func deleteSavedCategory(_ category: String) {
        if let index = categories.firstIndex(of: category) {
            categories.remove(at: index)
            UserDefaults.standard.set(categories, forKey: "SavedCategories")
            NotificationCenter.default.post(name: NSNotification.Name("CategoriesUpdated"), object: nil)
            
            if selectedCategory == category {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.5)) {
                    selectedCategory = "All"
                }
            }
        }
    }
     
    func deletePose(at url: URL) {
        loadingStatus = "Deleting Pose..."
        DispatchQueue.global(qos: .userInitiated).async {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("pkdrawing"))
            let updatedPoses = self.loadAllPoses()
            DispatchQueue.main.async {
                self.allPoses = updatedPoses
                self.loadingStatus = nil
            }
        }
    }
     
    // Retains your exact logic, but is now safely called from the background thread!
    func loadAllPoses() -> [PoseModel] {
        var loaded: [PoseModel] = []
        if let img = UIImage(named: "Pose") {
            loaded.append(PoseModel(poseName: "Starter", category: "Idle", thumbnailImage: img, fileURL: nil, dateAdded: Date(timeIntervalSince1970: 0)))
        }
        
        let folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("PoseImages")
        
        if let urls = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
            for url in urls where url.pathExtension.lowercased() == "png" {
                if let data = try? Data(contentsOf: url), let bgImage = UIImage(data: data) {
                    let filename = url.deletingPathExtension().lastPathComponent
                    let parts = filename.components(separatedBy: "---")
                    var finalThumbnail = bgImage
                    
                    if let drawingData = try? Data(contentsOf: url.appendingPathExtension("pkdrawing")), let drawing = try? PKDrawing(data: drawingData) {
                        let screenBounds = UIScreen.main.bounds
                        let renderer = UIGraphicsImageRenderer(size: screenBounds.size)
                        
                        finalThumbnail = renderer.image { ctx in
                            let scale = min(screenBounds.width / bgImage.size.width, screenBounds.height / bgImage.size.height)
                            let drawW = bgImage.size.width * scale
                            let drawH = bgImage.size.height * scale
                            let drawX = (screenBounds.width - drawW) / 2
                            let drawY = (screenBounds.height - drawH) / 2
                            
                            bgImage.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
                            
                            let traitCollection = UITraitCollection(userInterfaceStyle: .light)
                            traitCollection.performAsCurrent {
                                drawing.image(from: screenBounds, scale: UIScreen.main.scale).draw(in: screenBounds)
                            }
                        }
                    }
                    
                    let memorySafeThumbnail = finalThumbnail.preparingThumbnail(of: CGSize(width: 300, height: 300)) ?? finalThumbnail
                    
                    var parsedDate = Date()
                    if parts.count >= 3, let timestamp = TimeInterval(parts[2]) {
                        parsedDate = Date(timeIntervalSince1970: timestamp)
                    } else if let attr = try? FileManager.default.attributesOfItem(atPath: url.path), let cDate = attr[.creationDate] as? Date {
                        parsedDate = cDate
                    }
                    
                    if parts.count >= 3 {
                        loaded.append(PoseModel(poseName: parts[1], category: parts[0], thumbnailImage: memorySafeThumbnail, fileURL: url, dateAdded: parsedDate))
                    } else {
                        loaded.append(PoseModel(poseName: "Saved Pose", category: "Uncategorized", thumbnailImage: memorySafeThumbnail, fileURL: url, dateAdded: parsedDate))
                    }
                }
            }
        }
        return loaded
    }
}
