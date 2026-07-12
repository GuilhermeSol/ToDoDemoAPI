//
//  TodoRepository.swift
//  ToDoDemoAPI
//

public protocol TodoRepository {
    func fetchAll() async throws -> [TodoItem]
}
