import XCTest
@testable import VoiceReaderApp

final class SpeedPresetTests: XCTestCase {
    func testSpeedPresetValues() {
        XCTAssertEqual(SpeedPreset.x0_5.value, 0.5)
        XCTAssertEqual(SpeedPreset.x1_0.value, 1.0)
        XCTAssertEqual(SpeedPreset.x3_0.value, 3.0)
    }

    func testFixedPresetCount() {
        XCTAssertEqual(SpeedPreset.allCases.count, 8)
    }
}
