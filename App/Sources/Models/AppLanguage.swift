import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case zhHans = "zh-CN"
    case enUS = "en-US"
    case deDE = "de-DE"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhHans:
            return "中文"
        case .enUS:
            return "English"
        case .deDE:
            return "Deutsch"
        }
    }
}
