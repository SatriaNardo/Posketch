import RealityKit
import ARKit
import Combine
import SwiftUI

extension ARBodyScreen {
    nonisolated func cropRobotCenteredBackground(from img: UIImage) async -> UIImage {
        guard let cg = img.cgImage else { return img }
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 4*w, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return img }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let buf = ctx.data!.bindMemory(to: UInt8.self, capacity: w*h*4)
        var minX = w, maxX = 0, minY = h, maxY = 0
        for y in 0..<h {
            for x in 0..<w {
                let i = (y*w+x)*4
                if buf[i] < 180 {
                    minX = min(x, minX); maxX = max(x, maxX); minY = min(y, minY); maxY = max(y, maxY);
                    buf[i] = 0; buf[i+1] = 0; buf[i+2] = 0
                }
                else { buf[i] = 255; buf[i+1] = 255; buf[i+2] = 255 }
            }
        }
        guard minX < maxX, let processedCG = ctx.makeImage() else { return img }
        let cropRect = CGRect(x: max(0, minX - 40), y: max(0, minY - 40), width: min(w, maxX + 40) - max(0, minX - 40), height: min(h, maxY + 40) - max(0, minY - 40))
        guard let croppedCG = processedCG.cropping(to: cropRect) else { return img }
        let croppedUI = UIImage(cgImage: croppedCG)
        let canvasSize = CGSize(width: 1024, height: 1024)
        return await MainActor.run {
            return UIGraphicsImageRenderer(size: canvasSize).image { c in
                UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: canvasSize))
                let limit = canvasSize.width * 0.90
                let scale = min(limit / croppedUI.size.width, limit / croppedUI.size.height)
                let drawW = croppedUI.size.width * scale, drawH = croppedUI.size.height * scale
                let drawX = (canvasSize.width - drawW) / 2, drawY = (canvasSize.height - drawH) / 2
                croppedUI.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
            }
        }
    }
}
