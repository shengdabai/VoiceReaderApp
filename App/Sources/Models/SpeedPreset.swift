import Foundation

enum SpeedPreset: String, CaseIterable, Codable, Identifiable {
    case x0_5 = "0.5x"
    case x0_75 = "0.75x"
    case x1_0 = "1.0x"
    case x1_25 = "1.25x"
    case x1_5 = "1.5x"
    case x2_0 = "2.0x"
    case x2_5 = "2.5x"
    case x3_0 = "3.0x"

    var id: String { rawValue }

    var value: Float {
        switch self {
        case .x0_5: return 0.5
        case .x0_75: return 0.75
        case .x1_0: return 1.0
        case .x1_25: return 1.25
        case .x1_5: return 1.5
        case .x2_0: return 2.0
        case .x2_5: return 2.5
        case .x3_0: return 3.0
        }
    }
}
