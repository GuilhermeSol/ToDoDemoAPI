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

        let result = try await repo.fetchAll(offset: 0, limit: 10)

        #expect(result.items.isEmpty)
        #expect(result.hasMore == false)
    }

    @Test func fetchAllReturnsSingleItem() async throws {
        let item = makeItem(title: "Buy milk", isCompleted: true)
        let repo = makeRepository(items: [item])

        let result = try await repo.fetchAll(offset: 0, limit: 10)

        #expect(result.items == [item])
    }

    @Test func fetchAllReturnsAllPersistedItems() async throws {
        let items = [
            makeItem(title: "C", createdAt: Date(timeIntervalSince1970: 3)),
            makeItem(title: "A", createdAt: Date(timeIntervalSince1970: 1)),
            makeItem(title: "E", createdAt: Date(timeIntervalSince1970: 5)),
            makeItem(title: "B", isCompleted: true, createdAt: Date(timeIntervalSince1970: 2)),
            makeItem(title: "D", createdAt: Date(timeIntervalSince1970: 4))
        ]
        let repo = makeRepository(items: items)

        let result = try await repo.fetchAll(offset: 0, limit: 10)

        #expect(result.items.count == items.count)
        for item in items {
            #expect(result.items.contains(item))
        }
    }

    @Test func fetchAllSequentialPagesConcatenateInStableOrderWithNoDuplicatesOrGaps() async throws {
        let items = [
            makeItem(title: "C", createdAt: Date(timeIntervalSince1970: 3)),
            makeItem(title: "A", createdAt: Date(timeIntervalSince1970: 1)),
            makeItem(title: "E", createdAt: Date(timeIntervalSince1970: 5)),
            makeItem(title: "B", isCompleted: true, createdAt: Date(timeIntervalSince1970: 2)),
            makeItem(title: "D", createdAt: Date(timeIntervalSince1970: 4))
        ]
        let repo = makeRepository(items: items)
        let pageSize = 2

        var fetchedPages: [TodoItem] = []
        var offset = 0
        var hasMore = true
        while hasMore {
            let page = try await repo.fetchAll(offset: offset, limit: pageSize)
            fetchedPages.append(contentsOf: page.items)
            hasMore = page.hasMore
            offset += pageSize
        }

        let expectedOrder = items.sorted { $0.createdAt < $1.createdAt }
        #expect(fetchedPages == expectedOrder)
        #expect(Set(fetchedPages.map(\.id)).count == fetchedPages.count)
    }

    @Test func fetchAllReturnsFirstPageWithHasMoreTrue() async throws {
        let items = [
            makeItem(title: "D", createdAt: Date(timeIntervalSince1970: 4)),
            makeItem(title: "A", createdAt: Date(timeIntervalSince1970: 1)),
            makeItem(title: "E", createdAt: Date(timeIntervalSince1970: 5)),
            makeItem(title: "B", createdAt: Date(timeIntervalSince1970: 2)),
            makeItem(title: "C", createdAt: Date(timeIntervalSince1970: 3))
        ]
        let repo = makeRepository(items: items)

        let result = try await repo.fetchAll(offset: 0, limit: 3)

        let sortedItems = items.sorted { $0.createdAt < $1.createdAt }
        #expect(result.items == Array(sortedItems.prefix(3)))
        #expect(result.hasMore == true)
    }

    @Test func fetchAllReturnsFinalPageWithHasMoreFalse() async throws {
        let items = [
            makeItem(title: "D", createdAt: Date(timeIntervalSince1970: 4)),
            makeItem(title: "A", createdAt: Date(timeIntervalSince1970: 1)),
            makeItem(title: "E", createdAt: Date(timeIntervalSince1970: 5)),
            makeItem(title: "B", createdAt: Date(timeIntervalSince1970: 2)),
            makeItem(title: "C", createdAt: Date(timeIntervalSince1970: 3))
        ]
        let repo = makeRepository(items: items)

        let result = try await repo.fetchAll(offset: 3, limit: 3)

        let sortedItems = items.sorted { $0.createdAt < $1.createdAt }
        #expect(result.items == Array(sortedItems.suffix(2)))
        #expect(result.hasMore == false)
    }

    @Test func fetchAllExactlyConsumingStoreReportsNoMoreOnSameCall() async throws {
        let items = [
            makeItem(title: "A", createdAt: Date(timeIntervalSince1970: 1)),
            makeItem(title: "B", createdAt: Date(timeIntervalSince1970: 2)),
            makeItem(title: "C", createdAt: Date(timeIntervalSince1970: 3))
        ]
        let repo = makeRepository(items: items)

        let result = try await repo.fetchAll(offset: 0, limit: 3)

        #expect(result.items.count == 3)
        #expect(result.items == items)
        #expect(result.hasMore == false)
    }

    @Test func fetchAllOffsetBeyondStoredCountReturnsEmptyPage() async throws {
        let items = [
            makeItem(title: "A", createdAt: Date(timeIntervalSince1970: 1)),
            makeItem(title: "B", createdAt: Date(timeIntervalSince1970: 2)),
            makeItem(title: "C", createdAt: Date(timeIntervalSince1970: 3)),
            makeItem(title: "D", createdAt: Date(timeIntervalSince1970: 4)),
            makeItem(title: "E", createdAt: Date(timeIntervalSince1970: 5))
        ]
        let repo = makeRepository(items: items)

        let result = try await repo.fetchAll(offset: 10, limit: 3)

        #expect(result.items.isEmpty)
        #expect(result.hasMore == false)
    }

    @Test func fetchAllPropagatesRawReadError() async throws {
        let repo = makeRepository(fetchError: ReadFailure())

        await #expect(throws: ReadFailure.self) {
            _ = try await repo.fetchAll(offset: 0, limit: 10)
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
        let fetched = try await repo.fetchAll(offset: 0, limit: 10)

        #expect(fetched.items.count == items.count)
        for item in items {
            #expect(fetched.items.contains(item))
        }
    }

    @Test func testSaveNewItemStoresAndIsRetrievable() async throws {
        let mock = MockTodoModelContext()
        let repo = LocalRepository(modelContext: mock)
        let item = makeItem(title: "Buy milk", isCompleted: true, createdAt: Date(timeIntervalSince1970: 42))

        try await repo.save(item)
        let fetched = try await repo.fetchAll(offset: 0, limit: 10)

        #expect(fetched.items.count == 1)
        #expect(fetched.items == [item])
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

    @Test func testDeleteOnEmptyStoreCompletesWithoutError() async throws {
        let mock = MockTodoModelContext()
        let repo = LocalRepository(modelContext: mock)

        try await repo.delete(id: UUID())

        #expect(mock.items.isEmpty)
    }

    @Test func testDeleteNonMatchingIdLeavesExistingItemIntact() async throws {
        let item = makeItem()
        let mock = MockTodoModelContext(items: [item])
        let repo = LocalRepository(modelContext: mock)

        try await repo.delete(id: UUID())

        #expect(mock.items == [item])
    }

    @Test func testDeleteAlreadyDeletedItemIsIdempotent() async throws {
        let item = makeItem()
        let mock = MockTodoModelContext(items: [item])
        let repo = LocalRepository(modelContext: mock)

        try await repo.delete(id: item.id)
        try await repo.delete(id: item.id)

        #expect(mock.items.isEmpty)
    }

    @Test func testDeleteExistingItemRemovesItAndIsNoLongerFetchable() async throws {
        let item = makeItem()
        let mock = MockTodoModelContext(items: [item])
        let repo = LocalRepository(modelContext: mock)

        try await repo.delete(id: item.id)
        let result = try await repo.fetchAll(offset: 0, limit: 10)

        #expect(result.items.isEmpty)
    }

    @Test func testDeleteOneOfMultipleItemsRemovesOnlyThatItem() async throws {
        let itemA = makeItem(title: "A", createdAt: Date(timeIntervalSince1970: 1))
        let itemB = makeItem(title: "B", createdAt: Date(timeIntervalSince1970: 2))
        let itemC = makeItem(title: "C", createdAt: Date(timeIntervalSince1970: 3))
        let mock = MockTodoModelContext(items: [itemA, itemB, itemC])
        let repo = LocalRepository(modelContext: mock)

        try await repo.delete(id: itemB.id)
        let result = try await repo.fetchAll(offset: 0, limit: 10)

        #expect(result.items.count == 2)
        #expect(result.items.contains(itemA))
        #expect(result.items.contains(itemC))
        #expect(!result.items.contains(itemB))
    }

    @Test func testDeletePropagatesRawWriteErrorAndLeavesItemIntact() async throws {
        let item = makeItem()
        let mock = MockTodoModelContext(items: [item])
        mock.deleteError = WriteFailure()
        let repo = LocalRepository(modelContext: mock)

        await #expect(throws: WriteFailure.self) {
            try await repo.delete(id: item.id)
        }
        #expect(mock.items == [item])
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

// @unchecked Sendable: test double only, never accessed concurrently — each test
// creates its own instance and awaits every call sequentially within that test.
private final class MockTodoModelContext: TodoModelContext, @unchecked Sendable {
    var items: [TodoItem]
    var fetchError: Error?
    var saveError: Error?
    var deleteError: Error?

    init(items: [TodoItem] = [], fetchError: Error? = nil) {
        self.items = items
        self.fetchError = fetchError
    }

    func fetchAll(offset: Int, limit: Int) async throws -> [TodoItem] {
        if let fetchError { throw fetchError }
        let sorted = items.sorted { $0.createdAt < $1.createdAt }
        guard offset < sorted.count else { return [] }
        let end = min(offset + limit, sorted.count)
        return Array(sorted[offset..<end])
    }

    func save(_ item: TodoItem) async throws {
        if let saveError { throw saveError }
        items.append(item)
    }

    func delete(id: UUID) async throws {
        if let deleteError { throw deleteError }
        items.removeAll { $0.id == id }
    }
}
