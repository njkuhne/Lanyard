import AppKit
import SwiftUI

/// The Edit YAML window: the whole config as text, checked before it's saved.
struct YAMLEditorView: View {
    @ObservedObject private var store: ConfigStore
    @StateObject private var state: YAMLEditorState
    private let session: EditorSession?

    init(store: ConfigStore, session: EditorSession? = nil, prompts: EditorPrompts = .system) {
        self.store = store
        _state = StateObject(wrappedValue: YAMLEditorState(store: store, prompts: prompts))
        self.session = session
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Edit or paste your config. It's checked before it's saved.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                CodeEditor(text: $state.text)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))

                HStack {
                    Button("Import…", action: state.importFile)
                    Button("Export…", action: state.exportFile)
                    Spacer()
                }
                .controlSize(.small)
            }
            .padding(12)

            Divider()
            EditorBottomBar(
                message: state.message,
                messageIsError: state.messageIsError,
                hasUnsavedChanges: state.hasUnsavedChanges,
                revert: state.revert,
                save: { state.save() }
            )
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear { session?.save = { [state] in state.save() } }
        .onChange(of: state.hasUnsavedChanges) { session?.isDirty = $0 }
        .onChange(of: store.rawText) { _ in state.storeDidChange() }
    }
}

// MARK: - Plain-text editor (no smart quotes, which would break YAML)

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.string = text
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text { textView.string = text }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        init(_ parent: CodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
