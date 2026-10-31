import XCTest
@testable import ServerDeck

final class FormattersTests: XCTestCase {
    func testFormatUptime() {
        XCTAssertEqual(Formatters.formatUptime(0), "0m")
        XCTAssertEqual(Formatters.formatUptime(120), "2m")
        XCTAssertEqual(Formatters.formatUptime(3600), "1h 0m")
        XCTAssertEqual(Formatters.formatUptime(3665), "1h 1m")
        XCTAssertEqual(Formatters.formatUptime(90000), "1d 1h 0m")
    }

    func testFormatPercent() {
        XCTAssertEqual(Formatters.formatPercent(18.5), "18.5%")
        XCTAssertEqual(Formatters.formatPercent(50.0, decimals: 0), "50%")
    }

    func testFormatRate() {
        let rateStr = Formatters.formatRate(1_048_576)
        XCTAssertTrue(rateStr.contains("/s"))
    }
}
