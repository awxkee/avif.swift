set -e

cargo +nightly build -Z build-std=std --target=x86_64-apple-ios --release
cargo +nightly build -Z build-std=std --target=x86_64-apple-darwin --release
cargo +nightly build -Z build-std=std --target=aarch64-apple-darwin --features rdm --release
cargo +nightly build -Z build-std=std --target=arm64e-apple-darwin --features rdm --release
cargo +nightly build -Z build-std=std --target=arm64e-apple-ios --release
cargo +nightly build -Z build-std=std --features rdm --target=aarch64-apple-ios --release
cargo +nightly build -Z build-std=std --features rdm --target=aarch64-apple-ios-sim --release

cargo +nightly build -Z build-std=std --features rdm --target=aarch64-apple-tvos --release
cargo +nightly build -Z build-std=std --features rdm --target=arm64e-apple-tvos --release
cargo +nightly build -Z build-std=std --target=aarch64-apple-tvos-sim --release

# Mac Catalyst targets
cargo +nightly build -Z build-std=std --features rdm --target=aarch64-apple-ios-macabi --release
cargo +nightly build -Z build-std=std --target=x86_64-apple-ios-macabi --release

mkdir -p target/universal_sim
mkdir -p target/universal_mac
mkdir -p target/universal_ios
mkdir -p target/universal_tvos
mkdir -p target/universal_maccatalyst
rm -rf target/universal_sim/libavifpixart.a
rm -rf target/universal_mac/libavifpixart.a
rm -rf target/universal_ios/libavifpixart.a
rm -rf target/universal_tvos/libavifpixart.a
rm -rf target/universal_maccatalyst/libavifpixart.a
lipo -create target/aarch64-apple-ios-sim/release/libavifpixart.a target/x86_64-apple-ios/release/libavifpixart.a -output target/universal_sim/libavifpixart.a
lipo -create target/x86_64-apple-darwin/release/libavifpixart.a target/aarch64-apple-darwin/release/libavifpixart.a target/arm64e-apple-darwin/release/libavifpixart.a -output target/universal_mac/libavifpixart.a
lipo -create target/aarch64-apple-ios/release/libavifpixart.a target/arm64e-apple-ios/release/libavifpixart.a -output target/universal_ios/libavifpixart.a
lipo -create target/aarch64-apple-tvos/release/libavifpixart.a target/arm64e-apple-tvos/release/libavifpixart.a -output target/universal_tvos/libavifpixart.a
lipo -create target/aarch64-apple-ios-macabi/release/libavifpixart.a target/x86_64-apple-ios-macabi/release/libavifpixart.a -output target/universal_maccatalyst/libavifpixart.a
rm -rf ../Sources/AvifPixart/AvifPixart.xcframework

mkdir -p ../Sources/AvifPixart

cbindgen --config cbindgen.toml --crate avifpixart --output include/avifpixart.h

xcodebuild -create-xcframework \
      -library target/universal_sim/libavifpixart.a -headers include \
      -library target/universal_mac/libavifpixart.a -headers include \
      -library target/universal_ios/libavifpixart.a -headers include \
      -library target/universal_tvos/libavifpixart.a -headers include \
      -library target/aarch64-apple-tvos-sim/release/libavifpixart.a -headers include \
      -library target/universal_maccatalyst/libavifpixart.a -headers include \
      -output ../Sources/AvifPixart/AvifPixart.xcframework

cp -r ../Sources/AvifPixart/AvifPixart.xcframework AvifPixart.xcframework
rm -rf AvifPixart.xcframework
