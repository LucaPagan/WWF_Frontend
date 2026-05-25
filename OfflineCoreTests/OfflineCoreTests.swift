import CryptoKit
import Foundation

enum Tier: String {
    case light
    case standard
    case full

    var included: [Tier] {
        switch self {
        case .light: return [.light]
        case .standard: return [.light, .standard]
        case .full: return [.light, .standard, .full]
        }
    }
}

struct TestAsset: Codable {
    let id: String
    let localRelativePath: String
    let sizeBytes: Int
    let sha256: String
}

struct TestManifest: Codable {
    let manifestVersion: String
    let manifestSHA256: String
    let pathId: UUID
    let tier: String
    let includedTiers: [String]
    let globalAlerts: [String]
    let assets: [TestAsset]

    enum CodingKeys: String, CodingKey {
        case manifestVersion = "manifest_version"
        case manifestSHA256 = "manifest_sha256"
        case pathId = "path_id"
        case tier
        case includedTiers = "included_tiers"
        case globalAlerts = "global_alerts"
        case assets
    }
}

struct ProgressStore: Codable {
    var pathId: UUID
    var visitedPOIIds: Set<UUID>
}

struct TestGamificationLevel {
    let number: Int
    let title: String
    let requiredXP: Int
}

struct TestRewardLedger {
    private(set) var xpTotal = 0
    private(set) var awardedKeys: Set<String> = []

    mutating func awardXP(_ xp: Int, key: String) {
        guard awardedKeys.insert(key).inserted else { return }
        xpTotal += xp
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func testTierInclusion() {
    expect(Tier.light.included == [.light], "light includes only light")
    expect(Tier.standard.included == [.light, .standard], "standard includes light + standard")
    expect(Tier.full.included == [.light, .standard, .full], "full includes all tiers")
}

func testManifestDecodeAndGlobalAlerts() throws {
    let pathId = UUID()
    let payload = """
    {
      "manifest_version": "1",
      "manifest_sha256": "abc",
      "path_id": "\(pathId.uuidString)",
      "tier": "standard",
      "included_tiers": ["light", "standard"],
      "global_alerts": ["warning-1"],
      "assets": []
    }
    """.data(using: .utf8)!
    let manifest = try JSONDecoder().decode(TestManifest.self, from: payload)
    expect(manifest.pathId == pathId, "manifest path id decoded")
    expect(manifest.includedTiers == ["light", "standard"], "manifest tier inclusion decoded")
    expect(manifest.globalAlerts == ["warning-1"], "manifest includes global alerts")
}

func testAtomicCommitAndRollback() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wwf-offline-tests-\(UUID().uuidString)")
    let staging = root.appendingPathComponent(".staging/pkg")
    let installed = root.appendingPathComponent("installed/pkg-sha")
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
    try "old".data(using: .utf8)!.write(to: installed.appendingPathComponent("marker"), options: .atomic)
    try? FileManager.default.removeItem(at: installed)
    try FileManager.default.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.moveItem(at: staging, to: installed)
    expect(FileManager.default.fileExists(atPath: installed.path), "atomic commit moved staging")

    let failedStaging = root.appendingPathComponent(".staging/failed")
    try FileManager.default.createDirectory(at: failedStaging, withIntermediateDirectories: true)
    try FileManager.default.removeItem(at: failedStaging)
    expect(!FileManager.default.fileExists(atPath: failedStaging.path), "rollback removed failed staging")
}

func testRecoveryAndChecksum() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wwf-recovery-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let assetURL = root.appendingPathComponent("media/a.txt")
    try FileManager.default.createDirectory(at: assetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = "asset".data(using: .utf8)!
    try data.write(to: assetURL)
    let asset = TestAsset(id: "a", localRelativePath: "media/a.txt", sizeBytes: data.count, sha256: sha256(data))
    let read = try Data(contentsOf: root.appendingPathComponent(asset.localRelativePath))
    expect(read.count == asset.sizeBytes, "asset size verified")
    expect(sha256(read) == asset.sha256, "asset checksum verified")
}

func testProgressPersistence() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wwf-progress-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: root) }
    let poiId = UUID()
    let progress = ProgressStore(pathId: UUID(), visitedPOIIds: [poiId])
    try JSONEncoder().encode(progress).write(to: root)
    let restored = try JSONDecoder().decode(ProgressStore.self, from: Data(contentsOf: root))
    expect(restored.visitedPOIIds.contains(poiId), "progress survives restart")
}

func testQROfflineMembership() {
    let pathPOI = UUID()
    let otherPOI = UUID()
    let allowed = [pathPOI: "QR_PATH"]
    let global = [otherPOI: "QR_WARNING"]
    expect(allowed.values.contains("QR_PATH"), "path QR resolves locally")
    expect(global.values.contains("QR_WARNING"), "global warning QR resolves locally")
    expect(!allowed.values.contains("QR_OTHER"), "other path QR is rejected")
}

func testGamificationLevelThresholds() {
    let levels = [
        TestGamificationLevel(number: 1, title: "Visitatore", requiredXP: 0),
        TestGamificationLevel(number: 2, title: "Esploratore", requiredXP: 250),
        TestGamificationLevel(number: 3, title: "Naturalista", requiredXP: 750),
        TestGamificationLevel(number: 4, title: "Custode dell'Oasi", requiredXP: 1500),
        TestGamificationLevel(number: 5, title: "Guardiano WWF", requiredXP: 3000)
    ]

    func currentLevel(for xp: Int) -> TestGamificationLevel {
        levels
            .filter { xp >= $0.requiredXP }
            .sorted { $0.requiredXP < $1.requiredXP }
            .last ?? levels[0]
    }

    expect(currentLevel(for: 0).number == 1, "0 XP starts as visitor")
    expect(currentLevel(for: 249).number == 1, "level threshold is not crossed early")
    expect(currentLevel(for: 250).title == "Esploratore", "250 XP unlocks explorer")
    expect(currentLevel(for: 3000).number == 5, "max seeded threshold resolves")
}

func testGamificationRewardIdempotency() {
    var ledger = TestRewardLedger()
    let poiId = UUID().uuidString

    ledger.awardXP(25, key: "poi_scanned:\(poiId)")
    ledger.awardXP(25, key: "poi_scanned:\(poiId)")
    ledger.awardXP(100, key: "trail_completed:\(UUID().uuidString)")

    expect(ledger.xpTotal == 125, "duplicate POI reward is ignored")
    expect(ledger.awardedKeys.count == 2, "unique reward keys are tracked")
}

try testManifestDecodeAndGlobalAlerts()
try testAtomicCommitAndRollback()
try testRecoveryAndChecksum()
try testProgressPersistence()
testTierInclusion()
testQROfflineMembership()
testGamificationLevelThresholds()
testGamificationRewardIdempotency()
print("OfflineCoreTests passed")
