import Foundation

enum SubtitleToken: Identifiable, Equatable {
    case literal(String)
    case word(id: String, display: String, lookupKey: String)

    var id: String {
        switch self {
        case .literal(let text):
            return "lit-\(text.hashValue)"
        case .word(let id, _, _):
            return id
        }
    }
}

enum SubtitleWordTokenizer {
    private static let punctuationCharacters: CharacterSet = {
        var set = CharacterSet(charactersIn: ".,!?;:—–-")
        return set
    }()

    static func tokenize(_ text: String, lineID: String) -> [SubtitleToken] {
        guard !text.isEmpty else { return [] }

        var tokens: [SubtitleToken] = []
        var wordIndex = 0
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character.isWhitespace {
                let start = index
                while index < text.endIndex, text[index].isWhitespace {
                    index = text.index(after: index)
                }
                tokens.append(.literal(String(text[start..<index])))
                continue
            }

            if let scalar = character.unicodeScalars.first,
               punctuationCharacters.contains(scalar) {
                tokens.append(.literal(String(character)))
                index = text.index(after: index)
                continue
            }

            let start = index
            while index < text.endIndex {
                let current = text[index]
                if current.isWhitespace { break }
                if let scalar = current.unicodeScalars.first,
                   punctuationCharacters.contains(scalar) {
                    break
                }
                index = text.index(after: index)
            }

            let chunk = String(text[start..<index])
            let lookupKey = stripWordPunctuation(chunk)
            if lookupKey.count >= 2 {
                wordIndex += 1
                tokens.append(
                    .word(
                        id: "\(lineID)-w\(wordIndex)",
                        display: chunk,
                        lookupKey: lookupKey
                    )
                )
            } else {
                tokens.append(.literal(chunk))
            }
        }

        return tokens
    }

    static func stripWordPunctuation(_ chunk: String) -> String {
        chunk.unicodeScalars
            .filter { scalar in
                CharacterSet.letters.contains(scalar)
                    || CharacterSet.decimalDigits.contains(scalar)
                    || scalar == "'"
            }
            .map(String.init)
            .joined()
    }
}
