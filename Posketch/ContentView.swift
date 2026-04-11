import SwiftUI

// 1. The Bridge: This tells SwiftUI how to display your ARBodyViewController
struct ARViewContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ARBodyViewController {
        return ARBodyViewController()
    }
    
    func updateUIViewController(_ uiViewController: ARBodyViewController, context: Context) {}
}

// 2. The Main Screen
struct ContentView: View {
    // This state controls whether we show the menu or the AR camera
    @State private var isPosing = false
    
    var body: some View {
        if isPosing {
            // Show the AR Camera View
            ARViewContainer()
                .ignoresSafeArea()
        } else {
            // Show the Home Menu
            VStack {
                Spacer()
                
                Text("Posketch")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("3D Pose Reference")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    // This triggers the screen switch
                    isPosing = true
                }) {
                    Text("Start Posing")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    ContentView()
}
