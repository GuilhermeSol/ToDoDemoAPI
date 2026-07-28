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
}

private extension LocalRepositoryPersistenceTests {
    func makeRepository(at url: URL) throws -> LocalRepository {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: TodoItemModel.self, configurations: config)
        return LocalRepository(modelContext: SwiftDataModelContext(modelContainer: container))
    }
}
