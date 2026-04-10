import SwiftUI

struct TagView: View {

    let tagContent: String
    var textFont: Font = .caption
    var textPadding: CGFloat = 4

    var body: some View {
        Text(tagContent)
            .font(textFont)
            .foregroundColor(.white)
            .padding(.horizontal, textPadding + 2)
            .padding(.vertical, textPadding)
            .background(RoundedRectangle(cornerRadius: 5).fill(.blue))
    }
}
