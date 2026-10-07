//
//  LocalRepository.swift
//  ToDoDemoAPI
//

import Foundation
import SwiftData

public struct LocalRepository: TodoFetching, TodoSaving, TodoDeleting, Sendable {
    private let modelContext: TodoModelContext

    /// Test seam: inject a `TodoModelContext` (e.g. a throwing mock). Internal by design.
    init(modelContext: TodoModelContext) {
        self.modelContext = modelContext
    }

    /// Production: a repository backed by the app's on-disk SwiftData store.
    /// Callers never import SwiftData.
    public init() throws {
        let container = try ModelContainer(for: TodoItemModel.self)
        self.init(modelContext: SwiftDataModelContext(modelContainer: container))
    }

    public func fetchAll(offset: Int, limit: Int) async throws -> TodoItemPage {
        let rawItems = try await modelContext.fetchAll(offset: offset, limit: limit + 1)
        let hasMore = rawItems.count > limit
        let items = hasMore ? Array(rawItems.prefix(limit)) : rawItems
        return TodoItemPage(items: items, hasMore: hasMore)
    }

    public func save(_ item: TodoItem) async throws {
        try await modelContext.save(item)
    }

    public func delete(id: UUID) async throws {
        try await modelContext.delete(id: id)
    }
}
