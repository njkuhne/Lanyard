import AppKit
import SwiftUI

/// Large clickable icon square, used for a server's icon.
struct SymbolWell: View {
    @Binding var selection: String
    let defaultSymbol: String
    @State private var isPresented = false
    @State private var hovering = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: SymbolCatalog.resolved(selection, fallback: defaultSymbol))
                .font(.system(size: 28))
                .foregroundStyle(selection.isEmpty ? .secondary : .primary)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(hovering ? 0.09 : 0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isPresented ? Theme.accent : Color.primary.opacity(0.15),
                            style: StrokeStyle(lineWidth: isPresented ? 2 : 1, dash: selection.isEmpty ? [4, 3] : [])
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Click to choose an icon")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            SymbolGrid(selection: $selection, defaultSymbol: defaultSymbol, isPresented: $isPresented)
        }
        .contextMenu {
            if !selection.isEmpty {
                Button("Use Default Icon") { selection = "" }
            }
        }
    }
}

/// Compact icon button for a service. Empty selection means "use the type's default".
struct SymbolPicker: View {
    @Binding var selection: String
    let defaultSymbol: String
    @State private var isPresented = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isPresented.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: SymbolCatalog.resolved(selection, fallback: defaultSymbol))
                        .frame(width: 18)
                    Text(selection.isEmpty ? "Default" : "Custom")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.bordered)
            .help("Choose an icon")
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                SymbolGrid(selection: $selection, defaultSymbol: defaultSymbol, isPresented: $isPresented)
            }

            if !selection.isEmpty {
                Button {
                    selection = ""
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Use the default icon")
            }
        }
    }
}

struct SymbolGrid: View {
    @Binding var selection: String
    let defaultSymbol: String
    @Binding var isPresented: Bool
    @State private var search = ""

    init(selection: Binding<String>, defaultSymbol: String, isPresented: Binding<Bool>) {
        _selection = selection
        self.defaultSymbol = defaultSymbol
        _isPresented = isPresented
    }

    private var current: String { selection.isEmpty ? defaultSymbol : selection }

    private var sections: [(String, [String])] {
        SymbolCatalog.sections(matching: search, defaultSymbol: defaultSymbol)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search icons", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if sections.isEmpty {
                        Text("No icons match “\(search)”")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(sections, id: \.0) { category, symbols in
                        Section {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 6) {
                                ForEach(symbols, id: \.self) { symbol in
                                    Button {
                                        selection = symbol == defaultSymbol ? "" : symbol
                                        isPresented = false
                                    } label: {
                                        Image(systemName: symbol)
                                            .font(.title2)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(current == symbol ? Theme.accent.opacity(0.22) : Color.clear)
                                            )
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help(symbol)
                                }
                            }
                        } header: {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(10)
            }
        }
        .frame(width: 340, height: 420)
    }
}
