# avif.swift

## What's This?

avif.swift the package to easy compress `UIImage` to `AVIF` and decompress `AVIF` to `UIImage`

Library uses precompiled `svt-av1` and `dav1d` to ensure in fast encoding/decoding

Supports animated AVIF's with realtime FPS like 24+
Also supports encoding animated AVIF's

Precompiled for iOS 14+, Mac OS 12+, Mac Catalyst 14+

## Installation

### [Swift Package Manager](https://swift.org/package-manager/)

Go to `File / Swift Packages / Add Package Dependency…`
and enter package repository URL https://github.com/awxkee/avif.swift.git, then select the latest master branch
at the time of writing.

## Usage

```swift
// Decompress data
let uiImage: UIImage? = AVIFDecoder().decode(Data(), sampleSize: .zero) // or any max CGSize of image
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

## Nuke Plugin
If you wish to use `AVIF` with <a href="https://github.com/kean/Nuke" target="_blank">`Nuke`</a> you may add `avifnuke` library to project and activate the plugin on app init

```swift
import avifnuke

AVIFNukePlugin.enable()

let imageView = UIImageView()
let avifimageURL = URL(string: "https://bestavifdomain.com/sample.avif")!
Nuke.loadImage(with: url, into: imageView)
```

Currently, avif nuke plugin do not support animated avifs so you have to do it yourself

## TODO
- [ ] Tests
- [ ] Some examples 
