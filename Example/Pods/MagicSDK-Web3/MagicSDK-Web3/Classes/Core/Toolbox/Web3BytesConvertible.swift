//
//  BytesConvertible.swift
//  Web3
//
//  Created by Koray Koska on 06.04.18.
//  Copyright © 2018 Boilertalk. All rights reserved.
//

import Foundation

/// UInt8 typealias
public typealias Byte = UInt8

/// [UInt8] typealias
public typealias Bytes = [Byte]

/**
 * Implementable if the type can be converted to Bytes
 */
public protocol Web3BytesRepresentable {
    func makeBytes() throws -> Bytes
}

/**
 * Implementable if the type can be represented with Bytes
 */
public protocol Web3BytesInitializable {
    init(_ bytes: Bytes) throws
}

/**
 * Implementable if a type is BytesRepresentable and BytesInitializable
 */
public typealias Web3BytesConvertible = Web3BytesRepresentable & Web3BytesInitializable

public extension Web3BytesInitializable {
    init(_ bytes: Web3BytesRepresentable) throws {
        let bytes = try bytes.makeBytes()
        try self.init(bytes)
    }
}
