import Bouncer
import Dali
import Testing
import Vapor

@Suite("Session Storage", .serialized)
struct SessionStorageTests {
    @Test("session data properties")
    func sessionDataProperties() throws {
        let sessionId = "test-session-123"
        let userId = UUID()
        let accessToken = "test-access-token"

        let sessionData = SessionStorage.SessionData(
            sessionId: sessionId,
            userId: userId,
            accessToken: accessToken,
            refreshToken: "test-refresh-token",
            idToken: "test-id-token",
            expiresAt: Date().addingTimeInterval(3600)
        )

        #expect(sessionData.sessionId == sessionId)
        #expect(sessionData.userId == userId)
        #expect(sessionData.accessToken == accessToken)
        #expect(sessionData.refreshToken == "test-refresh-token")
        #expect(sessionData.idToken == "test-id-token")
        #expect(sessionData.isExpired == false)
    }

    @Test("session data expiration check")
    func sessionDataExpirationCheck() throws {
        // Test non-expired session
        let nonExpired = SessionStorage.SessionData(
            sessionId: "test",
            userId: UUID(),
            accessToken: "token",
            expiresAt: Date().addingTimeInterval(3600)  // 1 hour from now
        )
        #expect(nonExpired.isExpired == false)

        // Test expired session
        let expired = SessionStorage.SessionData(
            sessionId: "test",
            userId: UUID(),
            accessToken: "token",
            expiresAt: Date().addingTimeInterval(-3600)  // 1 hour ago
        )
        #expect(expired.isExpired == true)

        // Test no expiration
        let noExpiration = SessionStorage.SessionData(
            sessionId: "test",
            userId: UUID(),
            accessToken: "token",
            expiresAt: nil
        )
        #expect(noExpiration.isExpired == false)
    }

    @Test("session data codable")
    func sessionDataCodable() throws {
        let original = SessionStorage.SessionData(
            sessionId: "test-session",
            userId: UUID(),
            accessToken: "access-token",
            refreshToken: "refresh-token",
            idToken: "id-token",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            metadata: ["key": "value"]
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionStorage.SessionData.self, from: data)

        #expect(decoded.sessionId == original.sessionId)
        #expect(decoded.userId == original.userId)
        #expect(decoded.accessToken == original.accessToken)
        #expect(decoded.refreshToken == original.refreshToken)
        #expect(decoded.idToken == original.idToken)
        #expect(decoded.metadata == original.metadata)
    }

    @Test("session storage key type")
    func sessionStorageKeyType() throws {
        // Test that SessionStorageKey has correct value type
        let key = EnhancedSessionStorageKey.self
        #expect(key.Value.self == [String: SessionStorage.SessionData].self)
    }
}
