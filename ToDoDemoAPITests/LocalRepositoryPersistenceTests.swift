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

        let result = try await repo.fetchAll()
        #expect(result.count == 1)
        #expect(result.first?.title == "Updated")
        #expect(result.first?.isCompleted == true)
    }

    @Test func testSaveSameItemTwiceIsIdempotent() async throws {
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let repo = try makeRepository(at: storeURL)
        let item = TodoItem(id: UUID(), title: "Same", isCompleted: false, createdAt: Date(timeIntervalSince1970: 0))

        try await repo.save(item)
        try await repo.save(item)

        let result = try await repo.fetchAll()
        #expect(result.count == 1)
        #expect(result.first == item)
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
        let result = try await secondSessionRepo.fetchAll()

        #expect(result.count == 1)
        #expect(result.first == item)
    }
}

private extension LocalRepositoryPersistenceTests {
    func makeRepository(at url: URL) throws -> LocalRepository {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: TodoItemModel.self, configurations: config)
        return LocalRepository(modelContext: SwiftDataModelContext(modelContainer: container))
    }
}
