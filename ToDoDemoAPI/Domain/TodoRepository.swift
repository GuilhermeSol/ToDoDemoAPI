//
//  TodoRepository.swift
//  ToDoDemoAPI
//

public protocol TodoRepository {
    func fetchAll() async throws -> [TodoItem]
    func save(_ item: TodoItem) async throws
}
