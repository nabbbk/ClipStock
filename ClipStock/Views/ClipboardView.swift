import SwiftUI

struct ClipboardView: View {

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipboardItem.clipDate, ascending: false)],
        animation: .default)
    private var clips: FetchedResults<ClipboardItem>

    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(NSLocalizedString("Search clippings...", comment: ""), text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            .padding(.horizontal)
            .padding(.top, 10)

            if filteredClips.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("No clippings yet", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("Copy something to get started.", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // Clips list
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredClips) { clip in
                            ClipboardItemCard(clip: clip)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }

            Divider().padding(.top, 6)

            // Footer
            HStack {
                Text("\(clips.count) " + NSLocalizedString("clippings", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(NSLocalizedString("Clear All", comment: "")) {
                    StorageHelper.shared.clearAllClips()
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private var filteredClips: [ClipboardItem] {
        guard !searchText.isEmpty else { return Array(clips) }
        return clips.filter { clip in
            (clip.clipText ?? "").localizedCaseInsensitiveContains(searchText) ||
            (clip.clipSourceApp ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
}
