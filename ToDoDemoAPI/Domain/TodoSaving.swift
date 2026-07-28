//
//  TodoSaving.swift
//  ToDoDemoAPI
//

public protocol TodoSaving {
    func save(_ item: TodoItem) async throws
}
