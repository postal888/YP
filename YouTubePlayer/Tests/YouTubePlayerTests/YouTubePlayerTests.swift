import Foundation
@testable import YouTubePlayer
import XCTest

final class YouTubePlayerConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let config = YouTubePlayerConfiguration(videoID: "abc123")

        XCTAssertEqual(config.videoID, "abc123")
        XCTAssertFalse(config.autoplay)
        XCTAssertEqual(config.startTime, 0)
        XCTAssertTrue(config.showControls)
    }
}

final class YouTubeVideoIDExtractorTests: XCTestCase {
    func testExtractFromPlainID() {
        XCTAssertEqual(YouTubeVideoIDExtractor.extract(from: "dQw4w9WgXcQ"), "dQw4w9WgXcQ")
    }

    func testExtractFromWatchURL() {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        XCTAssertEqual(YouTubeVideoIDExtractor.extract(from: url), "dQw4w9WgXcQ")
    }
}

final class YouTubeTranscriptParserTests: XCTestCase {
    func testParseTranscriptXML() {
        let xml = """
        <transcript>
          <text start="1.2" dur="2.0">Olá</text>
          <text start="3.5" dur="1.5">mundo</text>
        </transcript>
        """
        let segments = YouTubeTranscriptParser.parseCaptionPayload(xml)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].text, "Olá")
        XCTAssertEqual(segments[0].offset, 1.2, accuracy: 0.001)
    }

    func testMergeSegmentsIntoLines() {
        let segments = [
            YouTubeTranscriptSegment(text: "Olá,", offset: 0, duration: 1),
            YouTubeTranscriptSegment(text: "como você está?", offset: 1, duration: 2)
        ]
        let lines = YouTubeTranscriptParser.mergeSegmentsIntoLines(segments)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Olá, como você está?")
    }

    func testSubtitleTone() {
        let line = YouTubeSubtitleLine(id: "1", text: "Test", startSec: 5, endSec: 8)
        XCTAssertEqual(youtubeSubtitleTone(for: line, playbackSec: 3), .future)
        XCTAssertEqual(youtubeSubtitleTone(for: line, playbackSec: 6), .current)
        XCTAssertEqual(youtubeSubtitleTone(for: line, playbackSec: 9), .spoken)
    }
}
