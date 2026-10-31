import XCTest
@testable import ServerDeck

final class ModelTests: XCTestCase {
    func testHostOverviewDecoding() throws {
        let json = """
        {
          "hostname": "srv-01",
          "os": "Debian GNU/Linux 12 (bookworm)",
          "uptime_seconds": 345600,
          "cpu": {
            "usage_percent": 18.5,
            "cores": 4,
            "model": "Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz",
            "temperature_celsius": 42.5
          },
          "memory": {
            "total_bytes": 16777216000,
            "used_bytes": 8388608000,
            "free_bytes": 8388608000,
            "usage_percent": 50.0
          },
          "disks": [
            {
              "mount_point": "/",
              "filesystem": "/dev/sda1",
              "total_bytes": 107374182400,
              "used_bytes": 48318382080,
              "free_bytes": 59055800320,
              "usage_percent": 45.0
            },
            {
              "mount_point": "/mnt/DATA",
              "filesystem": "/dev/sdb1",
              "total_bytes": 2000398934016,
              "used_bytes": 1440287232491,
              "free_bytes": 560111701525,
              "usage_percent": 72.0
            }
          ],
          "network": {
            "bytes_recv_rate": 1048576,
            "bytes_sent_rate": 524288
          },
          "containers_summary": {
            "total": 12,
            "running": 10,
            "stopped": 2,
            "unhealthy": 0
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let host = try decoder.decode(HostOverview.self, from: json)

        XCTAssertEqual(host.hostname, "srv-01")
        XCTAssertEqual(host.cpu.cores, 4)
        XCTAssertEqual(host.cpu.temperatureCelsius, 42.5)
        XCTAssertEqual(host.disks.count, 2)
        XCTAssertEqual(host.disks[1].mountPoint, "/mnt/DATA")
        XCTAssertEqual(host.disks[1].usagePercent, 72.0)
        XCTAssertFalse(host.disks[1].isWarning) // Warning threshold is 80%
        XCTAssertEqual(host.containersSummary.running, 10)
    }

    func testContainerDecoding() throws {
        let json = """
        {
          "id": "c1a2b3c4d5e6",
          "name": "openwebui",
          "image": "ghcr.io/open-webui/open-webui:main",
          "state": "running",
          "status": "Up 3 days (healthy)",
          "health": "healthy",
          "stack": "OpenWebUI",
          "created_at": 1700000000,
          "ports": ["8080:8080"],
          "cpu_percent": 2.4,
          "memory_usage_bytes": 268435456,
          "memory_limit_bytes": 16777216000
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let container = try decoder.decode(DockerContainer.self, from: json)

        XCTAssertEqual(container.id, "c1a2b3c4d5e6")
        XCTAssertEqual(container.name, "openwebui")
        XCTAssertEqual(container.cleanName, "openwebui")
        XCTAssertTrue(container.isRunning)
        XCTAssertFalse(container.isUnhealthy)
        XCTAssertEqual(container.stack, "OpenWebUI")
    }

    func testWebSocketEventDecoding() throws {
        let hostJson = """
        {
          "type": "host_tick",
          "timestamp": 1700000010,
          "data": {
            "hostname": "srv-01",
            "os": "Debian 12",
            "uptime_seconds": 120,
            "cpu": { "usage_percent": 10.0, "cores": 2, "model": "Intel" },
            "memory": { "total_bytes": 1000, "used_bytes": 500, "free_bytes": 500, "usage_percent": 50.0 },
            "disks": [],
            "network": { "bytes_recv_rate": 100, "bytes_sent_rate": 100 },
            "containers_summary": { "total": 1, "running": 1, "stopped": 0, "unhealthy": 0 }
          }
        }
        """.data(using: .utf8)!

        let event = try WebSocketEvent.decode(from: hostJson)
        XCTAssertEqual(event.type, "host_tick")
        if case .hostTick(let overview) = event.payload {
            XCTAssertEqual(overview.hostname, "srv-01")
        } else {
            XCTFail("Expected hostTick payload")
        }
    }
}
