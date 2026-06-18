//
// aus der Technik, on 15.05.23.
// https://www.ausdertechnik.de
//

import Foundation
import FileMonitorShared

#if os(macOS)
public final class MacosWatcher: WatcherProtocol {
    public var delegate: WatcherDelegate?
    let fileWatcher: FileWatcher
    private var lastFiles: [URL] = []

    required public init(directory: URL) throws {

        fileWatcher = FileWatcher([directory.path])
        fileWatcher.queue = DispatchQueue.global()
        lastFiles = try getCurrentFiles(in: directory)

        fileWatcher.callback = { [self] event throws in
            let url = URL(fileURLWithPath: event.path)
            let currentFiles = try getCurrentFiles(in: directory)

            let eventName = url.lastPathComponent
            let existedBefore = lastFiles.contains { $0.lastPathComponent == eventName }
            let existsNow = currentFiles.contains { $0.lastPathComponent == eventName }
            let removedFiles = getDifferencesInFiles(lhs: lastFiles, rhs: currentFiles)
            let addedFiles = getDifferencesInFiles(lhs: currentFiles, rhs: lastFiles)
            let changeSetCount = addedFiles.count - removedFiles.count

            func classify(removedFlag: Bool, createdFlag: Bool) -> FileChangeEvent {
                if (existedBefore && !existsNow) || removedFlag {
                    return .deleted(file: url)
                }

                if (!existedBefore && existsNow) || (createdFlag && !existedBefore) {
                    return .added(file: url)
                }

                return .changed(file: url)
            }

            if event.dirChange {
                self.delegate?.fileDidChanged(event: classify(removedFlag: event.dirRemoved, createdFlag: event.dirCreated))
                self.lastFiles = currentFiles
                return
            }

            if event.fileRemoved || (changeSetCount < 0 && !existsNow) {
                self.delegate?.fileDidChanged(event: .deleted(file: url))
            } else if (event.fileCreated && changeSetCount > 0) || (!existedBefore && existsNow) {
                self.delegate?.fileDidChanged(event: .added(file: url))
            } else {
                self.delegate?.fileDidChanged(event: .changed(file: url))
            }

            lastFiles = currentFiles
        }
    }

    deinit {
        stop()
    }

    public func observe() throws {
        fileWatcher.start()
    }

    public func stop() {
        fileWatcher.stop();
    }
}
#endif
