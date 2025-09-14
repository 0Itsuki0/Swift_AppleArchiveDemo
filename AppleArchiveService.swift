
import SwiftUI
import AppleArchive
import System

extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

class AppleArchiveService {
    private static let destinationDirectory = FileManager.default.temporaryDirectory
    
    static func compressDirectory(source: URL) throws -> URL? {
        
        guard FileManager.default.fileExists(atPath: source.path()) else {
            print("Source file/directory does not exist")
            return nil
        }
   
        var source = source
        var isDirectory = source.isDirectory
        
        // encodeStream.writeDirectoryContents requires the archiveFrom path to be a directory.
        //
        // if the source is a path, an alternative will be
        // 1. Create a read-only file stream to read the source file directly using fileStream(path:mode:options:permissions:)
        // 2. Call ArchiveByteStream.process(readingFrom: readFileStream, writingTo: compressStream) to Compress the source file, ie: skip the encoding stream
        if !isDirectory {
            let prevURL = source
            guard let sourceName = source.pathComponents.last else {
                print("failed to get source name")
                return nil
            }
            
            source = destinationDirectory.appending(path: source.deletingPathExtension().pathComponents.last ?? "tmp")
            if !FileManager.default.fileExists(atPath: source.path()) {
                try FileManager.default.createDirectory(atPath: source.path(), withIntermediateDirectories: true)
            }
            
            try FileManager.default.copyItem(at: prevURL, to: source.appending(path: sourceName))
        }
        
        
        guard let sourceDirectoryName = source.pathComponents.last else {
            print("failed to get source name")
            return nil
        }

        
        // Create source path
        guard let sourcePath = FilePath(source) else {
            print("Error creating source file path")
            return nil
        }
        
       
        // Create the file stream to write the compressed file
        let destinationURL = destinationDirectory.appending(path: "\(sourceDirectoryName).aar")

        guard let destinationPath = FilePath(destinationURL) else {
            print("Error creating destination file path")
            return nil
        }
        
        guard let writeFileStream = ArchiveByteStream.fileStream(
            path: destinationPath,
            mode: .writeOnly,
            options: [.create],
            permissions: [.ownerReadWrite, .groupRead, .otherRead] // same as FilePermissions(rawValue: 0o644)
        ) else {
            return nil
        }
        defer {
            try? writeFileStream.close()
        }
        
        // Create compression stream
        guard let compressStream = ArchiveByteStream.compressionStream(
            using: .zlib,
            writingTo: writeFileStream
        ) else {
            return nil
        }
        defer {
            try? compressStream.close()
        }
        
        // create encode stream
        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else {
            return nil
        }
        defer {
            try? encodeStream.close()
        }


        // Define the header keys
        // defaultForArchive: Same as ArchiveHeader.FieldKeySet(["CLC", "HLC", "GID", "UID", "MOD", "FLG", "LNK", "BTM", "CTM", "MTM", "TYP", "DAT", "PAT", "DEV"])
        let headerKeys: ArchiveHeader.FieldKeySet = .defaultForArchive
        
        
        // Compress Content
        try encodeStream.writeDirectoryContents(
            archiveFrom: sourcePath,
            keySet: headerKeys,
            flags: [] // archiveDeduplicateData, ignoreOperationNotPermitted, and etc.
        )
      
        if isDirectory {
            try? FileManager.default.removeItem(at: source)
        }
        return destinationURL
    }
    
    static func decompressDirectory(source: URL) throws -> URL? {
        guard FileManager.default.fileExists(atPath: source.path()) else {
            print("Source file/directory does not exist")
            return nil
        }
        
        guard let sourceDirectoryName = source.deletingPathExtension().pathComponents.last else {
            print("failed to get source directory name")
            return nil
        }
        
        // Create read stream to the source aar file
        guard let sourcePath = FilePath(source) else {
            print("Error creating source file path")
            return nil
        }
        
        guard let readFileStream = ArchiveByteStream.fileStream(
            path: sourcePath,
            mode: .readOnly,
            options: [],
            permissions: [.ownerReadWrite, .groupRead, .otherRead] // same as FilePermissions(rawValue: 0o644)
        ) else {
            return nil
        }
        defer {
            try? readFileStream.close()
        }

        
        // create decompress stream
        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream) else {
            print("unable to create decompress stream")
            return nil
        }
        defer {
            try? decompressStream.close()
        }
        
        // create decode stream
        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else {
            print("unable to create decode stream")
            return nil
        }
        defer {
            try? decodeStream.close()
        }
        
       
        // Create the file stream to write the compressed file
        let destinationURL = destinationDirectory.appending(path: sourceDirectoryName)
        
        if !FileManager.default.fileExists(atPath: destinationURL.path()) {
            try FileManager.default.createDirectory(atPath: destinationURL.path(), withIntermediateDirectories: true)
        }

        guard let destinationPath = FilePath(destinationURL) else {
            print("Error creating destination file path")
            return nil
        }        
        
        // create extract stream
        guard let extractStream = ArchiveStream.extractStream(
            extractingTo: destinationPath,
            flags: [] // ignoreOperationNotPermitted, extractNoAutoSparse, extractNoAutoDeduplicate, and etc
        ) else {
            return nil
        }
        defer {
            try? extractStream.close()
        }

        let processedBytes = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
        print("processedBytes: \(processedBytes)")
        
        return destinationURL
    }
}

