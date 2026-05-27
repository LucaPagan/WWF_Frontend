import Foundation
import SwiftData

enum LocalProgressStatus: String, Codable, CaseIterable {
    case inProgress = "in_progress"
    case completed
    case abandoned
}

enum LocalVisitSource: String, Codable, CaseIterable {
    case qr
    case numericCode = "numeric_code"
    case restored
}

@Model
final class LocalTrailProgress {
    @Attribute(.unique) var id: UUID
    var pathId: UUID
    var packageId: UUID?
    var statusRawValue: String
    var startedAt: Date
    var completedAt: Date?
    var updatedAt: Date
    var needsSync: Bool

    @Relationship(deleteRule: .cascade)
    var visits: [LocalPOIVisit]

    @Transient var status: LocalProgressStatus {
        get { LocalProgressStatus(rawValue: statusRawValue) ?? .inProgress }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        pathId: UUID,
        packageId: UUID? = nil,
        status: LocalProgressStatus = .inProgress,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.pathId = pathId
        self.packageId = packageId
        self.statusRawValue = status.rawValue
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = Date()
        self.needsSync = true
        self.visits = []
    }
}

@Model
final class LocalPOIVisit {
    @Attribute(.unique) var id: UUID
    var progressId: UUID
    var poiId: UUID
    var scannedAt: Date
    var sourceRawValue: String
    var qrPayload: String?

    @Transient var source: LocalVisitSource {
        get { LocalVisitSource(rawValue: sourceRawValue) ?? .qr }
        set { sourceRawValue = newValue.rawValue }
    }

    init(
        progressId: UUID,
        poiId: UUID,
        scannedAt: Date = Date(),
        source: LocalVisitSource = .qr,
        qrPayload: String? = nil,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.progressId = progressId
        self.poiId = poiId
        self.scannedAt = scannedAt
        self.sourceRawValue = source.rawValue
        self.qrPayload = qrPayload
    }
}

@Model
final class SyncOutboxItem {
    @Attribute(.unique) var id: UUID
    var kind: String
    var payloadData: Data
    var attemptCount: Int
    var lastAttemptAt: Date?
    var nextRetryAt: Date?
    var createdAt: Date

    init(kind: String, payloadData: Data, fixedID: UUID? = nil) {
        self.id = fixedID ?? UUID()
        self.kind = kind
        self.payloadData = payloadData
        self.attemptCount = 0
        self.lastAttemptAt = nil
        self.nextRetryAt = nil
        self.createdAt = Date()
    }
}

@Model
final class LocalBundleInstall {
    @Attribute(.unique) var id: UUID
    var packageId: UUID
    var pathId: UUID
    var tierRawValue: String
    var manifestSHA256: String
    var installPath: String
    var installedAt: Date
    var sizeBytes: Int64

    @Transient var tier: ContentTier {
        get { ContentTier(rawValue: tierRawValue) ?? .light }
        set { tierRawValue = newValue.rawValue }
    }

    init(
        packageId: UUID,
        pathId: UUID,
        tier: ContentTier,
        manifestSHA256: String,
        installPath: String,
        sizeBytes: Int64
    ) {
        self.id = UUID()
        self.packageId = packageId
        self.pathId = pathId
        self.tierRawValue = tier.rawValue
        self.manifestSHA256 = manifestSHA256
        self.installPath = installPath
        self.installedAt = Date()
        self.sizeBytes = sizeBytes
    }
}
