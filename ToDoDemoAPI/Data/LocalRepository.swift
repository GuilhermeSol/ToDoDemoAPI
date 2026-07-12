//
//  LocalRepository.swift
//  ToDoDemoAPI
//

import Foundation
import SwiftData

public struct LocalRepository: TodoRepository {
    private let modelContext: TodoModelContext

    /// Test seam: inject a `TodoModelContext` (e.g. a throwing mock). Internal by design.
    init(modelContext: TodoModelContext) {
        self.modelContext = modelContext
    }

    /// Production: a repository backed by the app's on-disk SwiftData store.
    /// Callers never import SwiftData.
    public init() throws {
        let container = try ModelContainer(for: TodoItemModel.self)
        self.init(modelContext: SwiftDataModelContext(context: ModelContext(container)))
    }

    public func fetchAll() async throws -> [TodoItem] {
        try modelContext.fetchAll().map { model in
            TodoItem(
                id: model.id,
                title: model.title,
                isCompleted: model.isCompleted,
                createdAt: model.createdAt
            )
        }
    }
}
