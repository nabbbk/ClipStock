import Foundation

extension String {
    func truncated(to count: Int) -> String {
        if self.count <= count { return self }
        return String(prefix(count)) + "..."
    }
}
