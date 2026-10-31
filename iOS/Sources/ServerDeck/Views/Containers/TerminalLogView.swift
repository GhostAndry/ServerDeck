import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct TerminalLogView: View {
    let logs: [String]
    @Binding var searchText: String
    @Binding var showTimestamps: Bool
    @Binding var autoScroll: Bool
    var onRefresh: (() -> Void)? = nil

    @State private var copied: Bool = false

    public init(
        logs: [String],
        searchText: Binding<String>,
        showTimestamps: Binding<Bool>,
        autoScroll: Binding<Bool>,
        onRefresh: (() -> Void)? = nil
    ) {
        self.logs = logs
        self._searchText = searchText
        self._showTimestamps = showTimestamps
        self._autoScroll = autoScroll
        self.onRefresh = onRefresh
    }

    private var filteredLines: [String] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return logs
        }
        let query = searchText.lowercased()
        return logs.filter { $0.lowercased().contains(query) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Terminal Toolbar Header
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                        Circle().fill(Color.yellow).frame(width: 10, height: 10)
                        Circle().fill(Color.green).frame(width: 10, height: 10)

                        Text("stdout / stderr")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.leading, 6)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        // Toggle Timestamps
                        Button {
                            showTimestamps.toggle()
                            HapticManager.selection()
                        } label: {
                            Image(systemName: showTimestamps ? "clock.fill" : "clock")
                                .font(.system(size: 13))
                                .foregroundColor(showTimestamps ? .accentColor : .secondary)
                        }

                        // Toggle Auto-scroll
                        Button {
                            autoScroll.toggle()
                            HapticManager.selection()
                        } label: {
                            Image(systemName: autoScroll ? "arrow.down.to.line.compact" : "arrow.down.to.line")
                                .font(.system(size: 13))
                                .foregroundColor(autoScroll ? .accentColor : .secondary)
                        }

                        // Copy Button
                        Button {
                            copyLogsToClipboard()
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13))
                                .foregroundColor(copied ? Theme.success : .secondary)
                        }

                        // Refresh logs
                        Button {
                            onRefresh?()
                            HapticManager.light()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Search Bar inside Terminal
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    TextField("Filter terminal logs...", text: $searchText)
                        .font(.system(size: 12, design: .monospaced))
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            .padding(10)
            .background(Color(red: 0.12, green: 0.14, blue: 0.17))

            Divider()
                .background(Color.white.opacity(0.1))

            // Console Output Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if filteredLines.isEmpty {
                            Text("No log messages found.")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(12)
                        } else {
                            ForEach(Array(filteredLines.enumerated()), id: \.offset) { index, line in
                                Text(formattedLine(line))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Theme.terminalText)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(minHeight: 280, maxHeight: 380)
                .background(Theme.terminalBackground)
                .onChange(of: filteredLines.count) {
                    if autoScroll, let lastIndex = filteredLines.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .cornerRadius(12)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func formattedLine(_ line: String) -> AttributedString {
        // Simple formatting to highlight timestamps
        if !showTimestamps && line.contains("T") && line.contains("Z") {
            // Strip timestamp prefix if found before standard log patterns
            if let closingIndex = line.firstIndex(of: "]") {
                let rest = line[closingIndex...]
                return AttributedString(String(rest))
            }
        }
        return AttributedString(line)
    }

    private func copyLogsToClipboard() {
        let fullText = filteredLines.joined(separator: "\n")
        #if canImport(UIKit)
        UIPasteboard.general.string = fullText
        #endif
        copied = true
        HapticManager.success()

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                copied = false
            }
        }
    }
}
