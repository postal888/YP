import Foundation

enum YouTubeTranscriptParser {
    static func parseCaptionPayload(_ raw: String) -> [YouTubeTranscriptSegment] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            if trimmed.hasPrefix("{") {
                let json3 = parseJson3Transcript(trimmed)
                if !json3.isEmpty { return json3 }
            }

            if let data = trimmed.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let mapped = array.compactMap(parseDictionarySegment)
                if !mapped.isEmpty { return mapped }
            }
        }

        if trimmed.contains("<p") && trimmed.contains("t=\"") {
            let srv3 = parseSrv3TranscriptXML(trimmed)
            if !srv3.isEmpty { return srv3 }
        }

        if trimmed.contains("<text") {
            return parseTranscriptXML(trimmed)
        }

        if trimmed.contains("WEBVTT") || trimmed.contains("-->") {
            return parseVTT(trimmed)
        }

        return []
    }

    static func parseJson3Transcript(_ raw: String) -> [YouTubeTranscriptSegment] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            return []
        }

        var out: [YouTubeTranscriptSegment] = []
        for event in events {
            guard let segs = event["segs"] as? [[String: Any]], !segs.isEmpty else { continue }
            let text = segs
                .compactMap { $0["utf8"] as? String }
                .joined()
                .replacingOccurrences(of: "\u{0000}", with: "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty, text != "\n" else { continue }

            let startMs = (event["tStartMs"] as? NSNumber)?.doubleValue ?? 0
            let durationMs = (event["dDurationMs"] as? NSNumber)?.doubleValue ?? 500
            let times = normalizeSegmentTimes(offset: startMs, duration: durationMs)
            out.append(YouTubeTranscriptSegment(text: text, offset: times.offset, duration: times.duration))
        }
        return out
    }

    static func parseSrv3TranscriptXML(_ xml: String) -> [YouTubeTranscriptSegment] {
        guard let regex = try? NSRegularExpression(pattern: #"<p\s+t="(\d+)"\s+d="(\d+)"[^>]*>([\s\S]*?)<\/p>"#) else {
            return []
        }

        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        let matches = regex.matches(in: xml, range: range)
        var out: [YouTubeTranscriptSegment] = []

        for match in matches {
            guard let startRange = Range(match.range(at: 1), in: xml),
                  let durationRange = Range(match.range(at: 2), in: xml),
                  let innerRange = Range(match.range(at: 3), in: xml) else {
                continue
            }

            let startMs = Double(xml[startRange]) ?? 0
            let durationMs = Double(xml[durationRange]) ?? 500
            let inner = String(xml[innerRange])
            let text = extractSrv3Text(from: inner)
            guard !text.isEmpty else { continue }

            let times = normalizeSegmentTimes(offset: startMs, duration: durationMs)
            out.append(YouTubeTranscriptSegment(text: text, offset: times.offset, duration: times.duration))
        }

        return out
    }

    static func parseTranscriptXML(_ xml: String) -> [YouTubeTranscriptSegment] {
        guard let regex = try? NSRegularExpression(pattern: #"<text[^>]*start="([^"]+)"[^>]*dur="([^"]+)"[^>]*>([\s\S]*?)<\/text>"#) else {
            return []
        }

        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        let matches = regex.matches(in: xml, range: range)
        var out: [YouTubeTranscriptSegment] = []

        for match in matches {
            guard let startRange = Range(match.range(at: 1), in: xml),
                  let durationRange = Range(match.range(at: 2), in: xml),
                  let textRange = Range(match.range(at: 3), in: xml) else {
                continue
            }

            let start = Double(xml[startRange]) ?? 0
            let duration = Double(xml[durationRange]) ?? 0
            let text = decodeHTMLEntities(String(xml[textRange]))
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }
            out.append(YouTubeTranscriptSegment(text: text, offset: start, duration: duration))
        }

        return out
    }

    static func parseVTT(_ vtt: String) -> [YouTubeTranscriptSegment] {
        let lines = vtt.components(separatedBy: .newlines)
        var out: [YouTubeTranscriptSegment] = []
        var index = 0

        while index < lines.count {
            let row = lines[index].trimmingCharacters(in: .whitespaces)
            guard row.contains("-->") else {
                index += 1
                continue
            }

            let parts = row.components(separatedBy: "-->")
            let startStamp = parts.first?.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""
            let endStamp = parts.dropFirst().first?.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""
            let start = timestampToSeconds(startStamp.replacingOccurrences(of: ",", with: "."))
            let end = timestampToSeconds(endStamp.replacingOccurrences(of: ",", with: "."))

            index += 1
            var cue: [String] = []
            while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                let cleaned = lines[index]
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    cue.append(cleaned)
                }
                index += 1
            }

            let text = cue.joined(separator: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                out.append(
                    YouTubeTranscriptSegment(
                        text: text,
                        offset: start,
                        duration: max(0.05, end - start)
                    )
                )
            }
        }

        return out
    }

    static func mergeSegmentsIntoLines(_ segments: [YouTubeTranscriptSegment]) -> [YouTubeSubtitleLine] {
        var out: [YouTubeSubtitleLine] = []
        var buffer: [(text: String, offset: Double, duration: Double)] = []

        func lineLength() -> Int {
            buffer.map(\.text).joined(separator: " ").count
        }

        func flush() {
            guard !buffer.isEmpty else { return }
            let text = buffer.map(\.text).joined(separator: " ")
            let startSec = buffer[0].offset
            var endSec = buffer[buffer.count - 1].offset + buffer[buffer.count - 1].duration
            if endSec <= startSec {
                endSec = startSec + 0.3
            }
            out.append(
                YouTubeSubtitleLine(
                    id: "line-\(out.count + 1)",
                    text: text,
                    startSec: startSec,
                    endSec: endSec
                )
            )
            buffer.removeAll(keepingCapacity: true)
        }

        for segment in segments {
            let text = segment.text
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }
            if text.range(of: #"^[\[\]♪\s]+$"#, options: .regularExpression) != nil { continue }

            let times = normalizeSegmentTimes(offset: segment.offset, duration: segment.duration)
            buffer.append((text: text, offset: times.offset, duration: times.duration))

            if text.range(of: #"[.!?…:;]\s*$"#, options: .regularExpression) != nil || lineLength() > 220 {
                flush()
            }
        }

        flush()
        return out
    }

    private static func parseDictionarySegment(_ segment: [String: Any]) -> YouTubeTranscriptSegment? {
        let text = (segment["text"] as? String ?? "")
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let offsetValue = segment["offset"] ?? segment["start"] ?? 0
        let durationValue = segment["duration"] ?? segment["dur"] ?? 0.5
        let offset = (offsetValue as? NSNumber)?.doubleValue ?? Double("\(offsetValue)") ?? 0
        let duration = (durationValue as? NSNumber)?.doubleValue ?? Double("\(durationValue)") ?? 0.5
        let times = normalizeSegmentTimes(offset: offset, duration: duration)
        return YouTubeTranscriptSegment(text: text, offset: times.offset, duration: times.duration)
    }

    private static func extractSrv3Text(from inner: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"<s[^>]*>([^<]*)<\/s>"#) else {
            return decodeHTMLEntities(inner.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let range = NSRange(inner.startIndex..<inner.endIndex, in: inner)
        let matches = regex.matches(in: inner, range: range)
        var text = matches.compactMap { match -> String? in
            guard let textRange = Range(match.range(at: 1), in: inner) else { return nil }
            return String(inner[textRange])
        }.joined()

        if text.isEmpty {
            text = inner.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }

        return decodeHTMLEntities(text)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeSegmentTimes(offset: Double, duration: Double) -> (offset: Double, duration: Double) {
        var normalizedOffset = offset.isFinite ? offset : 0
        var normalizedDuration = duration.isFinite && duration > 0 ? duration : 0.5

        let offsetIsInteger = normalizedOffset.rounded() == normalizedOffset
        let durationIsInteger = normalizedDuration.rounded() == normalizedDuration
        if offsetIsInteger, durationIsInteger {
            let intOffset = Int(normalizedOffset)
            let intDuration = Int(normalizedDuration)
            if intDuration >= 100 || intOffset > 45_000 || intOffset + intDuration > 120_000 {
                normalizedOffset = Double(intOffset) / 1000
                normalizedDuration = max(0.05, Double(intDuration) / 1000)
                return (normalizedOffset, normalizedDuration)
            }
        }

        if normalizedOffset > 1_000_000 { normalizedOffset /= 1000 }
        if normalizedDuration > 1_000_000 { normalizedDuration /= 1000 }
        if normalizedOffset > 100_000 { normalizedOffset /= 1000 }
        if normalizedDuration > 100_000 { normalizedDuration /= 1000 }

        if normalizedOffset > 500 || normalizedDuration > 100 {
            normalizedOffset /= 1000
            normalizedDuration /= 1000
        }

        return (normalizedOffset, max(0.05, normalizedDuration))
    }

    private static func decodeHTMLEntities(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private static func timestampToSeconds(_ stamp: String) -> Double {
        let parts = stamp.split(separator: ":").map(String.init)
        guard parts.count >= 2 else { return 0 }

        if parts.count == 3 {
            let hours = Double(parts[0]) ?? 0
            let minutes = Double(parts[1]) ?? 0
            let seconds = Double(parts[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        }

        let minutes = Double(parts[0]) ?? 0
        let seconds = Double(parts[1]) ?? 0
        return minutes * 60 + seconds
    }
}
