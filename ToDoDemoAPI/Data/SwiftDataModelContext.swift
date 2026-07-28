//
//  SwiftDataModelContext.swift
//  ToDoDemoAPI
//
//  Production TodoModelContext seam backed by a real SwiftData ModelContext.
//  Internal — the module hides SwiftData behind LocalRepository's public API.
//
//  An actor because ModelContext is not safe to touch from multiple threads.
//  Isolation lives here, at the one place that actually holds the unsafe
//  resource — not on TodoFetching/TodoSaving/TodoModelContext, which stay
//  plain protocols so non-SwiftData conformers (e.g. the test mock) aren't
//  forced to be actors too.
//
//  TodoItemModel <-> TodoItem mapping happens inside this actor so only the
//  Sendable TodoItem crosses the isolation boundary — TodoItemModel is a
//  mutable, non-Sendable @Model class and must never cross it.
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataModelContext: TodoModelContext {
    func fetchAll(offset: Int, limit: Int) throws -> [TodoItem] {
        var descriptor = FetchDescriptor<TodoItemModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map { model in
            TodoItem(
                id: model.id,
                title: model.title,
                isCompleted: model.isCompleted,
                createdAt: model.createdAt
            )
        }
    }

    func save(_ item: TodoItem) throws {
        let model = TodoItemModel(
            id: item.id,
            title: item.title,
            isCompleted: item.isCompleted,
            createdAt: item.createdAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }
}
