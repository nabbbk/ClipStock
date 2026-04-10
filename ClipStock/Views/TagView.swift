import SwiftUI

struct TagView: View {

    let tagContent: String
    var textFont: Font = .caption

    private var tags: [String] {
        tagContent.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(textFont)
                    .foregroundColor(.blue)
            }
        }
    }
}
