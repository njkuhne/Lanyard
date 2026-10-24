import XCTest
@testable import Lanyard

final class ServiceURLTests: XCTestCase {
    private func url(_ yaml: String) throws -> String? {
        let config = try ConfigParser.parse("servers:\n  - name: Box\n    host: box.lan\n    services:\n      - \(yaml)\n")
        guard case .server(let server) = config.entries.first, let service = server.services.first else { return nil }
        return service.url(for: server)?.absoluteString
    }

    func testWebDefaultsToHTTPSWithoutPort() throws {
        XCTAssertEqual(try url("web"), "https://box.lan")
    }

    func testWebUsesHTTPSOnKnownTLSPorts() throws {
        XCTAssertEqual(try url("web: 5001"), "https://box.lan:5001")
        XCTAssertEqual(try url("web: 8006"), "https://box.lan:8006")
    }

    func testWebUsesHTTPOnOtherPorts() throws {
        XCTAssertEqual(try url("web: 8123"), "http://box.lan:8123")
        XCTAssertEqual(try url("web: 80"), "http://box.lan:80")
    }

    func testExplicitHTTPSWins() throws {
        XCTAssertEqual(try url("web: { port: 8123, https: true }"), "https://box.lan:8123")
        XCTAssertEqual(try url("web: { port: 443, https: false }"), "http://box.lan:443")
        XCTAssertEqual(try url("http"), "http://box.lan")
    }

    func testUserGoesIntoSSHURL() throws {
        XCTAssertEqual(try url("ssh: { user: admin }"), "ssh://admin@box.lan")
    }

    func testCustomTemplateFillsHost() throws {
        XCTAssertEqual(try url("custom: { url: \"https://{host}:9443\" }"), "https://box.lan:9443")
    }

    func testEditorRoundTripKeepsImplicitHTTPSOutOfYAML() throws {
        let config = try ConfigParser.parse("servers:\n  - name: Box\n    host: box.lan\n    services:\n      - web: 8123\n      - web: { port: 8123, https: true }\n")
        let yaml = EditorModel.yaml(from: EditorModel.items(from: config))
        XCTAssertTrue(yaml.contains("- web: { port: 8123 }"), yaml)
        XCTAssertTrue(yaml.contains("- web: { port: 8123, https: true }"), yaml)
    }
}
