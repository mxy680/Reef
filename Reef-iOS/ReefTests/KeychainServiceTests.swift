//
//  KeychainServiceTests.swift
//  ReefTests
//
//  Local integration tests for KeychainService — no server required.
//

import Testing
import Foundation
@testable import Reef

@Suite("KeychainService", .serialized)
struct KeychainServiceTests {

    @Test("save and retrieve user ID")
    func saveAndRetrieveUserID() {
        KeychainService.deleteAll()
        let id = UUID().uuidString
        KeychainService.save(id, for: .userIdentifier)
        let retrieved = KeychainService.get(.userIdentifier)
        #expect(retrieved == id)
        KeychainService.deleteAll()
    }

    @Test("delete clears key")
    func deletesClearsKey() {
        KeychainService.deleteAll()
        KeychainService.save("to-be-deleted", for: .userName)
        KeychainService.delete(.userName)
        #expect(KeychainService.get(.userName) == nil)
    }

    @Test("overwrite existing value")
    func overwriteExistingValue() {
        KeychainService.deleteAll()
        KeychainService.save("first", for: .userEmail)
        KeychainService.save("second", for: .userEmail)
        #expect(KeychainService.get(.userEmail) == "second")
        KeychainService.deleteAll()
    }

    @Test("deleteAll clears all keys")
    func deleteAllClearsAllKeys() {
        KeychainService.deleteAll()
        KeychainService.save("id-value", for: .userIdentifier)
        KeychainService.save("name-value", for: .userName)
        KeychainService.save("email-value", for: .userEmail)
        KeychainService.deleteAll()
        #expect(KeychainService.get(.userIdentifier) == nil)
        #expect(KeychainService.get(.userName) == nil)
        #expect(KeychainService.get(.userEmail) == nil)
    }

    @Test("get nonexistent key returns nil")
    func getNonexistentKeyReturnsNil() {
        KeychainService.deleteAll()
        #expect(KeychainService.get(.userEmail) == nil)
    }
}
