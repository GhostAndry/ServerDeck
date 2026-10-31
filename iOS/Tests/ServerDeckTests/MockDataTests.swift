import XCTest
@testable import ServerDeck

final class MockDataTests: XCTestCase {
    func testSampleHostOverview() {
        let host = MockDataProvider.sampleHostOverview
        XCTAssertEqual(host.hostname, "srv-01")
        XCTAssertEqual(host.disks.count, 2)
        XCTAssertEqual(host.containersSummary.total, 10)
        XCTAssertEqual(host.containersSummary.running, 9)
    }

    func testSampleContainers() {
        let containers = MockDataProvider.sampleContainers
        XCTAssertGreaterThan(containers.count, 5)
        XCTAssertTrue(containers.contains(where: { $0.name == "openwebui" }))
        XCTAssertTrue(containers.contains(where: { $0.name == "portainer" }))
    }

    func testSampleServices() {
        let services = MockDataProvider.sampleServices
        XCTAssertGreaterThan(services.count, 3)
        XCTAssertTrue(services.contains(where: { $0.id == "beszel" }))
        XCTAssertTrue(services.contains(where: { $0.id == "portainer" }))
    }
}
