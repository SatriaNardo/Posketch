import SwiftUI

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct PoseCardView: View {
    let pose: PoseModel
    var isSelected: Bool = false
    @Environment(\.colorScheme) var colorScheme
     
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.white
                if let img = pose.thumbnailImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                        Text("No Image")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.gray)
                }
            }
            .clipped()
             
            Text(pose.poseName)
                .font(.custom("Noteworthy-Bold", size: 14))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? Color(white: 0.22) : Color.black)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.75, contentMode: .fit)
        .border(Color.primary.opacity(0.8), width: 2)
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: isSelected ? 4 : 0)
        )
        .overlay(
            ZStack {
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                                .background(Circle().fill(Color.white))
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
        )
        .shadow(color: isSelected ? Color.black.opacity(0.4) : Color.clear, radius: isSelected ? 4 : 0, x: 0, y: isSelected ? 2 : 0)
        .zIndex(isSelected ? 1 : 0)
    }
}

struct GlassButton: View {
    var title: String
    var icon: String
    var tint: Color
    var hasOutline: Bool = false
    var blurStyle: SwiftUI.Material = .ultraThinMaterial
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GlassButtonView(title: title, icon: icon, tint: tint, hasOutline: hasOutline, blurStyle: blurStyle)
        }
    }
}

struct GlassButtonView: View {
    var title: String
    var icon: String
    var tint: Color
    var hasOutline: Bool = false
    var blurStyle: SwiftUI.Material = .ultraThinMaterial
    
    var body: some View {
        HStack(spacing: 5) { // Tighter icon-to-text spacing
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(tint)
            
            Text(title)
                .font(.custom("Noteworthy-Bold", size: 14))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1) // Force text to stay on one line
                .fixedSize(horizontal: true, vertical: false) // Prevent horizontal squishing
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 17)
        .background(blurStyle, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
        .environment(\.colorScheme, .dark)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var onComplete: (() -> Void)?
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // This listens to what the user did with the share menu
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            // Only trigger the completion if they actually successfully shared it
            if completed {
                onComplete?()
            }
        }
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SideControlButton: View {
    var icon: String
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 54, height: 54)
            .overlay(
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            )
            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
    }
}
