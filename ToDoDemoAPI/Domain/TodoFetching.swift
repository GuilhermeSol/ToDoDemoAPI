//
//  TodoFetching.swift
//  ToDoDemoAPI
//

public protocol TodoFetching {
    func fetchAll(offset: Int, limit: Int) async throws -> TodoItemPage
}
