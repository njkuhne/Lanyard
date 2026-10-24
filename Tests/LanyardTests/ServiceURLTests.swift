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

    func testAddressAndLegacyHostKeysBothWork() throws {
        let config = try ConfigParser.parse("servers:\n  - name: A\n    address: a.lan\n  - name: B\n    host: b.lan\n")
        let hosts = config.entries.compactMap { entry -> String? in
            if case .server(let server) = entry { return server.host }
            return nil
        }
        XCTAssertEqual(hosts, ["a.lan", "b.lan"])
        XCTAssertEqual(try url("web: { url: \"https://{address}:9443\" }"), "https://box.lan:9443")
    }

    func testUserGoesIntoSSHURL() throws {
        XCTAssertEqual(try url("ssh: { user: admin }"), "ssh://admin@box.lan")
    }

    func testCustomTemplateFillsHost() throws {
        XCTAssertEqual(try url("custom: { url: \"https://{host}:9443\" }"), "https://box.lan:9443")
    }

    func testLinkAndCustomAreAliasesForWeb() throws {
        XCTAssertEqual(try url("link: { url: \"ftp://{host}/pub\" }"), "ftp://box.lan/pub")
    }

    func testWebURLReplacesPortPathAndHTTPSRule() throws {
        XCTAssertEqual(try url("web: { url: \"http://{host}:9443/admin\", port: 8123 }"), "http://box.lan:9443/admin")
    }

    func testEditorWritesWebURLWithoutPortOrHTTPS() throws {
        let config = try ConfigParser.parse("servers:\n  - name: Box\n    host: box.lan\n    services:\n      - custom: { url: \"https://{host}:9443\", label: Portainer }\n")
        let yaml = EditorModel.yaml(from: EditorModel.items(from: config))
        XCTAssertTrue(yaml.contains("- web: { url: \"https://{host}:9443\", label: Portainer }"), yaml)
    }

    func testEditorRoundTripKeepsImplicitHTTPSOutOfYAML() throws {
        let config = try ConfigParser.parse("servers:\n  - name: Box\n    host: box.lan\n    services:\n      - web: 8123\n      - web: { port: 8123, https: true }\n")
        let yaml = EditorModel.yaml(from: EditorModel.items(from: config))
        XCTAssertTrue(yaml.contains("- web: { port: 8123 }"), yaml)
        XCTAssertTrue(yaml.contains("- web: { port: 8123, https: true }"), yaml)
    }
}
