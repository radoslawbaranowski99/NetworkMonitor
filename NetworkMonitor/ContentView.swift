import SwiftUI
import Foundation
import UniformTypeIdentifiers

// Represent a CSV file for the system file exporter.
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.commaSeparatedText]
    }
    
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let content = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        text = content
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// Store the details of a single network check.
struct NetworkCheck: Identifiable, Codable, Equatable {
    var id = UUID()
    let date: Date
    let address: String
    let statusCode: Int?
    let durationMilliseconds: Double
    let errorMessage: String?
    
    // Build a readable description for the history list and text export.
    
    var summary: String {
        let timestamp = date.formatted(
            date: .abbreviated,
            time: .standard
        )
        
        if let errorMessage {
            return "\(timestamp) - \(address) - Error: \(errorMessage)"
        }
        
        let status = statusCode.map { String($0) } ?? "Unknown"
        return "\(timestamp) - \(address) - HTTP \(status) | Time: \(Int(durationMilliseconds)) ms "
    }
}
struct ContentView: View {
    // Remember the last entered address between app launches.
    @AppStorage("lastCheckedAddress") private var address = ""
    @State private var result = "Ready to check"
    @State private var isChecking = false
    @State private var resultColor: Color = .secondary
    @State private var history: [String] = []
    @State private var checks: [NetworkCheck] = []
    @State private var historySearch = ""
    @State private var exportText = ""
    @State private var showExport = false
    @State private var showCSVExporter = false
    @State private var csvDocument = CSVDocument(text: "")
    
    // Filter saved checks without changing the original history.
    private var filteredHistory: [String] {
        if historySearch.isEmpty {
            return history
        }
        
        return history.filter {
            $0.localizedCaseInsensitiveContains(historySearch)
        }
    }
    private var filteredChecks: [NetworkCheck] {
        if historySearch.isEmpty {
            return checks
        }
        
        return checks.filter {
            $0.summary.localizedCaseInsensitiveContains(historySearch)
        }
    }
    private let historyKey = "networkMonitorHistory"
    private let checksKey = "networkMonitorChecksV2"
    @State private var checkedAddress = ""
    @State private var latestCheck = ""
    @State private var showClearConfirmation = false
    
    // Build the main application interface.
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Network Monitor")
                .font(.title)
            
            TextField("Enter a domain, e.g. example.com", text: $address)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task {
                        await checkWebsite()
                    }
                }
            
            HStack(spacing: 12) {
                Button("Check") {
                    Task {
                        await checkWebsite()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isChecking)
                
                Button("Check Again") {
                    address = checkedAddress
                    
                    Task {
                        await checkWebsite()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isChecking || checkedAddress.isEmpty)
            }
            
            if isChecking {
                ProgressView()
                    .controlSize(.small)
            }
            Text(result)
                .font(.callout)
                .foregroundStyle(resultColor)
            
            Divider()
            
            Text("Recent Checks (\(filteredChecks.count)/\(checks.count))")
                .font(.headline)
            
            Menu("Export") {
                Button("Save All Checks as CSV") {
                    csvDocument = CSVDocument(text: makeCSV(from: checks))
                    showCSVExporter = true
                }
                .disabled(isChecking || checks.isEmpty)
                
                Divider()
                
                Button("Latest Check") {
                    exportText = latestCheck
                    showExport = true
                }
                .disabled(latestCheck.isEmpty)
                
                Button("All Checks") {
                    exportText = checks.map { $0.summary }
                        .joined(separator: "\n\n")
                    showExport = true
                }
                .disabled(checks.isEmpty)
                
                Button("Filtered Checks") {
                    exportText = filteredChecks.map { $0.summary }
                        .joined(separator: "\n\n")
                    showExport = true
                }
                .disabled(filteredChecks.isEmpty)
                
                Button("Previous Text History") {
                    exportText = history.joined(separator: "\n\n")
                    showExport = true
                }
                .disabled(history.isEmpty)
            }
            .disabled(isChecking)
            .sheet(isPresented: $showExport) {
                VStack(spacing: 16) {
                    Text("Export Results")
                        .font(.headline)
                    
                    ShareLink(item: exportText) {
                        Label("Share Results", systemImage: "square.and.arrow.up")
                    }
                    
                    Button("Done") {
                        showExport = false
                    }
                }
                .padding(24)
                .frame(minWidth: 300)
            }
            Button("Clear History") {
                showClearConfirmation = true
            }
            .disabled(isChecking || (history.isEmpty && checks.isEmpty))
            
            .alert("Clear all history?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                
                Button("Clear History", role: .destructive) {
                    history.removeAll()
                    checks.removeAll()
                    latestCheck = ""
                    checkedAddress = ""
                    exportText = ""
                    result = "Ready to check"
                    resultColor = .secondary
                }
            } message: {
                Text("This will permanently delete all saved checks.")
            }
            
            HStack {
                TextField("Search history", text: $historySearch)
                    .textFieldStyle(.roundedBorder)
                
                if !historySearch.isEmpty {
                    Button {
                        historySearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if checks.isEmpty {
                        Text("No structured checks yet.")
                            .foregroundStyle(.secondary)
                    } else if filteredChecks.isEmpty {
                        Text("No matching checks.")
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(filteredChecks) { check in Text(check.summary)
                            .textSelection(.enabled)
                    }
                    
                    if !filteredHistory.isEmpty {
                        Divider()
                        
                        Text("Previous Text History")
                            .font(.headline)
                        
                        ForEach(filteredHistory.indices, id: \.self) {index in Text(filteredHistory[index])
                                .textSelection(.enabled)
                        }
                    }
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 180)
        }
        .padding(24)
        .frame(minWidth: 360)
        .onAppear {
            loadHistory()
            loadChecks()
        }
        .onChange(of: history) {
            saveHistory()
        }
        .onChange(of: checks) {
            saveChecks()
        }
        .fileExporter(
            isPresented: $showCSVExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "network-checks.csv"
        ) { outcome in
            switch outcome {
            case .success:
                result = "CSV exported successfully"
                resultColor = .green
            case .failure(let error):
                result = "Export failed: \(error.localizedDescription)"
                resultColor = .red
            }
        }
    }
    
    // Quote CSV fields and escape quotation marks inside them.
    private func csvField(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"",  with: "\"\"") + "\""
    }
    
    // Convert structured checks into CSV rows.
    private func makeCSV(from entries: [NetworkCheck]) -> String {
        let header = "date,address,status_code,duration_ms,error"
        
        let rows = entries.map { check in
            let status = check.statusCode.map { String($0) } ?? ""
            
            let fields = [
                check.date.ISO8601Format(),
                check.address,
                status,
                String(check.durationMilliseconds),
                check.errorMessage ?? ""
            ]
            
            return fields.map { csvField($0) }.joined(separator: ",")
        }
        
        return ([header] + rows).joined(separator: "\r\n")
    }
    
    // Save history to the application's local settings.
    private func saveHistory() {
        UserDefaults.standard.set(history, forKey: historyKey)
    }
    
    // Restore saved history or start with an empty list.
    private func loadHistory() {
        history = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        
    }
    
    // Encode structured checks as JSON and save them locally.
    private func saveChecks() {
        do {
            let data = try JSONEncoder().encode(checks)
            UserDefaults.standard.set(data, forKey: checksKey)
        } catch {
            print("Could not save checks: \(error.localizedDescription)")
        }
    }
    
    // Restore structured checks from the saved JSON.
    private func loadChecks() {
        guard let data = UserDefaults.standard.data(forKey: checksKey) else {
            return
        }
        
        do {
            checks = try JSONDecoder().decode([NetworkCheck].self, from: data)
        } catch {
            print("Could not load checks: \(error.localizedDescription)")
        }
    }
    
    // Send an HTTPS HEAD request and record the response or connection error
    @MainActor
    private func checkWebsite() async {
        
        // Prevent multiple checks from running at the same time.
        guard !isChecking else { return }
        
        isChecking = true
        defer { isChecking = false }
        resultColor = .secondary
        
        let input = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !input.isEmpty else {
            resultColor = .red
            result = "Enter a domain first"
            return
        }
        
        // Add HTTPS when the user enters a domain without a scheme.
        let fullAddress = input.contains("://")
        ? input
        : "https://\(input)"
        
        guard let url = URL(string: fullAddress),
              url.scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            resultColor = .red
            result = "Enter a valid HTTPS URL"
            return
        }
        
        checkedAddress = fullAddress
        result = "Checking..."
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // Measure the total request duration including connection setup.
        let clock = ContinuousClock()
        let start = clock.now
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let response = response as? HTTPURLResponse {
                switch response.statusCode {
                case 200...299:
                    resultColor = .green
                case 300...399:
                    resultColor = .orange
                default:
                    resultColor = .red
                }
                let elapsed = start.duration(to: clock.now)
                let milliseconds = Double(elapsed.components.seconds) * 1_000
                + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
                let category: String
                
                switch response.statusCode {
                case 200...299:
                    category = "Success"
                case 300...399:
                    category = "Redirection"
                case 400...499:
                    category = "Client error"
                case 500...599:
                    category = "Server error"
                default:
                    category = "Other response"
                }
                result = "HTTP status: \(response.statusCode): \(category) | Time: \(Int(milliseconds)) ms"
                let check = NetworkCheck(
                    date: .now,
                    address: fullAddress,
                    statusCode: response.statusCode,
                    durationMilliseconds: milliseconds,
                    errorMessage: nil
                    
                )
                
                checks.insert(check, at:0)
                
                if checks.count > 100 {
                    checks = Array(checks.prefix(100))
                }
                
                latestCheck = "\(checkedAddress)\n\(result)"
                
            } else {
                resultColor = .red
                result = "Unexpected response"
            }
        } catch {
            resultColor = .red
            result = "Error: \(error.localizedDescription)"
            
            let elapsed = start.duration(to: clock.now)
            let milliseconds = Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
            
            let check = NetworkCheck(
                date: .now,
                address: fullAddress,
                statusCode: nil,
                durationMilliseconds: milliseconds,
                errorMessage: error.localizedDescription
            )
            
            checks.insert(check, at: 0)
            
            if checks.count > 100 {
                checks = Array(checks.prefix(100))
            }
            
            latestCheck = "\(checkedAddress)\n\(result)"
        }
    }
}
#Preview {
    ContentView()
}
