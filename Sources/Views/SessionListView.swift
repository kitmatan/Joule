import SwiftUI
import UniformTypeIdentifiers

enum SessionFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "All"
    case ac = "AC Only"
    case dc = "DC Only"
    case home = "Home"
    case publicStation = "Public"
    case work = "Work"
    case deferred = "Deferred Payment"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .ac: return "powerplug"
        case .dc: return "bolt.fill"
        case .home: return "house"
        case .publicStation: return "mappin.and.ellipse"
        case .work: return "briefcase"
        case .deferred: return "list.bullet.rectangle.portrait"
        }
    }

    /// Short label for the History filter chips.
    var chipTitle: String {
        switch self {
        case .all: return "All"
        case .ac: return "AC"
        case .dc: return "DC"
        case .home: return "Home"
        case .publicStation: return "Public"
        case .work: return "Work"
        case .deferred: return "On bill"
        }
    }

    /// Display name used in the macOS sidebar.
    var sidebarTitle: String {
        self == .all ? String(localized: "All Sessions") : rawValue
    }

    func matches(_ session: ChargingSession) -> Bool {
        switch self {
        case .all: return true
        case .ac: return session.chargingType == .ac
        case .dc: return session.chargingType == .dc
        case .home: return session.locationType == .home
        case .publicStation: return session.locationType == .publicStation
        case .work: return session.locationType == .work
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
    @State private var showingPDFExporter = false
    @State private var sessionToDelete: ChargingSession?
    @State private var csvDocument: CSVDocument?
    @State private var pdfDocument: PDFFileDocument?
    @State private var searchText = ""
    @State private var filter: SessionFilter = .all
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    @AppStorage("app_currency") private var appCurrency: AppCurrency = VehicleProfile.defaultCurrency

    var displayedSessions: [ChargingSession] {
        store.sessions(for: store.selectedVehicleId)
    }

    var filteredSessions: [ChargingSession] {
        displayedSessions.filter { session in
            guard filter.matches(session) else { return false }
            guard !searchText.isEmpty else { return true }
            let vehicleName = session.vehicleId.flatMap { store.vehicleName(for: $0) }
            let haystack = [session.locationName, session.vendorName, session.notes, vehicleName]
                .compactMap { $0 }
                .joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Group sessions by Month and Year (e.g., "July 2026")
    var groupedSessions: [(String, [ChargingSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            session.date.formatted(.dateTime.year().month(.wide))
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
                // The title lives in the content, not the bar: a `navigationTitle` collapses into
                // the bar on scroll, where the garage switcher and actions leave it no room and it
                // truncates. Here it simply scrolls away. Matches DashboardView, which also runs
                // with an empty navigation title.
                Text("History")
                    .font(.jouleDisplay(34, relativeTo: .largeTitle))
                    .foregroundStyle(Color.jouleInk)
                    .accessibilityAddTraits(.isHeader)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))

                filterChips
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))

                if store.duplicateSessionsCount > 0 {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                                .font(.joule(.title3))
                                .foregroundColor(.jouleDeferred)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: String(localized: "%lld Duplicate Sessions Found"), Int64(store.duplicateSessionsCount)))
                                    .font(.joule(.subheadline))
                                    .fontWeight(.medium)
                                Text("Merge data into canonical records and remove duplicates.")
                                    .font(.joule(.caption))
                                    .foregroundColor(.jouleMuted)
                            }
                            Spacer()
                            Button("Clean Up") {
                                store.cleanDuplicates()
                            }
                            .font(.joule(.caption))
                            .fontWeight(.semibold)
                            .buttonStyle(JouleOutlineButtonStyle())
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.jouleDeferredSoft)
                }

                ForEach(groupedSessions, id: \.0) { month, sessions in
                    Section {
                        ForEach(sessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                SessionRow(session: session)
                            }
                            .listRowBackground(Color.jouleSurface)
                            .listRowSeparatorTint(Color.jouleLine)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(month)
                                .font(.jouleDisplay(18, relativeTo: .headline))
                                .foregroundStyle(Color.jouleInk)
                            Spacer()
                            Text(appCurrency.format(sessions.reduce(0) { $0 + $1.totalPrice }) + " · " + String(format: "%.1f kWh", sessions.reduce(0) { $0 + $1.energyAdded }))
                                .font(.jouleMono(12))
                                .foregroundStyle(Color.jouleInk2)
                        }
                        .textCase(nil)
                        .padding(.bottom, 2)
                    }
                }
            }
            .jouleTabBarClearance()
            .joulePage()
            .searchable(text: $searchText, prompt: "Search location, vendor, notes")
            .overlay {
                if store.sessions.isEmpty {
                    VStack(spacing: 20) {
                        Text("No charging history yet.")
                            .foregroundColor(.jouleMuted)
                        Button("Add Charging Session") {
                            navCoordinator.presentNewSession()
                        }
                        .buttonStyle(JoulePrimaryButtonStyle())
                        .frame(maxWidth: 280)
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
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GarageSwitcherMenu(allowAllOption: true)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Menu {
                            Picker("Filter", selection: $filter) {
                                ForEach(SessionFilter.allCases) { option in
                                    Text(LocalizedStringKey(option.rawValue)).tag(option)
                                }
                            }
                            Divider()
                            if store.duplicateSessionsCount > 0 {
                                Button(action: { store.cleanDuplicates() }) {
                                    Label(String(format: String(localized: "Clean Up Duplicates (%lld)"), Int64(store.duplicateSessionsCount)), systemImage: "sparkles.rectangle.stack")
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
                                Label("Export All to CSV…", systemImage: "square.and.arrow.up")
                            }
                            .keyboardShortcut("e", modifiers: .command)

                            Button(action: {
                                let pdfData = PDFReportGenerator.generatePDF(
                                    sessions: filteredSessions,
                                    vehicle: store.activeVehicle,
                                    currency: appCurrency,
                                    unitSystem: unitSystem,
                                    title: "EV Charging Expense Statement - \(store.activeVehicle.name)",
                                    dateRangeTitle: filter == .all ? "All Sessions" : filter.rawValue
                                )
                                pdfDocument = PDFFileDocument(data: pdfData)
                                showingPDFExporter = true
                            }) {
                                Label("Export Reimbursement PDF…", systemImage: "doc.text.fill")
                            }

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
                Text("Are you sure you want to delete the charging session at \(session.locationName ?? "this location") on \(session.date.formatted(.dateTime.month(.abbreviated).day().year()))?")
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "Joule_Export"
            ) { _ in }
            .fileExporter(
                isPresented: $showingPDFExporter,
                document: pdfDocument,
                contentType: .pdf,
                defaultFilename: "Joule_Reimbursement_\(store.activeVehicle.name.replacingOccurrences(of: " ", with: "_"))"
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


    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SessionFilter.allCases) { option in
                    JouleChip(title: LocalizedStringKey(option.chipTitle), isSelected: filter == option) {
                        filter = option
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter")
    }
}

struct SessionRow: View {
    @EnvironmentObject private var store: SessionStore
    let session: ChargingSession
    @AppStorage("app_currency") private var appCurrency: AppCurrency = VehicleProfile.defaultCurrency

    /// Energy added as a share of the session vehicle's pack — the length of the row's bar.
    private var packShare: Double {
        let pack = store.vehicle(for: session.vehicleId)?.nominalCapacityKWh ?? store.activeVehicle.nominalCapacityKWh
        return pack > 0 ? session.energyAdded / pack : 0
    }

    private var meta: String {
        var parts: [String] = []
        if let vendor = session.vendorName, !vendor.isEmpty { parts.append(vendor) }
        parts.append(session.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
        if session.duration > 0 { parts.append(String(format: String(localized: "%.0f min"), session.duration / 60)) }
        if session.speed > 0 { parts.append(String(format: "%.0f kW", session.speed)) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ChargeTypeBadge(type: session.chargingType)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.locationName ?? String(localized: "Unknown Location"))
                            .font(.jouleText(16, relativeTo: .headline).weight(.semibold))
                            .foregroundStyle(Color.jouleInk)
                            .lineLimit(1)

                        if store.vehicles.count > 1, let vId = session.vehicleId, !vId.isEmpty {
                            Text(store.vehicleName(for: vId))
                                .font(.jouleText(11, relativeTo: .caption2).weight(.semibold))
                                .foregroundStyle(Color.jouleInk2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.jouleSunken, in: Capsule())
                                .lineLimit(1)
                        }
                    }
                    Text(meta)
                        .font(.jouleText(13, relativeTo: .footnote))
                        .foregroundStyle(Color.jouleMuted)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    ShareBar(fraction: packShare, color: session.chargingType?.jouleColor ?? .jouleMuted)
                    Text(String(format: "%.1f kWh", session.energyAdded))
                        .font(.jouleMono(12))
                        .foregroundStyle(Color.jouleInk2)
                        .fixedSize()
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                Text(appCurrency.format(session.totalPrice))
                    .font(.jouleText(16, relativeTo: .headline).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.jouleInk)
                if session.energyAdded > 0 {
                    Text(appCurrency.formatRate(session.totalPrice / session.energyAdded))
                        .font(.jouleMono(11))
                        .foregroundStyle(Color.jouleMuted)
                }
                if session.paymentStatus == .deferred {
                    JouleTag("On bill", foreground: .jouleDeferredOnSoft, background: .jouleDeferredSoft)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.locationName ?? "Charging Session")\(session.vendorName != nil ? ", \(session.vendorName!)" : ""), \(session.date.formatted(.dateTime.month(.abbreviated).day().year()))")
        .accessibilityValue("\(session.chargingType?.rawValue ?? "") charging, \(String(format: "%.1f kWh", session.energyAdded)) added in \(String(format: "%.0f minutes", session.duration / 60)), \(appCurrency.format(session.totalPrice))\(session.paymentStatus == .deferred ? ", Deferred" : "")")
    }
}
