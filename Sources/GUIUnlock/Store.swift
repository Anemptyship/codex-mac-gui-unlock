import Foundation
import Darwin
import UnlockCore

final class Store {
    let dir: Int32
    let lock: Int32
    init() throws {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CodexMacGUIUnlock")
        if mkdir(url.path, 0o700) != 0 && errno != EEXIST { throw Failure.storage }
        dir = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard dir >= 0 else { throw Failure.storage }
        var st = stat()
        guard fstat(dir, &st) == 0, st.st_uid == getuid(), st.st_mode & 0o777 == 0o700 else { close(dir); throw Failure.storage }
        lock = openat(dir, "exclusive.lock", O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lock >= 0, fstat(lock, &st) == 0, st.st_uid == getuid(), st.st_nlink == 1,
              st.st_mode & S_IFMT == S_IFREG, st.st_mode & 0o777 == 0o600,
              flock(lock, LOCK_EX | LOCK_NB) == 0 else {
            if lock >= 0 { close(lock) }; close(dir); throw Failure.busy
        }
    }
    deinit { close(lock); close(dir) }
    enum Failure: Error { case storage, busy }
    func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        let fd = openat(dir, name, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { return nil }; defer { close(fd) }
        var st = stat()
        guard fstat(fd, &st) == 0, st.st_uid == getuid(), st.st_nlink == 1,
              st.st_mode & S_IFMT == S_IFREG, st.st_mode & 0o777 == 0o600, st.st_size <= 16384 else { return nil }
        var bytes = [UInt8](repeating: 0, count: Int(st.st_size))
        let count = bytes.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
        guard count == bytes.count else { return nil }
        return try? JSONDecoder().decode(type, from: Data(bytes))
    }
    func write<T: Encodable>(_ value: T, name: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        let temporary = UUID().uuidString + ".tmp"
        let fd = openat(dir, temporary, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { return false }
        let count = data.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
        let synced = fsync(fd) == 0; close(fd)
        guard count == data.count, synced, renameat(dir, temporary, dir, name) == 0 else { unlinkat(dir, temporary, 0); return false }
        return fsync(dir) == 0
    }
    func remove(_ name: String) -> Bool { unlinkat(dir, name, 0) == 0 || errno == ENOENT }
}
