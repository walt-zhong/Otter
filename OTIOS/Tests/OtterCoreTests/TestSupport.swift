import Foundation
import XCTest
@testable import OtterCore

func expect(
    _ actual: String?,
    _ expected: String?,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(actual, expected, file: file, line: line)
}

func expectValue(
    _ actual: JSONValue?,
    _ expected: JSONValue,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(actual, expected, file: file, line: line)
}

func assertNumber(
    _ value: JSONValue?,
    int: Int,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let number = value?.number else {
        XCTFail("expected Number, got \(String(describing: value))", file: file, line: line)
        return
    }
    XCTAssertEqual(int, number.intValue, file: file, line: line)
}

func assertNumber(
    _ value: JSONValue?,
    double: Double,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let number = value?.number else {
        XCTFail("expected Number, got \(String(describing: value))", file: file, line: line)
        return
    }
    XCTAssertEqual(double, number.doubleValue, accuracy: 0, file: file, line: line)
}

func assertFails(
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ block: () throws -> Void
) {
    do {
        try block()
        XCTFail("期望抛出 TemplateParseException：\(message)", file: file, line: line)
    } catch let error as TemplateParseException {
        XCTAssertEqual(message, error.message, file: file, line: line)
    } catch {
        XCTFail("期望抛出 TemplateParseException：\(message) 实际 \(error)", file: file, line: line)
    }
}

func assertFailsPrefix(
    _ prefix: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ block: () throws -> Void
) {
    do {
        try block()
        XCTFail("期望抛出 TemplateParseException：\(prefix)", file: file, line: line)
    } catch let error as TemplateParseException {
        XCTAssertTrue(
            error.message.hasPrefix(prefix),
            error.message,
            file: file,
            line: line
        )
    } catch {
        XCTFail("期望抛出 TemplateParseException：\(prefix) 实际 \(error)", file: file, line: line)
    }
}

func isDirectory(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
}

func isFile(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue
}

func repoRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func firstExistingDirectory(_ relatives: [String]) -> URL? {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let root = repoRoot()
    let bases = [cwd, root]
    for relative in relatives {
        for base in bases {
            let candidate = base.appendingPathComponent(relative).standardizedFileURL
            if isDirectory(candidate.path) {
                return candidate
            }
        }
    }
    return nil
}
