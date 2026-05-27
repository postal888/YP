import Foundation

extension String {
    var rangeOfTranslationSeparator: Range<String.Index>? {
        let separators = [" — ", " – ", " - "]
        for separator in separators {
            if let range = range(of: separator) {
                return range
            }
        }
        return nil
    }
}
