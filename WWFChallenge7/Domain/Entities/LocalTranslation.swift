//
//  LocalTranslation.swift
//  WWFChallenge7
//
//  Created by Antigravity on 17/05/26.
//

import Foundation
import SwiftData

@Model
final class LocalTranslation: @unchecked Sendable {
    var id: UUID
    var tableName: String
    var recordId: UUID
    var fieldName: String
    var languageCode: String
    var translatedText: String
    
    init(
        tableName: String,
        recordId: UUID,
        fieldName: String,
        languageCode: String,
        translatedText: String,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.tableName = tableName
        self.recordId = recordId
        self.fieldName = fieldName
        self.languageCode = languageCode
        self.translatedText = translatedText
    }
}
