//
//  LocalRepositoryPersistenceTests.swift
//  ToDoDemoAPITests
//
//  Real, file-backed SwiftData tests (no mock) — exercises genuine
//  ModelContainer/ModelContext behavior, unlike LocalRepositoryTests.swift.
//

import Foundation
import Testing
import SwiftData
@testable import ToDoDemoAPI

struct LocalRepositoryPersistenceTests {

    @Test func testSaveExistingIdOverwritesFields() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let repo = try makeRepository(at: storeURL)
        let id = UUID()

        try await repo.save(TodoItem(id: id, title: "Original", isCompleted: false, createdAt: Date(timeIntervalSince1970: 0)))
        try await repo.save(TodoItem(id: id, title: "Updated", isCompleted: true, createdAt: Date(timeIntervalSince1970: 0)))

        let result = try await repo.fetchAll(offset: 0, limit: 10)
        #expect(result.items.count == 1)
        #expect(result.items.first?.title == "Updated")
        #expect(result.items.first?.isCompleted == true)
    }

    @Test func testSaveSameItemTwiceIsIdempotent() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let repo = try makeRepository(at: storeURL)
        let item = TodoItem(id: UUID(), title: "Same", isCompleted: false, createdAt: Date(timeIntervalSince1970: 0))

        try await repo.save(item)
        try await repo.save(item)

        let result = try await repo.fetchAll(offset: 0, limit: 10)
        #expect(result.items.count == 1)
        #expect(result.items.first == item)
    }

    @Test func testSavedItemSurvivesAcrossContainerRecreation() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let item = TodoItem(id: UUID(), title: "Persisted", isCompleted: true, createdAt: Date(timeIntervalSince1970: 0))

        // Scoped so the first container/context is released before the second is built,
        // ruling out any in-process carryover masquerading as on-disk persistence.
        do {
            let firstSessionRepo = try makeRepository(at: storeURL)
            try await firstSessionRepo.save(item)
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let result = try await secondSessionRepo.fetchAll(offset: 0, limit: 10)

        #expect(result.items.count == 1)
        #expect(result.items.first == item)
    }

    @Test func testFetchAllPaginatesAcrossRealStore() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let repo = try makeRepository(at: storeURL)

        let itemAt300 = TodoItem(id: UUID(), title: "Item 3", isCompleted: false, createdAt: Date(timeIntervalSince1970: 300))
        let itemAt100 = TodoItem(id: UUID(), title: "Item 1", isCompleted: false, createdAt: Date(timeIntervalSince1970: 100))
        let itemAt500 = TodoItem(id: UUID(), title: "Item 5", isCompleted: false, createdAt: Date(timeIntervalSince1970: 500))
        let itemAt200 = TodoItem(id: UUID(), title: "Item 2", isCompleted: false, createdAt: Date(timeIntervalSince1970: 200))
        let itemAt400 = TodoItem(id: UUID(), title: "Item 4", isCompleted: false, createdAt: Date(timeIntervalSince1970: 400))

        for item in [itemAt300, itemAt100, itemAt500, itemAt200, itemAt400] {
            try await repo.save(item)
        }

        let expectedChronological = [itemAt100, itemAt200, itemAt300, itemAt400, itemAt500]

        let firstPage = try await repo.fetchAll(offset: 1, limit: 2)
        #expect(firstPage.items == [itemAt200, itemAt300])
        #expect(firstPage.hasMore == true)

        let lastSingle = try await repo.fetchAll(offset: 4, limit: 1)
        #expect(lastSingle.items == [itemAt500])
        #expect(lastSingle.hasMore == false)

        let beyondEnd = try await repo.fetchAll(offset: 5, limit: 2)
        #expect(beyondEnd.items == [])
        #expect(beyondEnd.hasMore == false)

        let everything = try await repo.fetchAll(offset: 0, limit: 5)
        #expect(everything.items == expectedChronological)
        #expect(everything.hasMore == false)
    }

    @Test func testDeleteExistingItemRemovesItFromRealStore() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let repo = try makeRepository(at: storeURL)
        let item = TodoItem(id: UUID(), title: "Delete me", isCompleted: false, createdAt: Date(timeIntervalSince1970: 0))
        try await repo.save(item)

        try await repo.delete(id: item.id)

        let result = try await repo.fetchAll(offset: 0, limit: 10)
        #expect(result.items.isEmpty)
    }

    @Test func testToggleNonMatchingIdLeavesStoredItemUnchangedAndDoesNotThrow() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let repo = try makeRepository(at: storeURL)
        let item = TodoItem(id: UUID(), title: "Keep me", isCompleted: false, createdAt: Date(timeIntervalSince1970: 7))
        try await repo.save(item)

        try await repo.toggle(id: UUID())

        let result = try await repo.fetchAll(offset: 0, limit: 10)
        #expect(result.items == [item])
    }

    @Test func testToggleFlipsIsCompletedAndKeepsTitleAndCreatedAt() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let repo = try makeRepository(at: storeURL)
        let a = TodoItem(id: UUID(), title: "Flip me", isCompleted: false, createdAt: Date(timeIntervalSince1970: 11))
        let b = TodoItem(id: UUID(), title: "Other", isCompleted: false, createdAt: Date(timeIntervalSince1970: 22))
        try await repo.save(a)
        try await repo.save(b)

        try await repo.toggle(id: a.id)

        let result = try await repo.fetchAll(offset: 0, limit: 10)
        #expect(result.items == [TodoItem(id: a.id, title: "Flip me", isCompleted: true, createdAt: Date(timeIntervalSince1970: 11)), b])
    }

    @Test func testToggleTwiceRestoresOriginalCompletionState() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let repo = try makeRepository(at: storeURL)
        let item = TodoItem(id: UUID(), title: "Twice", isCompleted: false, createdAt: Date(timeIntervalSince1970: 5))
        try await repo.save(item)

        try await repo.toggle(id: item.id)
        try await repo.toggle(id: item.id)

        let result = try await repo.fetchAll(offset: 0, limit: 10)
        #expect(result.items == [item])
    }

    @Test func testToggledStateSurvivesAcrossContainerRecreation() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let item = TodoItem(id: UUID(), title: "Persist toggle", isCompleted: false, createdAt: Date(timeIntervalSince1970: 9))

        do {
            let firstSessionRepo = try makeRepository(at: storeURL)
            try await firstSessionRepo.save(item)
            try await firstSessionRepo.toggle(id: item.id)
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let result = try await secondSessionRepo.fetchAll(offset: 0, limit: 10)

        #expect(result.items == [TodoItem(id: item.id, title: "Persist toggle", isCompleted: true, createdAt: Date(timeIntervalSince1970: 9))])
    }

    // MARK: - Relaunch round trips (TDO-44)

    @Test func testDeletedItemIsAbsentAfterContainerRecreation() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let item = TodoItem(id: UUID(), title: "Delete me", isCompleted: false, createdAt: Date(timeIntervalSince1970: 1))

        do {
            let firstSessionRepo = try makeRepository(at: storeURL)
            try await firstSessionRepo.save(item)
            try await firstSessionRepo.delete(id: item.id)
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let result = try await secondSessionRepo.fetchAll(offset: 0, limit: 10)

        #expect(result.items.isEmpty)
    }

    @Test func testDeleteUnknownIdLeavesOtherItemsAfterContainerRecreation() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let itemA = TodoItem(id: UUID(), title: "A", isCompleted: false, createdAt: Date(timeIntervalSince1970: 1))
        let itemB = TodoItem(id: UUID(), title: "B", isCompleted: true, createdAt: Date(timeIntervalSince1970: 2))

        do {
            let firstSessionRepo = try makeRepository(at: storeURL)
            try await firstSessionRepo.save(itemA)
            try await firstSessionRepo.save(itemB)
            try await firstSessionRepo.delete(id: UUID())
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let result = try await secondSessionRepo.fetchAll(offset: 0, limit: 10)

        #expect(result.items == [itemA, itemB])
    }

    @Test func testOnlyKeptItemRemainsAfterDeletingOtherAcrossRecreation() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let itemA = TodoItem(id: UUID(), title: "A", isCompleted: false, createdAt: Date(timeIntervalSince1970: 1))
        let itemB = TodoItem(id: UUID(), title: "B", isCompleted: false, createdAt: Date(timeIntervalSince1970: 2))

        do {
            let firstSessionRepo = try makeRepository(at: storeURL)
            try await firstSessionRepo.save(itemA)
            try await firstSessionRepo.save(itemB)
            try await firstSessionRepo.delete(id: itemA.id)
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let result = try await secondSessionRepo.fetchAll(offset: 0, limit: 10)

        #expect(result.items == [itemB])
    }

    @Test func testEmptyStoreReturnsNoItemsAfterContainerRecreation() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        do {
            _ = try makeRepository(at: storeURL)
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let result = try await secondSessionRepo.fetchAll(offset: 0, limit: 10)

        #expect(result.items.isEmpty)
        #expect(result.hasMore == false)
    }

    @Test func testDoubleToggleRestoresStateAfterContainerRecreation() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let item = TodoItem(id: UUID(), title: "Toggle twice", isCompleted: false, createdAt: Date(timeIntervalSince1970: 1))

        do {
            let firstSessionRepo = try makeRepository(at: storeURL)
            try await firstSessionRepo.save(item)
            try await firstSessionRepo.toggle(id: item.id)
            try await firstSessionRepo.toggle(id: item.id)
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let result = try await secondSessionRepo.fetchAll(offset: 0, limit: 10)

        #expect(result.items == [item])
    }

    @Test func testPagingAcrossRelaunchReturnsAllItemsInOrder() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let items = (1 ... 5).map {
            TodoItem(id: UUID(), title: "Item \($0)", isCompleted: false, createdAt: Date(timeIntervalSince1970: TimeInterval($0)))
        }

        do {
            let firstSessionRepo = try makeRepository(at: storeURL)
            // Saved out of order so the assertion proves createdAt ordering, not insertion order.
            for item in items.reversed() {
                try await firstSessionRepo.save(item)
            }
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let firstPage = try await secondSessionRepo.fetchAll(offset: 0, limit: 2)
        let secondPage = try await secondSessionRepo.fetchAll(offset: 2, limit: 2)
        let lastPage = try await secondSessionRepo.fetchAll(offset: 4, limit: 2)

        #expect(firstPage.items == Array(items[0 ... 1]))
        #expect(firstPage.hasMore == true)
        #expect(secondPage.items == Array(items[2 ... 3]))
        #expect(secondPage.hasMore == true)
        #expect(lastPage.items == [items[4]])
        #expect(lastPage.hasMore == false)
    }

    @Test func testRetitledItemHasNewTitleAfterContainerRecreation() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1)

        do {
            let firstSessionRepo = try makeRepository(at: storeURL)
            try await firstSessionRepo.save(TodoItem(id: id, title: "Old title", isCompleted: false, createdAt: createdAt))
            try await firstSessionRepo.save(TodoItem(id: id, title: "New title", isCompleted: false, createdAt: createdAt))
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let result = try await secondSessionRepo.fetchAll(offset: 0, limit: 10)

        #expect(result.items == [TodoItem(id: id, title: "New title", isCompleted: false, createdAt: createdAt)])
    }

    @Test func testMixedSessionFinalStateSurvivesContainerRecreation() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let idA = UUID()
        let idB = UUID()
        let createdAt = Date(timeIntervalSince1970: 1)

        do {
            let firstSessionRepo = try makeRepository(at: storeURL)
            try await firstSessionRepo.save(TodoItem(id: idA, title: "A", isCompleted: false, createdAt: createdAt))
            try await firstSessionRepo.save(TodoItem(id: idB, title: "B", isCompleted: false, createdAt: Date(timeIntervalSince1970: 2)))
            try await firstSessionRepo.toggle(id: idA)
            try await firstSessionRepo.delete(id: idB)
            try await firstSessionRepo.save(TodoItem(id: idA, title: "A renamed", isCompleted: true, createdAt: createdAt))
        }

        let secondSessionRepo = try makeRepository(at: storeURL)
        let result = try await secondSessionRepo.fetchAll(offset: 0, limit: 10)

        #expect(result.items == [TodoItem(id: idA, title: "A renamed", isCompleted: true, createdAt: createdAt)])
    }
}

private extension LocalRepositoryPersistenceTests {
    func makeRepository(at url: URL) throws -> LocalRepository {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: TodoItemModel.self, configurations: config)
        return LocalRepository(modelContext: SwiftDataModelContext(modelContainer: container))
    }
}
