# avif.swift

## What's This?

avif.swift the package to easy compress `UIImage` to `AVIF` and decompress `AVIF` to `UIImage`

Library uses precompiled `svt-av1` and `dav1d` to ensure in fast encoding/decoding

```swift
// Decompress data
let uiImage: UIImage? = AVIFImageDecoder().decode(Data(), sampleSize: .zero) // or any max CGSize of image
// Compress
let data: Data = try AVIFEncoder().encode(image: UIImage())
```

## TODO
- [ ] Tests
