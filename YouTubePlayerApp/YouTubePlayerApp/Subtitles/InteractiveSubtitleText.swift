import SwiftUI
import UIKit

struct ActiveSubtitleWord: Equatable {
    let lookupKey: String
    let display: String
}

@MainActor
struct InteractiveSubtitleText: View {
    let text: String
    let lineID: String
    let sourceLanguage: String
    let translatedKeys: Set<String>
    let interactionToken: Int
    @Binding var activeWord: ActiveSubtitleWord?
    @Binding var translationPreview: String?
    @Binding var isTranslating: Bool
    let onTranslationError: (String) -> Void

    @EnvironmentObject private var appSettings: AppSettings

    var body: some View {
        TappableSubtitleTextRepresentable(
            text: text,
            lineID: lineID,
            sourceLanguage: sourceLanguage,
            translatedKeys: translatedKeys,
            useChatGPT: appSettings.useChatGPTTranslation,
            backendBaseURL: appSettings.normalizedBackendURL,
            activeWord: $activeWord,
            translationPreview: $translationPreview,
            isTranslating: $isTranslating,
            onTranslationError: onTranslationError
        )
        .id("\(lineID)-\(interactionToken)")
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct TappableSubtitleTextRepresentable: UIViewRepresentable {
    let text: String
    let lineID: String
    let sourceLanguage: String
    let translatedKeys: Set<String>
    let useChatGPT: Bool
    let backendBaseURL: String
    @Binding var activeWord: ActiveSubtitleWord?
    @Binding var translationPreview: String?
    @Binding var isTranslating: Bool
    let onTranslationError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> TappableSubtitleTextView {
        let view = TappableSubtitleTextView()
        view.delegate = context.coordinator
        view.onLinkHover = { url, interaction in
            context.coordinator.handleLink(url, interaction: interaction)
        }
        view.onLinkTap = { url in
            context.coordinator.handleLink(url, interaction: .invokeDefaultAction)
        }
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.isEditable = false
        view.isScrollEnabled = false
        view.isSelectable = true
        view.isUserInteractionEnabled = true
        view.dataDetectorTypes = []
        view.linkTextAttributes = [:]
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateContent(in: view)
        return view
    }

    func updateUIView(_ uiView: TappableSubtitleTextView, context: Context) {
        context.coordinator.parent = self
        uiView.isUserInteractionEnabled = true
        uiView.isSelectable = true
        uiView.onLinkHover = { url, _ in
            context.coordinator.handleLink(url, interaction: .preview)
        }
        uiView.onLinkTap = { url in
            context.coordinator.handleLink(url, interaction: .invokeDefaultAction)
        }
        updateContent(in: uiView)
    }

    private func updateContent(in textView: TappableSubtitleTextView) {
        let tokens = SubtitleWordTokenizer.tokenize(text, lineID: lineID)
        let attributed = NSMutableAttributedString()
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let baseColor = UIColor(red: 0.898, green: 0.906, blue: 0.922, alpha: 0.95)

        for token in tokens {
            switch token {
            case .literal(let literal):
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: baseColor
                ]
                attributed.append(NSAttributedString(string: literal, attributes: attrs))

            case .word(_, let display, let lookupKey):
                let known = translatedKeys.contains(lookupKey.lowercased())
                let active = activeWord?.lookupKey.caseInsensitiveCompare(lookupKey) == .orderedSame
                var attrs: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: baseColor,
                    .link: wordURL(for: lookupKey, display: display)
                ]
                if known {
                    attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    attrs[.underlineColor] = UIColor.systemGreen
                }
                if active {
                    attrs[.backgroundColor] = UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 0.22)
                }
                attributed.append(NSAttributedString(string: display, attributes: attrs))
            }
        }

        textView.attributedText = attributed
    }

    private func wordURL(for lookupKey: String, display: String) -> URL {
        var components = URLComponents()
        components.scheme = "subtitleword"
        components.host = lookupKey.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        components.queryItems = [
            URLQueryItem(
                name: "display",
                value: display.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            )
        ]
        return components.url ?? URL(string: "subtitleword://\(lookupKey)")!
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TappableSubtitleTextRepresentable
        private var lastHandledLinkAt: Date = .distantPast
        private var translationTask: Task<Void, Never>?

        init(parent: TappableSubtitleTextRepresentable) {
            self.parent = parent
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            handleLink(URL, interaction: interaction)
            return false
        }

        func handleLink(_ url: URL, interaction: UITextItemInteraction) {
            guard url.scheme == "subtitleword", let lookupKey = url.host?.removingPercentEncoding else {
                return
            }

            let now = Date()
            guard now.timeIntervalSince(lastHandledLinkAt) > 0.35 else { return }
            lastHandledLinkAt = now

            let display = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "display" })?
                .value?
                .removingPercentEncoding ?? lookupKey

            let word = ActiveSubtitleWord(lookupKey: lookupKey, display: display)
            parent.activeWord = word

            translationTask?.cancel()
            translationTask = Task { @MainActor in
                await parent.translate(word: word)
            }
        }
    }
}

private extension TappableSubtitleTextRepresentable {
    @MainActor
    func translate(word: ActiveSubtitleWord) async {
        if Task.isCancelled { return }

        if let cached = await WordTranslationService.shared.cachedTranslation(
            for: word.lookupKey,
            sourceLanguage: sourceLanguage,
            context: .subtitle,
            useChatGPT: useChatGPT
        ) {
            guard !Task.isCancelled else { return }
            translationPreview = "\(word.display) — \(cached)"
            return
        }

        isTranslating = true
        translationPreview = "\(word.display) — …"

        do {
            let translated = try await WordTranslationService.shared.translate(
                word.lookupKey,
                sourceLanguage: sourceLanguage,
                context: .subtitle,
                useChatGPT: useChatGPT,
                backendBaseURL: backendBaseURL
            )
            guard !Task.isCancelled else { return }
            translationPreview = "\(word.display) — \(translated)"
        } catch {
            guard !Task.isCancelled else { return }
            if error is CancellationError { return }
            translationPreview = nil
            onTranslationError(error.localizedDescription)
        }

        isTranslating = false
    }
}

private final class TappableSubtitleTextView: UITextView {
    var onLinkHover: ((URL, UITextItemInteraction) -> Void)?
    var onLinkTap: ((URL) -> Void)?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
        if #available(iOS 13.4, *) {
            let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
            addGestureRecognizer(hover)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @available(iOS 13.4, *)
    @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        guard recognizer.state == .changed || recognizer.state == .began else { return }
        let point = recognizer.location(in: self)
        guard let url = linkURL(at: point) else { return }
        onLinkHover?(url, .preview)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let point = recognizer.location(in: self)
        guard let url = linkURL(at: point) else { return }
        onLinkTap?(url)
    }

    private func linkURL(at point: CGPoint) -> URL? {
        guard let position = closestPosition(to: point) else { return nil }
        let index = offset(from: beginningOfDocument, to: position)
        guard index < attributedText.length else { return nil }
        var range = NSRange(location: 0, length: 0)
        let value = attributedText.attribute(.link, at: index, effectiveRange: &range)
        return value as? URL
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 80
        let fitting = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: fitting.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

extension TappableSubtitleTextView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
