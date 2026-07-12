//
//  TodoItemModel.swift
//  ToDoDemoAPI
//

import Foundation
import SwiftData

@Model
final class TodoItemModel {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date

    init(id: UUID, title: String, isCompleted: Bool, createdAt: Date) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
