import SwiftUI
import UniformTypeIdentifiers

/// macOS experience: sidebar navigation with a Mail-style list + detail split for history.
struct MacRootView: View {
    typealias SidebarItem = MacSidebarDestination

    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var navCoordinator: AppNavigationCoordinator

    var body: some View {
        NavigationSplitView {
            List(selection: $navCoordinator.macSidebarSelection) {
                Section("Overview") {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                        .tag(MacSidebarDestination.dashboard)
                        .keyboardShortcut("1", modifiers: .command)
                    Label("Battery Health", systemImage: "bolt.batteryblock.fill")
                        .tag(MacSidebarDestination.batteryHealth)
                        .keyboardShortcut("2", modifiers: .command)
                }

                Section("History") {
                    ForEach(SessionFilter.allCases) { filter in
                        Label(filter.sidebarTitle, systemImage: filter.icon)
                            .badge(store.sessions.filter { filter.matches($0) }.count)
                            .tag(MacSidebarDestination.history(filter))
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
            switch navCoordinator.macSidebarSelection ?? .dashboard {
            case .dashboard:
                DashboardView()
            case .batteryHealth:
                BatteryHealthView()
            case .history(let filter):
                MacHistoryView(filter: filter)
            }
        }
        .sheet(isPresented: $navCoordinator.showingAddSession) {
            AddSessionView()
                .frame(minWidth: 540, minHeight: 640)
        }
        .sheet(isPresented: $navCoordinator.showingSettings) {
            SettingsView()
                .frame(minWidth: 500, minHeight: 550)
        }
        .fileExporter(
            isPresented: $navCoordinator.showingExporter,
            document: CSVDocument(text: CSVExporter.generateCSV(from: store.sessions)),
            contentType: .commaSeparatedText,
            defaultFilename: "Joule_Export"
        ) { _ in }
        .fileImporter(
            isPresented: $navCoordinator.showingImporter,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            store.handleImport(result)
        }
    }

    private var newSessionButton: some View {
        Button {
            navCoordinator.presentNewSession()
        } label: {
            Label("New Session", systemImage: "plus.circle.fill")
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .keyboardShortcut("n", modifiers: .command)
        .accessibilityLabel("New Charging Session")
        .accessibilityHint("Opens sheet to log a new charging session")
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private var settingsButton: some View {
        Button {
            navCoordinator.presentSettings()
        } label: {
            Label("Settings", systemImage: "gearshape")
                .font(.callout)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .keyboardShortcut(",", modifiers: .command)
        .accessibilityLabel("Settings")
        .accessibilityHint("Opens vehicle settings and preferences")
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
        .accessibilityLabel("Sign In with Google")
        .accessibilityHint("Enables automatic cloud backup and sync")
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
        .accessibilityLabel("Sign Out")
        .accessibilityHint("Signs out of Google account")
        .padding(.trailing, 12)
        .padding(.vertical, 10)
    }
}

/// Two-pane history: session list on the left, detail on the right.
struct MacHistoryView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var navCoordinator: AppNavigationCoordinator
    let filter: SessionFilter

    @State private var searchText = ""
    @State private var selectedSessionID: String?
    @State private var sessionToEdit: ChargingSession?
    @State private var sessionToDelete: ChargingSession?

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
                    if store.duplicateSessionsCount > 0 {
                        Button(action: { store.cleanDuplicates() }) {
                            Label("Clean Up Duplicates (\(store.duplicateSessionsCount))", systemImage: "sparkles.rectangle.stack")
                        }
                        Divider()
                    }

                    Button(action: { navCoordinator.triggerImport() }) {
                        Label("Import CSV…", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("i", modifiers: [.command, .shift])

                    Button(action: {
                        navCoordinator.triggerExport()
                    }) {
                        // The whole history, not the current filter — this is the backup path.
                        Label("Export All to CSV…", systemImage: "square.and.arrow.up")
                    }
                    .keyboardShortcut("e", modifiers: .command)
                } label: {
                    Label("Import/Export", systemImage: "square.and.arrow.up.on.square")
                }

                Button(action: { navCoordinator.presentNewSession() }) {
                    Label("New Session", systemImage: "plus")
                }
            }
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
                        Text(VehicleProfile.currency.format(sessions.reduce(0) { $0 + $1.totalPrice }))
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
    @AppStorage("app_currency") private var appCurrency: AppCurrency = VehicleProfile.defaultCurrency

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.locationName ?? "Unknown Location")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                Text(appCurrency.format(session.totalPrice))
                    .font(.subheadline).bold()
                    .foregroundColor(session.paymentStatus == .deferred ? .orange : .primary)
                    .lineLimit(1)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.locationName ?? "Charging Session"), \(session.date.formatted(.dateTime.month(.abbreviated).day().locale(Locale(identifier: "en_US_POSIX"))))")
        .accessibilityValue("\(session.chargingType?.rawValue ?? "") \(String(format: "%.1f kWh", session.energyAdded)), \(appCurrency.format(session.totalPrice))\(session.paymentStatus == .deferred ? ", Deferred" : "")")
    }
}
