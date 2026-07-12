//
//  LocalRepositoryTests.swift
//  ToDoDemoAPITests
//

import Foundation
import Testing
@testable import ToDoDemoAPI

struct LocalRepositoryTests {

    @Test func fetchAllOnEmptyStoreReturnsEmptyList() async throws {
        let repo = makeRepository(models: [])

        let result = try await repo.fetchAll()

        #expect(result.isEmpty)
    }

    @Test func fetchAllReturnsSingleItem() async throws {
        let model = makeModel(title: "Buy milk", isCompleted: true)
        let repo = makeRepository(models: [model])

        let result = try await repo.fetchAll()

        #expect(result == [expected(from: model)])
    }

    @Test func fetchAllReturnsAllPersistedItems() async throws {
        let models = [
            makeModel(title: "A", createdAt: Date(timeIntervalSince1970: 1)),
            makeModel(title: "B", isCompleted: true, createdAt: Date(timeIntervalSince1970: 2)),
            makeModel(title: "C", createdAt: Date(timeIntervalSince1970: 3))
        ]
        let repo = makeRepository(models: models)

        let result = try await repo.fetchAll()

        #expect(result.count == models.count)
        for model in models {
            #expect(result.contains(expected(from: model)))
        }
    }

    @Test func fetchAllPropagatesRawReadError() async throws {
        let repo = makeRepository(error: ReadFailure())

        await #expect(throws: ReadFailure.self) {
            _ = try await repo.fetchAll()
        }
    }
}

// MARK: - Helpers

private extension LocalRepositoryTests {

    func makeRepository(models: [TodoItemModel] = [], error: Error? = nil) -> LocalRepository {
        LocalRepository(modelContext: MockTodoModelContext(models: models, error: error))
    }

    func makeModel(
        id: UUID = UUID(),
        title: String = "Task",
        isCompleted: Bool = false,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> TodoItemModel {
        TodoItemModel(id: id, title: title, isCompleted: isCompleted, createdAt: createdAt)
    }

    func expected(from model: TodoItemModel) -> TodoItem {
        TodoItem(
            id: model.id,
            title: model.title,
            isCompleted: model.isCompleted,
            createdAt: model.createdAt
        )
    }
}

// MARK: - Test doubles

private struct ReadFailure: Error {}

private struct MockTodoModelContext: TodoModelContext {
    var models: [TodoItemModel] = []
    var error: Error?

    func fetchAll() throws -> [TodoItemModel] {
        if let error { throw error }
        return models
    }
}
