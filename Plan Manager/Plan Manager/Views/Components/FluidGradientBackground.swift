import SwiftUI

struct FluidGradientBackground: View {
    // Top-Left, Top-Right, Bottom-Left, Bottom-Right
    let colors: [Color]

    init(colors: [Color] = [Color(hex: "5DADE2"), Color(hex: "8BC6FF"), Color(hex: "66D9E8"), Color(hex: "EAF6FF")]) {
        self.colors = colors
    }

    var body: some View {
        ZStack {
            // Base Background
            colors[0].opacity(0.3).ignoresSafeArea()

            // Floating Blobs
            GeometryReader { proxy in
                ZStack {
                    // Blob 1
                    Circle()
                        .fill(colors[0].opacity(0.4))
                        .frame(width: proxy.size.width * 0.8)
                        .blur(radius: 42)
                        .offset(x: 26, y: 22)

                    // Blob 2
                    Circle()
                        .fill(colors[1].opacity(0.4))
                        .frame(width: proxy.size.width * 0.7)
                        .blur(radius: 42)
                        .offset(x: -44, y: 190)

                    // Blob 3
                    Circle()
                        .fill(colors[2].opacity(0.4))
                        .frame(width: proxy.size.width * 0.9)
                        .blur(radius: 42)
                        .offset(x: 130, y: -42)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Glass Overlay
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.3))
                .ignoresSafeArea()
        }
    }
}
