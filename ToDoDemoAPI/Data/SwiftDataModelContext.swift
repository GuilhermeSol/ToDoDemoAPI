//
//  SwiftDataModelContext.swift
//  ToDoDemoAPI
//
//  Production TodoModelContext seam backed by a real SwiftData ModelContext.
//  Internal — the module hides SwiftData behind LocalRepository's public API.
//

import Foundation
import SwiftData

struct SwiftDataModelContext: TodoModelContext {
    let context: ModelContext

    func fetchAll() throws -> [TodoItemModel] {
        try context.fetch(FetchDescriptor<TodoItemModel>())
    }
}
