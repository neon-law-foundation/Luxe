import Foundation
import SotoS3

public protocol S3ClientProtocol: Sendable {
    func putObject(_ input: S3.PutObjectRequest) async throws
    func headObject(_ input: S3.HeadObjectRequest) async throws -> String?
    func createMultipartUpload(_ input: S3.CreateMultipartUploadRequest) async throws -> String?
    func uploadPart(_ input: S3.UploadPartRequest) async throws -> String?
    func completeMultipartUpload(_ input: S3.CompleteMultipartUploadRequest) async throws
}

public final class S3ClientWrapper: S3ClientProtocol {
    private let s3: S3

    public init(s3: S3) {
        self.s3 = s3
    }

    public func putObject(_ input: S3.PutObjectRequest) async throws {
        _ = try await s3.putObject(input)
    }

    public func headObject(_ input: S3.HeadObjectRequest) async throws -> String? {
        let response = try await s3.headObject(input)
        return response.eTag
    }

    public func createMultipartUpload(_ input: S3.CreateMultipartUploadRequest) async throws -> String? {
        let response = try await s3.createMultipartUpload(input)
        return response.uploadId
    }

    public func uploadPart(_ input: S3.UploadPartRequest) async throws -> String? {
        let response = try await s3.uploadPart(input)
        return response.eTag
    }

    public func completeMultipartUpload(_ input: S3.CompleteMultipartUploadRequest) async throws {
        _ = try await s3.completeMultipartUpload(input)
    }
}

final class MockS3Client: @unchecked Sendable, S3ClientProtocol {
    var putObjectResults: [Result<Void, Error>] = []
    var headObjectResults: [Result<String?, Error>] = []
    var createMultipartUploadResults: [Result<String?, Error>] = []
    var uploadPartResults: [Result<String?, Error>] = []
    var completeMultipartUploadResults: [Result<Void, Error>] = []

    private var putObjectIndex = 0
    private var headObjectIndex = 0
    private var createMultipartUploadIndex = 0
    private var uploadPartIndex = 0
    private var completeMultipartUploadIndex = 0

    var putObjectRequests: [S3.PutObjectRequest] = []
    var headObjectRequests: [S3.HeadObjectRequest] = []
    var createMultipartUploadRequests: [S3.CreateMultipartUploadRequest] = []
    var uploadPartRequests: [S3.UploadPartRequest] = []
    var completeMultipartUploadRequests: [S3.CompleteMultipartUploadRequest] = []

    func putObject(_ input: S3.PutObjectRequest) async throws {
        putObjectRequests.append(input)

        guard putObjectIndex < putObjectResults.count else {
            throw MockS3Error.unexpectedCall("putObject called more times than expected")
        }

        let result = putObjectResults[putObjectIndex]
        putObjectIndex += 1

        switch result {
        case .success():
            return
        case .failure(let error):
            throw error
        }
    }

    func headObject(_ input: S3.HeadObjectRequest) async throws -> String? {
        headObjectRequests.append(input)

        guard headObjectIndex < headObjectResults.count else {
            throw MockS3Error.unexpectedCall("headObject called more times than expected")
        }

        let result = headObjectResults[headObjectIndex]
        headObjectIndex += 1

        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func createMultipartUpload(_ input: S3.CreateMultipartUploadRequest) async throws -> String? {
        createMultipartUploadRequests.append(input)

        guard createMultipartUploadIndex < createMultipartUploadResults.count else {
            throw MockS3Error.unexpectedCall("createMultipartUpload called more times than expected")
        }

        let result = createMultipartUploadResults[createMultipartUploadIndex]
        createMultipartUploadIndex += 1

        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadPart(_ input: S3.UploadPartRequest) async throws -> String? {
        uploadPartRequests.append(input)

        guard uploadPartIndex < uploadPartResults.count else {
            throw MockS3Error.unexpectedCall("uploadPart called more times than expected")
        }

        let result = uploadPartResults[uploadPartIndex]
        uploadPartIndex += 1

        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func completeMultipartUpload(_ input: S3.CompleteMultipartUploadRequest) async throws {
        completeMultipartUploadRequests.append(input)

        guard completeMultipartUploadIndex < completeMultipartUploadResults.count else {
            throw MockS3Error.unexpectedCall("completeMultipartUpload called more times than expected")
        }

        let result = completeMultipartUploadResults[completeMultipartUploadIndex]
        completeMultipartUploadIndex += 1

        switch result {
        case .success():
            return
        case .failure(let error):
            throw error
        }
    }

    func reset() {
        putObjectResults.removeAll()
        headObjectResults.removeAll()
        createMultipartUploadResults.removeAll()
        uploadPartResults.removeAll()
        completeMultipartUploadResults.removeAll()

        putObjectIndex = 0
        headObjectIndex = 0
        createMultipartUploadIndex = 0
        uploadPartIndex = 0
        completeMultipartUploadIndex = 0

        putObjectRequests.removeAll()
        headObjectRequests.removeAll()
        createMultipartUploadRequests.removeAll()
        uploadPartRequests.removeAll()
        completeMultipartUploadRequests.removeAll()
    }
}

enum MockS3Error: Error, LocalizedError, Equatable {
    case unexpectedCall(String)
    case fileNotFound
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedCall(let message):
            return "Unexpected S3 call: \(message)"
        case .fileNotFound:
            return "File not found in S3"
        case .uploadFailed:
            return "S3 upload failed"
        }
    }
}
