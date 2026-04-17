import Foundation
import XCTest
@testable import VoiceReaderApp

final class ReadingProgressStoreTests: XCTestCase {
    func testSaveAndLoadPosition() {
        let suiteName = "test.reading.progress.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create test defaults")
            return
        }

        let store = ReadingProgressStore(defaults: defaults)
        let bookID = UUID()
        let expected = ReadingPosition(paragraphIndex: 12, offsetInParagraph: 4, updatedAt: Date())

        store.savePosition(expected, for: bookID)

        let actual = store.loadPosition(for: bookID)
        XCTAssertEqual(actual.paragraphIndex, expected.paragraphIndex)
        XCTAssertEqual(actual.offsetInParagraph, expected.offsetInParagraph)
    }
}
