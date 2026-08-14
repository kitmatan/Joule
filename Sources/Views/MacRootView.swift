import SwiftUI
import UniformTypeIdentifiers

/// macOS experience: sidebar navigation with a Mail-style list + detail split for history.
struct MacRootView: View {
    enum SidebarItem: Hashable {
        case dashboard
        case batteryHealth
        case history(SessionFilter)
    }

    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var auth: AuthService
    @State private var selection: SidebarItem? = .dashboard
    @State private var showingAddSession = false
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Overview") {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                        .tag(SidebarItem.dashboard)
                    Label("Battery Health", systemImage: "bolt.batteryblock.fill")
                        .tag(SidebarItem.batteryHealth)
                }

                Section("History") {
                    ForEach(SessionFilter.allCases) { filter in
                        Label(filter.sidebarTitle, systemImage: filter.icon)
                            .badge(store.sessions.filter { filter.matches($0) }.count)
                            .tag(SidebarItem.history(filter))
                    }
                }
            }
            .navigationTitle("Joule")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    newSessionButton
                    HStack {
                        settingsButton
                        Spacer()
                        if auth.isSignedIn {
                            signOutButton
                        } else {
                            signInButton
                        }
                    }
                }
                .background(.bar)
            }
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard:
                DashboardView()
            case .batteryHealth:
                BatteryHealthView()
            case .history(let filter):
                MacHistoryView(filter: filter)
            }
        }
        .sheet(isPresented: $showingAddSession) {
            AddSessionView()
                .frame(minWidth: 540, minHeight: 640)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .frame(minWidth: 500, minHeight: 550)
        }
    }

    private var newSessionButton: some View {
        Button {
            showingAddSession = true
        } label: {
            Label("New Session", systemImage: "plus.circle.fill")
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .keyboardShortcut("n", modifiers: .command)
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape")
                .font(.callout)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.leading, 12)
        .padding(.vertical, 10)
    }

    private var signInButton: some View {
        Button {
            auth.signIn()
        } label: {
            Label("Sign In", systemImage: "icloud.and.arrow.up")
                .font(.callout)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
    }

    private var signOutButton: some View {
        Button {
            auth.signOut()
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.callout)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
    }
}

/// Two-pane history: session list on the left, detail on the right.
struct MacHistoryView: View {
    @EnvironmentObject private var store: SessionStore
    let filter: SessionFilter

    @State private var searchText = ""
    @State private var selectedSessionID: String?
    @State private var showingAddSession = false
    @State private var sessionToEdit: ChargingSession?
    @State private var sessionToDelete: ChargingSession?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var csvDocument: CSVDocument?

    var filteredSessions: [ChargingSession] {
        store.sessions.filter { session in
            guard filter.matches(session) else { return false }
            guard !searchText.isEmpty else { return true }
            let haystack = [session.locationName, session.vendorName, session.notes]
                .compactMap { $0 }
                .joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedSessions: [(String, [ChargingSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            session.date.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "en_US_POSIX")))
        }
        return grouped.sorted { a, b in
            guard let aDate = a.value.first?.date, let bDate = b.value.first?.date else { return false }
            return aDate > bDate
        }
    }

    var selectedSession: ChargingSession? {
        guard let id = selectedSessionID else { return nil }
        return store.sessions.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            sessionList
                .frame(minWidth: 330, idealWidth: 380, maxWidth: 430)

            Divider()

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(filter.sidebarTitle)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search location, vendor, notes")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(action: { showingImporter = true }) {
                        Label("Import CSV…", systemImage: "square.and.arrow.down")
                    }
                    Button(action: {
                        csvDocument = CSVDocument(text: CSVExporter.generateCSV(from: store.sessions))
                        showingExporter = true
                    }) {
                        // The whole history, not the current filter — this is the backup path.
                        Label("Export All to CSV…", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("Import/Export", systemImage: "square.and.arrow.up.on.square")
                }

                Button(action: { showingAddSession = true }) {
                    Label("New Session", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSession) {
            AddSessionView()
                .frame(minWidth: 540, minHeight: 640)
        }
        .sheet(item: $sessionToEdit) { session in
            AddSessionView(sessionToEdit: session)
                .frame(minWidth: 540, minHeight: 640)
        }
        .confirmationDialog(
            "Delete Charging Session?",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            presenting: sessionToDelete
        ) { session in
            Button("Delete Session", role: .destructive) {
                if selectedSessionID == session.id {
                    selectedSessionID = nil
                }
                store.deleteSession(session)
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: { session in
            Text("Are you sure you want to delete the charging session at \(session.locationName ?? "this location") on \(session.date.formatted(.dateTime.month(.abbreviated).day().year().locale(Locale(identifier: "en_US_POSIX"))))?")
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "Joule_Export"
        ) { _ in }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            store.handleImport(result)
        }
    }

    private var sessionList: some View {
        List(selection: $selectedSessionID) {
            ForEach(groupedSessions, id: \.0) { month, sessions in
                Section {
                    ForEach(sessions) { session in
                        MacSessionRow(session: session)
                            .tag(session.id ?? "")
                            .contextMenu {
                                Button("Edit…") {
                                    selectedSessionID = session.id
                                    sessionToEdit = session
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    sessionToDelete = session
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(month)
                        Spacer()
                        Text(sessions.reduce(0) { $0 + $1.totalPrice }
                            .formatted(.currency(code: "THB").presentation(.narrow)))
                        Text("•")
                        Text(String(format: "%.0f kWh", sessions.reduce(0) { $0 + $1.energyAdded }))
                    }
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if filteredSessions.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "bolt.car",
                        description: Text("Sessions matching this filter will appear here.")
                    )
                } else {
                    ContentUnavailableView.search
                }
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let session = selectedSession {
            ScrollView {
                SessionDetailContent(session: session)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Spacer()
                    Button {
                        sessionToEdit = session
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground).opacity(0.4))
        } else {
            ContentUnavailableView(
                "Select a Session",
                systemImage: "sidebar.right",
                description: Text("Choose a charging session from the list to see its details.")
            )
        }
    }
}

/// Compact row tuned for the narrow Mac list column.
struct MacSessionRow: View {
    let session: ChargingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.locationName ?? "Unknown Location")
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(session.totalPrice.formatted(.currency(code: "THB").presentation(.narrow)))
                    .font(.subheadline).bold()
                    .foregroundColor(session.paymentStatus == .deferred ? .orange : .primary)
            }

            HStack(spacing: 6) {
                if let type = session.chargingType {
                    Text(type.rawValue)
                        .font(.caption2).bold()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background((type == .dc ? Color.orange : Color.blue).opacity(0.15))
                        .foregroundColor(type == .dc ? .orange : .blue)
                        .clipShape(Capsule())
                }
                Text(String(format: "%.1f kWh", session.energyAdded))
                Text("•")
                Text(session.date.formatted(.dateTime.month(.abbreviated).day().locale(Locale(identifier: "en_US_POSIX"))))
                if session.paymentStatus == .deferred {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 3)
    }
}
