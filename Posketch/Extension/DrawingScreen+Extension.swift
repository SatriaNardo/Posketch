import SwiftUI
import PencilKit

extension DrawingScreen {
    func createExportImage() -> UIImage? {
        guard let bgImage = backgroundImage else { return nil }
        let drawing = drawingManager.canvasView.drawing
        let screenBounds = UIScreen.main.bounds
            
        let scale = min(screenBounds.width / bgImage.size.width, screenBounds.height / bgImage.size.height)
        let drawW = bgImage.size.width * scale
        let drawH = bgImage.size.height * scale
        let drawX = (screenBounds.width - drawW) / 2
        let drawY = (screenBounds.height - drawH) / 2
            
        let exportSize = CGSize(width: drawW, height: drawH)
        let renderer = UIGraphicsImageRenderer(size: exportSize)
            
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: exportSize))
            bgImage.draw(in: CGRect(origin: .zero, size: exportSize))
            
            let traitCollection = UITraitCollection(userInterfaceStyle: .light)
            traitCollection.performAsCurrent {
                let strokeImage = drawing.image(from: screenBounds, scale: UIScreen.main.scale)
                strokeImage.draw(in: CGRect(x: -drawX, y: -drawY, width: screenBounds.width, height: screenBounds.height))
            }
        }
    }
        
    func processAutoSave() {
        // Show the loading screen instantly
        loadingMessage = "Updating File..."
        
        // 1. Capture the UI data on the main thread FIRST
        guard let bgImage = backgroundImage, let url = currentSourceURL else {
            loadingMessage = nil
            return
        }
        let drawingData = drawingManager.canvasView.drawing.dataRepresentation()
        
        // 2. Push the heavy data conversion and hard drive writing to the Background!
        DispatchQueue.global(qos: .userInitiated).async {
            let bgData = bgImage.pngData()
            
            if let finalBgData = bgData {
                try? finalBgData.write(to: url)
                try? drawingData.write(to: url.appendingPathExtension("pkdrawing"))
            }
            
            // 3. Jump back to the main thread to close the screen
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshPoseList"), object: nil)
                self.loadingMessage = nil
                if let returnToMenu = self.onSaveComplete { returnToMenu() } else { self.dismiss() }
            }
        }
    }
    
    func processSave() {
        showSaveDialog = false
        loadingMessage = "Saving Pose..."
            
        // Yield thread so the loading screen appears immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let bgData = backgroundImage?.pngData() else {
                loadingMessage = nil
                return
            }
            let drawingData = drawingManager.canvasView.drawing.dataRepresentation()
            
            if let url = currentSourceURL {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: url.appendingPathExtension("pkdrawing"))
            }
            
            let finalName = poseName.isEmpty ? "Untitled" : poseName
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("PoseImages")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            
            let filename = "\(selectedCategory.replacingOccurrences(of: "---", with: "-"))---\(finalName.replacingOccurrences(of: "---", with: "-"))---\(Int(Date().timeIntervalSince1970)).png"
            let imageURL = folder.appendingPathComponent(filename)
            
            try? bgData.write(to: imageURL)
            try? drawingData.write(to: imageURL.appendingPathExtension("pkdrawing"))
                
            currentSourceURL = imageURL
            NotificationCenter.default.post(name: NSNotification.Name("RefreshPoseList"), object: nil)
            
            if pendingExport {
                loadingMessage = "Preparing Image..."
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let img = createExportImage() {
                        exportedImageToShare = img
                        isShowingShareSheet = true
                    }
                    loadingMessage = nil
                    pendingExport = false
                }
            } else {
                loadingMessage = nil
                if let returnToMenu = onSaveComplete { returnToMenu() } else { dismiss() }
            }
        }
    }
}
