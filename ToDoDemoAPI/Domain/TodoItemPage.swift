//
//  TodoItemPage.swift
//  ToDoDemoAPI
//

public struct TodoItemPage: Equatable, Sendable {
    public let items: [TodoItem]
    public let hasMore: Bool

    public init(items: [TodoItem], hasMore: Bool) {
        self.items = items
        self.hasMore = hasMore
    }
}
