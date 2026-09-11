import Foundation
import XCTest
@testable import WSDeckBuilder

private final class NewsURLProtocol: URLProtocol {
    static var status = 200
    static var body = Data()
    static var requests = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
final class WSNewsServiceTests: XCTestCase {
    func testRefreshThrottleManualBypassAndFailurePreserveCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appendingPathComponent("news.json")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NewsURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        NewsURLProtocol.requests = 0
        NewsURLProtocol.status = 200
        NewsURLProtocol.body = Data(#"{"items":[{"date":"2026-09-11","categories":["商品情報"],"title_jp":"商品","url":"https://example.com/news","source":"official"}]}"#.utf8)
        let service = WSNewsService(session: session, cacheFile: cache)
        await service.refresh(force: false)
        XCTAssertEqual(service.items.count, 1)
        await service.refresh(force: false)
        XCTAssertEqual(NewsURLProtocol.requests, 1)
        await service.refresh()
        XCTAssertEqual(NewsURLProtocol.requests, 2)
        let reloaded = WSNewsService(session: session, cacheFile: cache)
        await reloaded.refresh(force: false)
        XCTAssertEqual(NewsURLProtocol.requests, 2)
        NewsURLProtocol.status = 503
        await service.refresh()
        XCTAssertEqual(service.items.count, 1)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertFalse(service.isLoading)
        NewsURLProtocol.status = 200
        NewsURLProtocol.body = Data(#"{"items":[]}"#.utf8)
        await service.refresh()
        XCTAssertEqual(service.items.count, 1)
        XCTAssertEqual(WSNewsService(session: session, cacheFile: cache).items.count, 1)
    }
}
