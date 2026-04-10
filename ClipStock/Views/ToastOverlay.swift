import SwiftUI

class ToastState: ObservableObject {
    static let shared = ToastState()
    @Published var isShowing = false
    @Published var message = ""

    func show(_ message: String) {
        self.message = message
        withAnimation(.easeIn(duration: 0.15)) {
            isShowing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.isShowing = false
            }
        }
    }
}

struct ToastOverlay: ViewModifier {
    @ObservedObject var toast = ToastState.shared

    func body(content: Content) -> some View {
        ZStack {
            content
            if toast.isShowing {
                Text(toast.message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.75))
                            .shadow(radius: 4)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(999)
            }
        }
    }
}

extension View {
    func withToastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
