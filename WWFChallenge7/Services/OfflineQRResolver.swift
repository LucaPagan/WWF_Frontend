import Foundation

enum OfflineQRResolution: Equatable {
    case trailPOI(POI)
    case globalAlert(POI)
    case notInDownloadedTrail
    case unknown
    case alreadyVisited
}

struct OfflineQRResolver {
    let trail: Trail
    let globalAlerts: [POI]
    let completedPOIIds: Set<UUID>

    func resolve(payload: String) -> OfflineQRResolution {
        resolve(clean: payload.trimmingCharacters(in: .whitespacesAndNewlines), numeric: false)
    }

    func resolve(numericCode: String) -> OfflineQRResolution {
        resolve(clean: numericCode.trimmingCharacters(in: .whitespacesAndNewlines), numeric: true)
    }

    private func resolve(clean: String, numeric: Bool) -> OfflineQRResolution {
        guard !clean.isEmpty else { return .unknown }

        let pathPOIs = trail.sortedSteps.compactMap { $0.poi }
        if let poi = pathPOIs.first(where: { numeric ? $0.numericCode == clean : $0.qrPayload == clean }) {
            if completedPOIIds.contains(poi.id) {
                return .alreadyVisited
            }
            return .trailPOI(poi)
        }

        if let alert = globalAlerts.first(where: { numeric ? $0.numericCode == clean : $0.qrPayload == clean }) {
            return .globalAlert(alert)
        }

        return .unknown
    }
}

extension POIType {
    var isGlobalAlertType: Bool {
        self == .warning || self == .danger || self == .info
    }
}
