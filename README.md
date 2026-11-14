# Refract

Refract is a native macOS and iPadOS app for applying glass distortion to photos, graphics, and type. The editor runs locally and uses the same renderer for previews and exports.

## Download

Grab **Refract-3.0-macOS.zip** from the [Releases page](../../releases/latest), unzip it, and move `Refract.app` to your Applications folder. It runs on Apple Silicon and Intel Macs with macOS 13 or later.

The app is ad hoc signed, not notarized. If macOS blocks the first launch, right-click `Refract.app`, choose **Open**, then confirm.

## Using Refract

- **Image** opens files or accepts a drop on the canvas. On iPad, you can also pick from Photos. A PDF opens on its first page.
- **Text** starts with an empty canvas. Type your text and choose a face, ink, and background.
- **Gradient** stays blank until you select **New Gradient**. Set the colors and direction in Adjustments, or switch to a radial gradient. **Clear Gradient** returns to the empty canvas.
- **Surfaces** contains 18 glass patterns. Add Microlens for a finer texture or use Coverage to restrict the effect to one half.
- **Custom Effects** is the wand in the toolbar. Create an effect, choose two surfaces, and adjust how they blend. You can set density, angle, offset, stretch, refraction, and microlens settings. Give your effect a name and save it to reuse later. Saving under an existing name updates that preset.
- **Export** saves PNG, JPEG, or TIFF in sRGB. PNG and TIFF preserve transparency. JPEG uses a white background wherever the artwork is transparent. The print setting writes 300 DPI metadata.

The canvas supports pinch-to-zoom on iPad and Mac trackpads. When built with Xcode 27 or later, the Mac build also enables direct-touch pinch on macOS 27 or later. Use **Fit Artwork** to reset it. On smaller windows, Effects and Adjustments open from the toolbar.

## Build

Open `Refract.xcodeproj` in Xcode. The project uses only Apple frameworks.

**Mac** — Select the Refract scheme and **My Mac**, then press **⌘R**. The app targets macOS 13+. To build for Apple Silicon and Intel:

```sh
xcodebuild -scheme Refract -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build \
  ARCHS='arm64 x86_64' build
```

The product is at `build/Build/Products/Release/Refract.app`. Local release builds are ad hoc signed. Public distribution with Gatekeeper approval requires your own Developer ID signing and notarization.

**iPad** — Select an iPad simulator or an iPad running iPadOS 17 or later, then press **⌘R**. For a physical iPad, choose your Team under **Signing & Capabilities**. If Xcode reports a bundle ID conflict, set a unique ID for your build. [Apple’s Developer Mode instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) cover running on a physical device. Public iPad distribution requires a signed distribution build.

## Source

- `StudioView.swift` contains the adaptive editor, import flow, and export controls.
- `EffectWorkshop.swift` contains the custom effect editor.
- `StudioModel.swift` manages previews and local preset storage.
- `Rendering/GlassRenderer.swift` converts artwork to an sRGB bitmap and encodes the output.
- `Rendering/Glass.cpp` contains the individual surface displacement functions and pixel sampler.

A surface returns a sampling offset and a highlight value. Custom Effects blend the offsets from two surfaces before sampling the source. The microlens layer adds a smaller offset around each lens center.

## License

[MIT](LICENSE)
