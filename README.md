# Swift_AppleArchiveDemo
A demo of using apple archive framework to compress(archive) directories and unarchive .aar files.

Apple Archive (.aar) is a format for both Archiving and compression created by Apple.

On Mac, to extract such an archive, all we have to do is to double click on it, just like we could for all the other more universal formats such as zip! 

This demo includes how we can use the [Apple archive](https://developer.apple.com/documentation/applearchive) framework to 
- Compress and Archive directories and files to .aar files.
- Decompress and extract .aar archives.

For more detiails, please check out my article [Swift: Compress and Decompress Files & Directories with Apple Archive]().

## Sample Usage
```
let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appending(path: "test")
let destinationURL = try AppleArchiveService.compressDirectory(source: url)
let _ = try AppleArchiveService.decompressDirectory(source: destinationURL!)
```
