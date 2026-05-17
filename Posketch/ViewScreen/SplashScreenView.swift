import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 0.7
    @State private var opacity = 0.4
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if isActive {
            PosketchMainMenuView()
        } else {
            ZStack {
                (colorScheme == .dark ? Color(UIColor.systemGray6) : Color(white: 1))
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // The core custom icon without the circular covers
                    Image("SplashIcon")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.primary)
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.2)) {
                        self.size = 1.0
                        self.opacity = 1.0
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
