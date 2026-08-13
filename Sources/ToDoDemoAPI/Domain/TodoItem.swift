//
//  TodoItem.swift
//  ToDoDemoAPI
//

import Foundation

public struct TodoItem: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let isCompleted: Bool
    public let createdAt: Date

    public init(id: UUID, title: String, isCompleted: Bool, createdAt: Date) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
