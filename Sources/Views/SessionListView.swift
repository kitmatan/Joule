import SwiftUI
import UniformTypeIdentifiers

enum SessionFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "All"
    case ac = "AC Only"
    case dc = "DC Only"
    case home = "Home"
    case publicStation = "Public"
    case deferred = "Deferred Payment"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .ac: return "powerplug"
        case .dc: return "bolt.fill"
        case .home: return "house"
        case .publicStation: return "mappin.and.ellipse"
        case .deferred: return "list.bullet.rectangle.portrait"
        }
    }

    /// Display name used in the macOS sidebar.
    var sidebarTitle: String {
        self == .all ? "All Sessions" : rawValue
    }

    func matches(_ session: ChargingSession) -> Bool {
        switch self {
        case .all: return true
        case .ac: return session.chargingType == .ac
        case .dc: return session.chargingType == .dc
        case .home: return session.locationType == .home
        case .publicStation: return session.locationType == .publicStation
        case .deferred: return session.paymentStatus == .deferred
        }
    }
}

struct SessionListView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var navCoordinator: AppNavigationCoordinator

    @State private var showingAddSession = false
    @State private var showingSettings = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var sessionToDelete: ChargingSession?
    @State private var csvDocument: CSVDocument?
    @State private var searchText = ""
    @State private var filter: SessionFilter = .all

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

    // Group sessions by Month and Year (e.g., "July 2026")
    var groupedSessions: [(String, [ChargingSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            session.date.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "en_US_POSIX")))
        }

        // Sort groups by the date of the first item (newest first)
        return grouped.sorted { a, b in
            guard let aDate = a.value.first?.date, let bDate = b.value.first?.date else { return false }
            return aDate > bDate
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedSessions, id: \.0) { month, sessions in
                    Section {
                        ForEach(sessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                SessionRow(session: session)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                } label: {
                                    Label("Delete", systemImage: "trash")
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
            .searchable(text: $searchText, prompt: "Search location, vendor, notes")
            .overlay {
                if store.sessions.isEmpty {
                    VStack(spacing: 20) {
                        Text("No charging history yet.")
                            .foregroundColor(.secondary)
                        Button("Add Charging Session") {
                            navCoordinator.presentNewSession()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if filteredSessions.isEmpty {
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
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Menu {
                            Picker("Filter", selection: $filter) {
                                ForEach(SessionFilter.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            Divider()
                            Button(action: { navCoordinator.triggerImport() }) {
                                Label("Import CSV…", systemImage: "square.and.arrow.down")
                            }
                            .keyboardShortcut("i", modifiers: [.command, .shift])

                            Button(action: {
                                navCoordinator.triggerExport()
                            }) {
                                Label("Export All to CSV…", systemImage: "square.and.arrow.up")
                            }
                            .keyboardShortcut("e", modifiers: .command)

                            Divider()
                            Button(action: { navCoordinator.presentSettings() }) {
                                Label("Settings…", systemImage: "gearshape")
                            }
                            .keyboardShortcut(",", modifiers: .command)

                            Button(role: .destructive, action: { auth.signOut() }) {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: filter == .all
                                  ? "line.3.horizontal.decrease.circle"
                                  : "line.3.horizontal.decrease.circle.fill")
                                .fontWeight(.semibold)
                        }
                        .accessibilityLabel("History Options")

                        Button(action: { navCoordinator.presentNewSession() }) {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                        .keyboardShortcut("n", modifiers: .command)
                        .accessibilityLabel("New Session")
                    }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                AddSessionView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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
    }
    
}

struct SessionRow: View {
    let session: ChargingSession
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Background
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "bolt.car.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(session.locationName ?? "Unknown Location")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                HStack(spacing: 4) {
                    if let vendor = session.vendorName, !vendor.isEmpty {
                        Text(vendor)
                        Text("•")
                    }
                    Text(session.date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute().locale(Locale(identifier: "en_US_POSIX"))))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        if let type = session.chargingType {
                            metricView(icon: "powerplug.fill", text: type.rawValue, color: type == .dc ? .orange : .blue)
                        }
                        metricView(icon: "bolt.fill", text: String(format: "%.1f kWh", session.energyAdded))
                        metricView(icon: "clock.fill", text: String(format: "%.0f min", session.duration / 60))
                        if session.speed > 0 {
                            metricView(icon: "gauge.medium", text: String(format: "%.0f kW", session.speed))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if let type = session.chargingType {
                                metricView(icon: "powerplug.fill", text: type.rawValue, color: type == .dc ? .orange : .blue)
                            }
                            metricView(icon: "bolt.fill", text: String(format: "%.1f kWh", session.energyAdded))
                        }
                        HStack(spacing: 8) {
                            metricView(icon: "clock.fill", text: String(format: "%.0f min", session.duration / 60))
                            if session.speed > 0 {
                                metricView(icon: "gauge.medium", text: String(format: "%.0f kW", session.speed))
                            }
                        }
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            }
            
            Spacer(minLength: 8)
            
            // Cost
            VStack(alignment: .trailing, spacing: 4) {
                if session.paymentStatus == .deferred {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text(session.totalPrice.formatted(.currency(code: "THB").presentation(.narrow)))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.orange)
                    }
                } else {
                    Text(session.totalPrice.formatted(.currency(code: "THB").presentation(.narrow)))
                        .font(.subheadline)
                        .bold()
                }
                
                if session.energyAdded > 0 {
                    Text(String(format: "฿%.2f/kWh", session.totalPrice / session.energyAdded))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.locationName ?? "Charging Session")\(session.vendorName != nil ? ", \(session.vendorName!)" : ""), \(session.date.formatted(.dateTime.month(.abbreviated).day().year().locale(Locale(identifier: "en_US_POSIX"))))")
        .accessibilityValue("\(session.chargingType?.rawValue ?? "") charging, \(String(format: "%.1f kWh", session.energyAdded)) added in \(String(format: "%.0f minutes", session.duration / 60)), \(session.totalPrice.formatted(.currency(code: "THB").presentation(.narrow)))\(session.paymentStatus == .deferred ? ", Deferred" : "")")
    }
    
    @ViewBuilder
    private func metricView(icon: String, text: String, color: Color = .secondary) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text(text)
        }
        .foregroundColor(color)
    }
}
