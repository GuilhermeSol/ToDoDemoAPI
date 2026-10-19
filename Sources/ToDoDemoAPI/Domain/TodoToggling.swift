//
//  TodoToggling.swift
//  ToDoDemoAPI
//

import Foundation

public protocol TodoToggling {
    func toggle(id: UUID) async throws
}
