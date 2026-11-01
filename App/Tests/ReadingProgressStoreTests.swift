import Foundation
import XCTest
@testable import VoiceReaderApp

final class ReadingProgressStoreTests: XCTestCase {
    func testInvalidStoredCoordinatesResetToZero() throws {
        let suiteName = "test.reading.invalid.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ReadingProgressStore(defaults: defaults)
        let bookID = UUID()
        for (paragraph, offset) in [(-1, 0), (0, -1), (Int.min, Int.min)] {
            let invalid = ReadingPosition(paragraphIndex: paragraph, offsetInParagraph: offset, updatedAt: Date())
            // Write encoded legacy/corrupt data directly, bypassing save validation.
            defaults.set(try JSONEncoder().encode(invalid), forKey: "reading.position.\(bookID.uuidString)")
            let actual = store.loadPosition(for: bookID)
            XCTAssertEqual(actual.paragraphIndex, 0)
            XCTAssertEqual(actual.offsetInParagraph, 0)
        }
    }

    func testSaveAndLoadPosition() {
        let suiteName = "test.reading.progress.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create test defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReadingProgressStore(defaults: defaults)
        let bookID = UUID()
        let expected = ReadingPosition(paragraphIndex: 12, offsetInParagraph: 4, updatedAt: Date())

        store.savePosition(expected, for: bookID)

        let actual = store.loadPosition(for: bookID)
        XCTAssertEqual(actual.paragraphIndex, expected.paragraphIndex)
        XCTAssertEqual(actual.offsetInParagraph, expected.offsetInParagraph)
    }
}
