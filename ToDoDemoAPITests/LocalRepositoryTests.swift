//
//  LocalRepositoryTests.swift
//  ToDoDemoAPITests
//

import Foundation
import Testing
@testable import ToDoDemoAPI

struct LocalRepositoryTests {

    @Test func fetchAllOnEmptyStoreReturnsEmptyList() async throws {
        let repo = makeRepository(items: [])

        let result = try await repo.fetchAll()

        #expect(result.isEmpty)
    }

    @Test func fetchAllReturnsSingleItem() async throws {
        let item = makeItem(title: "Buy milk", isCompleted: true)
        let repo = makeRepository(items: [item])

        let result = try await repo.fetchAll()

        #expect(result == [item])
    }

    @Test func fetchAllReturnsAllPersistedItems() async throws {
        let items = [
            makeItem(title: "A", createdAt: Date(timeIntervalSince1970: 1)),
            makeItem(title: "B", isCompleted: true, createdAt: Date(timeIntervalSince1970: 2)),
            makeItem(title: "C", createdAt: Date(timeIntervalSince1970: 3))
        ]
        let repo = makeRepository(items: items)

        let result = try await repo.fetchAll()

        #expect(result.count == items.count)
        for item in items {
            #expect(result.contains(item))
        }
    }

    @Test func fetchAllPropagatesRawReadError() async throws {
        let repo = makeRepository(fetchError: ReadFailure())

        await #expect(throws: ReadFailure.self) {
            _ = try await repo.fetchAll()
        }
    }

    @Test func testSavePropagatesRawWriteErrorWhenStoreUnavailable() async throws {
        let mock = MockTodoModelContext()
        mock.saveError = WriteFailure()
        let repo = LocalRepository(modelContext: mock)
        let item = makeItem()

        await #expect(throws: WriteFailure.self) {
            try await repo.save(item)
        }
    }

    @Test func testSavePropagatesRawWriteErrorWhenStoreFull() async throws {
        let mock = MockTodoModelContext()
        mock.saveError = WriteFailure()
        let repo = LocalRepository(modelContext: mock)
        let item = makeItem()

        await #expect(throws: WriteFailure.self) {
            try await repo.save(item)
        }
        #expect(mock.items.isEmpty)
    }

    @Test func testSaveMultipleDistinctItemsStoresAllIndependently() async throws {
        let mock = MockTodoModelContext()
        let repo = LocalRepository(modelContext: mock)
        let items = [
            makeItem(title: "A", createdAt: Date(timeIntervalSince1970: 1)),
            makeItem(title: "B", isCompleted: true, createdAt: Date(timeIntervalSince1970: 2)),
            makeItem(title: "C", createdAt: Date(timeIntervalSince1970: 3))
        ]

        for item in items {
            try await repo.save(item)
        }
        let fetched = try await repo.fetchAll()

        #expect(fetched.count == items.count)
        for item in items {
            #expect(fetched.contains(item))
        }
    }

    @Test func testSaveNewItemStoresAndIsRetrievable() async throws {
        let mock = MockTodoModelContext()
        let repo = LocalRepository(modelContext: mock)
        let item = makeItem(title: "Buy milk", isCompleted: true, createdAt: Date(timeIntervalSince1970: 42))

        try await repo.save(item)
        let fetched = try await repo.fetchAll()

        #expect(fetched.count == 1)
        #expect(fetched == [item])
    }

    @Test func testFailedUpsertLeavesPreviousRecordIntact() async throws {
        let existingItem = makeItem(title: "Original title")
        let mock = MockTodoModelContext(items: [existingItem])
        mock.saveError = WriteFailure()
        let repo = LocalRepository(modelContext: mock)
        let item = makeItem(id: existingItem.id, title: "Corrupted title")

        await #expect(throws: WriteFailure.self) {
            try await repo.save(item)
        }
        #expect(mock.items == [existingItem])
    }
}

// MARK: - Helpers

private extension LocalRepositoryTests {

    func makeRepository(items: [TodoItem] = [], fetchError: Error? = nil) -> LocalRepository {
        LocalRepository(modelContext: MockTodoModelContext(items: items, fetchError: fetchError))
    }

    func makeItem(
        id: UUID = UUID(),
        title: String = "Task",
        isCompleted: Bool = false,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> TodoItem {
        TodoItem(id: id, title: title, isCompleted: isCompleted, createdAt: createdAt)
    }
}

// MARK: - Test doubles

private struct ReadFailure: Error {}
private struct WriteFailure: Error {}

private final class MockTodoModelContext: TodoModelContext {
    var items: [TodoItem]
    var fetchError: Error?
    var saveError: Error?

    init(items: [TodoItem] = [], fetchError: Error? = nil) {
        self.items = items
        self.fetchError = fetchError
    }

    func fetchAll() async throws -> [TodoItem] {
        if let fetchError { throw fetchError }
        return items
    }

    func save(_ item: TodoItem) async throws {
        if let saveError { throw saveError }
        items.append(item)
    }
}
