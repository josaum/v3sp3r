import SwiftUI

public struct FapHubView: View {
    @State private var service = FapHubService.shared
    @State private var selectedTab: Int = 0 // 0 = Apps, 1 = Resource Repos
    @State private var selectedCategory: FapCategory = .all
    @State private var searchQuery: String = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header HUD
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Image(systemName: "app.badge.checkmark.fill")
                            .font(.system(size: 40))
                            .foregroundColor(FerriteSuiteTheme.flipperOrange)
                            .frame(width: 64, height: 64)
                            .background(FerriteSuiteTheme.flipperOrange.opacity(0.15))
                            .cornerRadius(14)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FapHub App Store & Resource Catalog")
                                .font(.title2.bold())
                            Text("Browse, install, and launch official Flipper applications and curated community vaults.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(20)
                .glassCard()
                
                // Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("Applications (.fap)").tag(0)
                    Text("Community Resource Repos").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
                
                if selectedTab == 0 {
                    // Category Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FapCategory.allCases) { cat in
                                Button(action: { selectedCategory = cat }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: cat.iconName)
                                            .font(.caption)
                                        Text(cat.rawValue)
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory == cat ? FerriteSuiteTheme.accentCyan : FerriteSuiteTheme.secondaryCardBackground)
                                    .foregroundColor(selectedCategory == cat ? .black : .primary)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search apps by name, author, or keyword...", text: $searchQuery)
                            .textFieldStyle(.plain)
                    }
                    .padding(10)
                    .background(FerriteSuiteTheme.secondaryCardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                    )
                    
                    if !service.installStatusText.isEmpty {
                        Text(service.installStatusText)
                            .font(.caption.monospaced())
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                            .padding(8)
                            .glassCard()
                    }
                    
                    // Apps Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320))], spacing: 16) {
                        ForEach(filteredApps) { app in
                            AppCard(app: app)
                        }
                    }
                } else {
                    // Resource Repositories
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340))], spacing: 16) {
                        ForEach(service.resourceRepos) { repo in
                            RepoCard(repo: repo)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(FerriteSuiteTheme.darkBackground)
    }
    
    private var filteredApps: [FapAppItem] {
        service.featuredApps.filter { app in
            let matchesCategory = (selectedCategory == .all || app.category == selectedCategory)
            let matchesSearch = searchQuery.isEmpty || app.name.localizedCaseInsensitiveContains(searchQuery) || app.description.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesSearch
        }
    }
}

private struct AppCard: View {
    let app: FapAppItem
    @State private var service = FapHubService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(FerriteSuiteTheme.accentCyan.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: app.category.iconName)
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.headline)
                    Text("by \(app.author) • \(app.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(app.category.rawValue)
                    .font(.system(size: 10, weight: .bold).monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(FerriteSuiteTheme.secondaryCardBackground)
                    .cornerRadius(4)
            }
            
            Text(app.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .frame(minHeight: 36, alignment: .topLeading)
            
            Divider().background(FerriteSuiteTheme.subtleBorder)
            
            HStack {
                Text(app.flipperAppPath)
                    .font(.system(size: 9).monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                if service.installedApps.contains(app.id) {
                    Button(action: {
                        Task { await service.launchInstalledApp(app) }
                    }) {
                        Label("Launch on Flipper", systemImage: "play.fill")
                            .font(.caption.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(FerriteSuiteTheme.neonGreen)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        Task { await service.installApp(app) }
                    }) {
                        if service.installingAppId == app.id {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Label("Install .fap", systemImage: "arrow.down.circle.fill")
                                .font(.caption.bold())
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(FerriteSuiteTheme.flipperOrange)
                                .cornerRadius(6)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(service.installingAppId != nil)
                }
            }
        }
        .padding(14)
        .glassCard()
    }
}

private struct RepoCard: View {
    let repo: CommunityResourceRepo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.badge.gearshape")
                    .font(.title2)
                    .foregroundColor(FerriteSuiteTheme.cyberPurple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.headline)
                    Text(repo.category)
                        .font(.caption.monospaced())
                        .foregroundColor(FerriteSuiteTheme.accentCyan)
                }
                
                Spacer()
            }
            
            Text(repo.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider().background(FerriteSuiteTheme.subtleBorder)
            
            HStack {
                Text("Target: \(repo.targetDirectory)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Link(destination: URL(string: repo.githubUrl)!) {
                    Label("View on GitHub ↗", systemImage: "link")
                        .font(.caption)
                        .foregroundColor(FerriteSuiteTheme.accentCyan)
                }
            }
        }
        .padding(14)
        .glassCard()
    }
}
