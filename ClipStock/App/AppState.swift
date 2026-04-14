import SwiftUI
import Combine

enum KeyAction {
    case focusSearch
    case addItem
    case deleteSelected
    case copySelected
    case navigateUp
    case navigateDown
    case navigateUpExtend
    case navigateDownExtend
    case editItem
    case addDeadline
    case removeDeadline
    case saveToStock
    case copyIndex(Int)
    case copyPlainText
    case togglePin
}

class AppState: ObservableObject {
    static let shared = AppState()
    @Published var selectedTab: AppTab = .stock
    let keyAction = PassthroughSubject<KeyAction, Never>()
}
