import Foundation

public struct ExecResult: Codable, Sendable {
    public let command: String
    public let stdout: String
    public let stderr: String
    public let exitCode: Int
    public let durationMs: Int64

    enum CodingKeys: String, CodingKey {
        case command
        case stdout
        case stderr
        case exitCode = "exit_code"
        case durationMs = "duration_ms"
    }

    public init(
        command: String,
        stdout: String,
        stderr: String,
        exitCode: Int,
        durationMs: Int64
    ) {
        self.command = command
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.durationMs = durationMs
    }

    public var isSuccess: Bool {
        exitCode == 0
    }
}
