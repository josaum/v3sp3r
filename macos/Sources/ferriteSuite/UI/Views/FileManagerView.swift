import SwiftUI

public struct FileManagerView: View {
    @State private var connection = FlipperConnectionManager.shared
    @State private var currentPath: String = "/ext"
    @State private var files: [FileItem] = []
    @State private var isLoading: Bool = false
    @State private var selectedFile: FileItem?
    @State private var fileContent: String = ""
    @State private var isReadingFile: Bool = false
    @State private var errorMessage: String = ""
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // File List Table
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 10) {
                    Button(action: goUp) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(currentPath == "/ext" || currentPath == "/")
                    
                    Text(currentPath)
                        .font(.subheadline.monospaced())
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(FerriteSuiteTheme.secondaryCardBackground)
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Button(action: selectLocalFileAndUpload) {
                        Label("Upload File", systemImage: "arrow.up.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FerriteSuiteTheme.secondaryCardBackground)
                    .cornerRadius(6)
                    
                    Button(action: { Task { await loadDirectory(path: currentPath) } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .padding(12)
                .background(FerriteSuiteTheme.cardBackground)
                
                Divider()
                    .background(FerriteSuiteTheme.subtleBorder)
                
                if isLoading {
                    Spacer()
                    ProgressView("Reading SD Card...")
                    Spacer()
                } else if files.isEmpty {
                    Spacer()
                    Text("No files found or directory empty.")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(files) { file in
                        HStack {
                            Image(systemName: fileIcon(file))
                                .foregroundColor(file.isDirectory ? FerriteSuiteTheme.neonAmber : FerriteSuiteTheme.accentCyan)
                                .frame(width: 20)
                            
                            Text(file.name)
                                .font(.body.monospaced())
                            
                            Spacer()
                            
                            if !file.isDirectory && file.size > 0 {
                                Text("\(file.size) B")
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if file.isDirectory {
                                Task { await loadDirectory(path: file.path) }
                            } else {
                                selectedFile = file
                                Task { await readFile(path: file.path) }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 320)
            
            // Detail Preview Panel
            VStack(alignment: .leading, spacing: 12) {
                if let file = selectedFile {
                    HStack {
                        Image(systemName: fileIcon(file))
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                        Text(file.name)
                            .font(.headline.monospaced())
                        Spacer()
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(fileContent, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy content to clipboard")
                        
                        Button(action: {
                            let panel = NSSavePanel()
                            panel.nameFieldStringValue = file.name
                            if panel.runModal() == .OK, let url = panel.url {
                                try? fileContent.write(to: url, atomically: true, encoding: .utf8)
                            }
                        }) {
                            Image(systemName: "arrow.down.doc")
                                .foregroundColor(FerriteSuiteTheme.accentCyan)
                        }
                        .buttonStyle(.plain)
                        .help("Export/Save file to Mac")
                        
                        Button(action: {
                            Task {
                                _ = try? await connection.executeCommand("storage remove \(file.path)")
                                await loadDirectory(path: currentPath)
                                selectedFile = nil
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(FerriteSuiteTheme.neonRed)
                        }
                        .buttonStyle(.plain)
                        .help("Delete File")
                    }
                    
                    Text("Path: \(file.path)")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .background(FerriteSuiteTheme.subtleBorder)
                    
                    if isReadingFile {
                        ProgressView("Loading file...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            Text(fileContent)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .background(FerriteSuiteTheme.terminalBackground)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                        )
                    }
                    
                    // Quick Action Buttons
                    HStack {
                        if file.name.hasSuffix(".sub") {
                            Button(action: {
                                Task { _ = try? await connection.executeCommand("subghz tx \(file.path) 1") }
                            }) {
                                Label("Transmit Sub-GHz", systemImage: "antenna.radiowaves.left.and.right")
                            }
                            .buttonStyle(.borderedProminent)
                        } else if file.name.hasSuffix(".txt") && file.path.contains("badusb") {
                            Button(action: {
                                Task { _ = try? await connection.executeCommand("badusb run \(file.path)") }
                            }) {
                                Label("Run BadUSB", systemImage: "keyboard")
                            }
                            .buttonStyle(.borderedProminent)
                        } else if file.name.hasSuffix(".ir") {
                            Button(action: {
                                Task { _ = try? await connection.executeCommand("ir tx \(file.path)") }
                            }) {
                                Label("Transmit IR", systemImage: "rays")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Select a file to inspect or transmit")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
            .padding(16)
            .background(FerriteSuiteTheme.cardBackground)
            .frame(minWidth: 280)
        }
        .background(FerriteSuiteTheme.darkBackground)
        .onAppear {
            Task { await loadDirectory(path: currentPath) }
        }
    }
    
    private func goUp() {
        let parts = currentPath.split(separator: "/")
        if parts.count > 1 {
            let parent = "/" + parts.dropLast().joined(separator: "/")
            Task { await loadDirectory(path: parent) }
        }
    }
    
    private func loadDirectory(path: String) async {
        isLoading = true
        currentPath = path
        do {
            let output = try await connection.executeCommand("storage list \(path)")
            let parsed = parseStorageList(output, parentPath: path)
            DispatchQueue.main.async {
                self.files = parsed
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func readFile(path: String) async {
        isReadingFile = true
        do {
            let output = try await connection.executeCommand("storage read \(path)")
            DispatchQueue.main.async {
                self.fileContent = output
                self.isReadingFile = false
            }
        } catch {
            DispatchQueue.main.async {
                self.fileContent = "Failed to read: \(error.localizedDescription)"
                self.isReadingFile = false
            }
        }
    }
    
    private func parseStorageList(_ raw: String, parentPath: String) -> [FileItem] {
        var items: [FileItem] = []
        let lines = raw.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.contains(">:"), !trimmed.hasPrefix("Storage list") else { continue }
            
            let isDir = trimmed.hasPrefix("[D]") || trimmed.contains("<DIR>") || trimmed.hasSuffix("/")
            let cleanName = trimmed
                .replacingOccurrences(of: "[D] ", with: "")
                .replacingOccurrences(of: "[F] ", with: "")
                .replacingOccurrences(of: "<DIR>", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            let fullPath = "\(parentPath)/\(cleanName)".replacingOccurrences(of: "//", with: "/")
            items.append(FileItem(name: cleanName, path: fullPath, isDirectory: isDir))
        }
        return items.sorted { ($0.isDirectory ? 0 : 1) < ($1.isDirectory ? 0 : 1) }
    }
    
    private func fileIcon(_ file: FileItem) -> String {
        if file.isDirectory { return "folder.fill" }
        if file.name.hasSuffix(".sub") { return "antenna.radiowaves.left.and.right" }
        if file.name.hasSuffix(".ir") { return "rays" }
        if file.name.hasSuffix(".nfc") { return "wave.3.forward" }
        if file.name.hasSuffix(".txt") { return "doc.text" }
        if file.name.hasSuffix(".fap") { return "app.fill" }
        return "doc"
    }
    
    private func selectLocalFileAndUpload() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select a file to upload to Flipper Zero"
        if panel.runModal() == .OK, let url = panel.url {
            uploadLocalFile(at: url)
        }
    }
    
    private func uploadLocalFile(at url: URL) {
        guard let content = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1)) else {
            return
        }
        let fileName = url.lastPathComponent
        let targetPath = "\(currentPath)/\(fileName)".replacingOccurrences(of: "//", with: "/")
        
        Task {
            _ = await FlipperToolExecutor.shared.execute(action: "write_file", params: ["path": targetPath, "content": content])
            await loadDirectory(path: currentPath)
        }
    }
}
