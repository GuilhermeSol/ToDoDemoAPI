//
//  TodoDeleting.swift
//  ToDoDemoAPI
//

import Foundation

public protocol TodoDeleting {
    func delete(id: UUID) async throws
}
