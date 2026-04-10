import SwiftUI

struct SearchFieldView: View {

    @Binding var searchText: String
    @State private var isExpanded = false

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
    }
}
