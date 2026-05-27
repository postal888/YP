import Foundation

@MainActor
final class DictionaryFolderRecordingController: ObservableObject {
    @Published private(set) var session: DictionaryFolderRecordingSession?
    @Published var isMinimized = false
    private(set) var viewModel: DictionaryFolderRecordingViewModel?

    var isActive: Bool { session != nil }
    var isSheetPresented: Bool { session != nil && !isMinimized }

    func present(
        session: DictionaryFolderRecordingSession,
        vocabularyStore: VocabularyStore,
        appSettings: AppSettings
    ) {
        if self.session?.id != session.id {
            viewModel?.cleanupOnDismiss()
            viewModel = DictionaryFolderRecordingViewModel(
                folder: session.folder,
                playbackCards: session.playbackCards,
                vocabularyStore: vocabularyStore,
                appSettings: appSettings
            )
        }
        self.session = session
        isMinimized = false
    }

    func minimize() {
        isMinimized = true
    }

    func expand() {
        isMinimized = false
    }

    func dismiss() {
        viewModel?.cleanupOnDismiss()
        viewModel = nil
        session = nil
        isMinimized = false
    }
}
