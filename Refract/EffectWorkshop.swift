import SwiftUI

struct EffectWorkshop: View {
    @ObservedObject var model: StudioModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Custom Effects").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 18)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let image = model.preview, model.artwork.canRender {
                        Image(decorative: image, scale: 1)
                            .resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 190)
                            .accessibilityLabel("Custom effect preview")
                    } else {
                        Text("Open artwork to preview your effect.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let surface = Binding($model.options.custom) {
                        HStack {
                            surfacePicker("Base", selection: Binding(
                                get: { model.options.effect.id.rawValue },
                                set: { id in
                                    if let effect = GlassEffect.all.first(where: { $0.id.rawValue == id }) {
                                        model.options.effect = effect
                                    }
                                }
                            ))
                            surfacePicker("Blend with", selection: surface.secondaryID)
                        }
                        ValueSlider("Blend", value: surface.blend, range: 0...1, unit: .percent)
                        ValueSlider("Second density", value: surface.density, range: 0.35...3, unit: .decimal)
                        ValueSlider("Second angle", value: surface.angle, range: -180...180, unit: .degrees)
                        ValueSlider("Pattern offset", value: surface.phase, range: -4...4, unit: .decimal)
                        ValueSlider("Horizontal stretch", value: surface.stretch, range: 0.4...2.5, unit: .decimal)
                        Divider()
                        RefractionControls(settings: $model.options)
                        Toggle("Microlens", isOn: $model.options.microlens).toggleStyle(.switch)
                        if model.options.microlens {
                            ValueSlider("Texture", value: $model.options.lensAmount, range: 0...1, unit: .percent)
                            ValueSlider("Lens density", value: $model.options.lensDensity, range: 22...180)
                        }
                        HStack {
                            TextField("Preset name", text: $model.presetName).textFieldStyle(.roundedBorder)
                            Button("Save Preset") { model.savePreset(name: model.presetName) }
                                .buttonStyle(.borderedProminent)
                                .disabled(model.presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if let notice = model.presetNotice {
                            Label(notice, systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Create Effect", action: model.beginCustomEffect).buttonStyle(.borderedProminent)
                    }

                    if !model.presets.isEmpty {
                        Divider()
                        Text("Saved Presets").font(.headline)
                        ForEach(model.presets) { preset in
                            HStack {
                                Button(preset.name) {
                                    model.apply(preset)
                                    model.presetName = preset.name
                                }
                                Spacer()
                                Button(role: .destructive) { model.delete(preset) } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("Delete \(preset.name)")
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
                .padding(18)
            }
        }
        #if os(macOS)
        .frame(width: 475, height: 640)
        #endif
    }

    private func surfacePicker(_ title: String, selection: Binding<UInt32>) -> some View {
        Picker(title, selection: selection) {
            ForEach(GlassEffect.all) { Text($0.name).tag($0.id.rawValue) }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

struct RefractionControls: View {
    @Binding var settings: GlassSettings

    var body: some View {
        ValueSlider("Intensity", value: $settings.strength, range: 0...1.65, unit: .percent)
        ValueSlider("Density", value: $settings.scale, range: 3...42)
        ValueSlider("Angle", value: $settings.angle, range: -180...180, unit: .degrees)
        ValueSlider("Color fringe", value: $settings.dispersion, range: 0...1, unit: .percent)
        ValueSlider("Highlights", value: $settings.light, range: 0...1, unit: .percent)
    }
}

struct ValueSlider: View {
    enum Unit {
        case number, percent, degrees, decimal
    }

    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: Unit

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: Unit = .number) {
        self.title = title
        _value = value
        self.range = range
        self.unit = unit
    }

    private var label: String {
        switch unit {
        case .number: String(Int(value.rounded()))
        case .percent: "\(Int((value * 100).rounded()))%"
        case .degrees: "\(Int(value.rounded()))°"
        case .decimal: value.formatted(.number.precision(.fractionLength(2)))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(label).monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.caption)
            .accessibilityHidden(true)
            Slider(value: $value, in: range) { Text(title) }
                .labelsHidden()
                .accessibilityValue(label)
        }
        #if os(iOS)
        .frame(minHeight: 44)
        #endif
    }
}
