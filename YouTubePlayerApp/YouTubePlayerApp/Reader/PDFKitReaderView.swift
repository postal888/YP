import SwiftUI
import PDFKit

struct PDFReaderWordTap: Equatable {
    let display: String
    let lookupKey: String
}

struct PDFKitReaderView: UIViewRepresentable {
    let document: PDFDocument
    let savedWordKeys: Set<String>
    let fontScale: CGFloat
    let onWordTap: (PDFReaderWordTap) -> Void
    let onPageChange: (Int, Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> FitWidthPDFView {
        let pdfView = FitWidthPDFView()
        pdfView.autoScales = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false, withViewOptions: nil)
        pdfView.backgroundColor = UIColor(PortTheme.surfaceMuted)
        pdfView.pageShadowsEnabled = false
        pdfView.document = document
        pdfView.delegate = context.coordinator
        pdfView.fontScale = fontScale

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = false
        pdfView.addGestureRecognizer(tap)

        context.coordinator.pdfView = pdfView
        DispatchQueue.main.async {
            pdfView.applyFitWidthScale()
            context.coordinator.reportPageChange()
        }
        return pdfView
    }

    func updateUIView(_ pdfView: FitWidthPDFView, context: Context) {
        context.coordinator.parent = self
        if pdfView.document !== document {
            pdfView.document = document
        }
        if abs(pdfView.fontScale - fontScale) > 0.001 {
            pdfView.fontScale = fontScale
            pdfView.applyFitWidthScale()
        }
    }

    final class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitReaderView
        weak var pdfView: FitWidthPDFView?

        init(parent: PDFKitReaderView) {
            self.parent = parent
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let pdfView else { return }
            let location = recognizer.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }

            let pagePoint = pdfView.convert(location, to: page)
            guard let selection = page.selectionForWord(at: pagePoint),
                  let rawWord = selection.string?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                  !rawWord.isEmpty else {
                return
            }

            let lookupKey = SubtitleWordTokenizer.stripWordPunctuation(rawWord)
            guard lookupKey.count >= 2 else { return }

            pdfView.setCurrentSelection(selection, animate: true)
            highlightSelection(selection, saved: parent.savedWordKeys.contains(lookupKey.lowercased()))

            parent.onWordTap(
                PDFReaderWordTap(display: rawWord, lookupKey: lookupKey)
            )
        }

        func pdfViewPageChanged(_ sender: PDFView) {
            reportPageChange()
        }

        func reportPageChange() {
            guard
                let pdfView,
                let document = pdfView.document,
                let currentPage = pdfView.currentPage
            else {
                return
            }

            let index = document.index(for: currentPage)
            parent.onPageChange(index + 1, document.pageCount)
        }

        private func highlightSelection(_ selection: PDFSelection, saved: Bool) {
            selection.color = saved
                ? UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 0.35)
                : UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 0.22)
        }
    }
}

final class FitWidthPDFView: PDFView {
    var fontScale: CGFloat = 1.0
    private var lastAppliedFontScale: CGFloat = 1.0
    private var lastBoundsSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        applyFitWidthScale()
    }

    func applyFitWidthScale() {
        guard document != nil else { return }
        layoutDocumentView()
        let fitScale = scaleFactorForSizeToFit
        guard fitScale > 0 else { return }

        minScaleFactor = fitScale * 0.85
        maxScaleFactor = fitScale * 2.5

        let boundsChanged = bounds.size != lastBoundsSize
        let fontScaleChanged = abs(fontScale - lastAppliedFontScale) > 0.001
        guard boundsChanged || fontScaleChanged else { return }

        scaleFactor = fitScale * max(fontScale, 0.85)
        lastAppliedFontScale = fontScale
        lastBoundsSize = bounds.size
    }
}
