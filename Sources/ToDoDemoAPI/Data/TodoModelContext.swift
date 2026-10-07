//
//  TodoModelContext.swift
//  ToDoDemoAPI
//
//  Internal seam over the persistence read path so LocalRepository can be
//  tested without a real SwiftData store. Not part of the public API.
//

import Foundation

protocol TodoModelContext: Sendable {
    func fetchAll(offset: Int, limit: Int) async throws -> [TodoItem]
    func save(_ item: TodoItem) async throws
    func delete(id: UUID) async throws
}
