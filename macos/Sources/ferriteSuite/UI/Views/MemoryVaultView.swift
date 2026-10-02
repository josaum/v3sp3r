import SwiftUI

public struct MemoryVaultView: View {
    @State private var memoryStore = VesperMemoryStore.shared
    @State private var searchQuery: String = ""
    @State private var selectedCategory: MemoryCategory? = nil
    
    @State private var showAddSheet: Bool = false
    @State private var newCategory: MemoryCategory = .operatorNote
    @State private var newTitle: String = ""
    @State private var newContent: String = ""
    @State private var newIsPinned: Bool = false
    
    public init() {}
    
    private var filteredMemories: [VesperMemory] {
        var list = memoryStore.search(query: searchQuery)
        if let cat = selectedCategory {
            list = list.filter { $0.category == cat }
        }
        return list
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(VesperTheme.accentCyan)
                        Text("ferriteSuite Memory Vault")
                            .font(.title2.bold())
                    }
                    Text("Persistent long-term epistemic memory injected into Grok 4.7 context.")
                        .font(.caption)
                        .foregroundColor(VesperTheme.secondaryTextColor)
                }
                
                Spacer()
                
                Button(action: {
                    let export = memoryStore.memories.map { mem in
                        "### \(mem.isPinned ? "⭐ " : "")\(mem.title) (\(mem.category.rawValue))\n*Saved: \(mem.timestamp)*\n\n\(mem.content)\n\n---"
                    }.joined(separator: "\n\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(export, forType: .string)
                }) {
                    Label("Export Vault", systemImage: "arrow.up.doc")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VesperTheme.secondaryCardBackground)
                        .foregroundColor(.secondary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Copy entire memory vault as Markdown to clipboard")
                
                Button(action: { showAddSheet = true }) {
                    Label("Add Memory", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(VesperTheme.accentCyan.opacity(0.15))
                        .foregroundColor(VesperTheme.accentCyan)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(VesperTheme.cardBackground)
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Search and Category Filters
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search long-term memories, signals, device specs...", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(VesperTheme.secondaryCardBackground)
                .cornerRadius(8)
                
                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(title: "All (\(memoryStore.memories.count))", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        
                        ForEach(MemoryCategory.allCases, id: \.self) { cat in
                            let count = memoryStore.memories.filter { $0.category == cat }.count
                            FilterPill(title: "\(cat.rawValue) (\(count))", isSelected: selectedCategory == cat) {
                                selectedCategory = cat
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(VesperTheme.cardBackground)
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Memories List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredMemories.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "brain")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No memories found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Memories are automatically recorded from hardware telemetry, signal captures, and operator directives.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(filteredMemories) { mem in
                            MemoryCard(memory: mem)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(VesperTheme.darkBackground)
        .sheet(isPresented: $showAddSheet) {
            AddMemorySheet(isPresented: $showAddSheet)
        }
    }
}

// MARK: - Memory Card Component

private struct MemoryCard: View {
    let memory: VesperMemory
    @State private var store = VesperMemoryStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Category Badge
                HStack(spacing: 4) {
                    Image(systemName: memory.category.iconName)
                        .font(.caption2)
                    Text(memory.category.rawValue)
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(memory.category.color.opacity(0.12))
                .foregroundColor(memory.category.color)
                .cornerRadius(6)
                
                Text(memory.title)
                    .font(.subheadline.bold())
                    .foregroundColor(VesperTheme.primaryTextColor)
                
                Spacer()
                
                // Copy button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("[\(memory.title)] (\(memory.category.rawValue))\n\(memory.content)", forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy memory to clipboard")
                
                // Pin button
                Button(action: { store.togglePin(id: memory.id) }) {
                    Image(systemName: memory.isPinned ? "pin.fill" : "pin")
                        .font(.caption)
                        .foregroundColor(memory.isPinned ? VesperTheme.neonAmber : .secondary)
                }
                .buttonStyle(.plain)
                .help(memory.isPinned ? "Unpin memory" : "Pin memory to top")
                
                // Delete button
                Button(action: { store.deleteMemory(id: memory.id) }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete memory")
            }
            
            Text(memory.content)
                .font(.callout)
                .foregroundColor(VesperTheme.secondaryTextColor)
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Text(memory.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(memory.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .glassCard()
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? VesperTheme.accentCyan.opacity(0.2) : VesperTheme.secondaryCardBackground)
                .foregroundColor(isSelected ? VesperTheme.accentCyan : VesperTheme.secondaryTextColor)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? VesperTheme.accentCyan : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Memory Sheet

private struct AddMemorySheet: View {
    @Binding var isPresented: Bool
    @State private var category: MemoryCategory = .operatorNote
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isPinned: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Add Knowledge to Memory Vault")
                    .font(.headline)
                Spacer()
                Button("Cancel") { isPresented = false }
            }
            
            Picker("Category", selection: $category) {
                ForEach(MemoryCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.menu)
            
            TextField("Memory Title (e.g. 'Office Gate Rolling Code')", text: $title)
                .textFieldStyle(.roundedBorder)
            
            TextEditor(text: $content)
                .frame(minHeight: 120)
                .border(VesperTheme.subtleBorder, width: 1)
                .cornerRadius(6)
            
            Toggle("Pin Memory (Always prioritize in Grok 4.7 context)", isOn: $isPinned)
            
            HStack {
                Spacer()
                Button("Save Memory") {
                    guard !title.isEmpty else { return }
                    VesperMemoryStore.shared.addMemory(
                        category: category,
                        title: title,
                        content: content,
                        isPinned: isPinned
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 440, minHeight: 360)
        .background(VesperTheme.cardBackground)
    }
}
