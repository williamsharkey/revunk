import Foundation

public enum RevunkFormat {
    public static func format(text: String) -> String {
        // For now, formatting is identity; parser-normalized formatting can be added later
        return text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}
