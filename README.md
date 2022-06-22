# avif.swift

## What's This?

avif.swift the package to easy compress `UIImage` to `AVIF` and decompress `AVIF` to `UIImage`

Library uses precompiled `svt-av1` and `dav1d` to ensure in fast encoding/decoding

Supports animated AVIF's with realtime FPS like 24+
Also supports encoding animated AVIF's

```swift
// Decompress data
let uiImage: UIImage? = AVIFImageDecoder().decode(Data(), sampleSize: .zero) // or any max CGSize of image
// Compress
let data: Data = try AVIFEncoder().encode(image: UIImage())

// Decode animated
let animatedDecoder = AnimatedDecoder(withData: Data())
let frame: CGImage = try animatedDecoder.get(frame: 1)
let image: UIImage = try animatedDecoder.getImage(frame: 1) 

// Encode animation
import avifc

let animatedEncoder = AVIFAnimatedEncoder()
animatedEncoder.create()
try animatedEncoder.addImage(UIImage(), duration: 250)
let encodedData = animatedEncoder.encode()
```

## TODO
- [ ] Tests
- [ ] Some examples 
