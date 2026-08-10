import SwiftUI
import UIKit

enum ImmersiveUIMetrics {
    static let pageHorizontalPadding: CGFloat = 20
    static let topControlVisualSize: CGFloat = 26
    static let topControlHitSize: CGFloat = 44
    static let edgeSwipeHitWidth: CGFloat = 28
    static let edgeSwipeDismissDistance: CGFloat = 96
}

struct ImmersiveBackdrop: View {
    let url: URL?
    let overlayOpacity: Double
    let blurRadius: CGFloat

    init(url: URL?, overlayOpacity: Double, blurRadius: CGFloat = 52) {
        self.url = url
        self.overlayOpacity = overlayOpacity
        self.blurRadius = blurRadius
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                    default: Color(uiColor: .systemBackground)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .scaleEffect(1.18)
                .blur(radius: blurRadius)
                Color(uiColor: .systemBackground).opacity(overlayOpacity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

private struct InteractiveEdgeBackModifier: ViewModifier {
    let onDismiss: () -> Void
    @State private var dragOffset: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.black.opacity(min(0.16, Double(dragOffset / max(1, geometry.size.width)) * 0.16)).ignoresSafeArea()
                content
                    .offset(x: dragOffset)
                    .shadow(color: dragOffset > 0 ? Color.black.opacity(0.18) : .clear, radius: 12, x: -6, y: 0)
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: ImmersiveUIMetrics.edgeSwipeHitWidth)
                    .frame(maxHeight: .infinity)
                    .gesture(
                        DragGesture(minimumDistance: 4, coordinateSpace: .local)
                            .onChanged { value in
                                guard value.translation.width > 0 else { return }
                                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                dragOffset = min(geometry.size.width, value.translation.width)
                            }
                            .onEnded { value in
                                let shouldDismiss = dragOffset >= ImmersiveUIMetrics.edgeSwipeDismissDistance || value.predictedEndTranslation.width >= geometry.size.width * 0.42
                                if shouldDismiss {
                                    withAnimation(.easeOut(duration: 0.16)) { dragOffset = geometry.size.width }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { onDismiss() }
                                } else {
                                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.88, blendDuration: 0.08)) { dragOffset = 0 }
                                }
                            }
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

extension View {
    func interactiveEdgeBack(_ onDismiss: @escaping () -> Void) -> some View {
        modifier(InteractiveEdgeBackModifier(onDismiss: onDismiss))
    }
}

enum DetailHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
