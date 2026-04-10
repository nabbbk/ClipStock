import SwiftUI

struct SearchFieldView: View {

    @Binding var searchText: String
    @Binding var triggerFocus: Bool
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .frame(height: 40)
                .foregroundColor(Color(NSColor.controlBackgroundColor))

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(NSColor.labelColor))

                if isExpanded {
                    TextField(
                        NSLocalizedString("Search...", comment: ""),
                        text: $searchText
                    )
                    .textFieldStyle(.plain)
                    .focused($isFocused)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            isExpanded = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onChange(of: triggerFocus) { newValue in
            if newValue {
                isExpanded = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isFocused = true
                }
                triggerFocus = false
            }
        }
    }
}
