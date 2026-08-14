import SwiftUI
import UIKit

struct V3MediaManagementOverlayView: View {
    @State private var draft: [V3HomeLibraryPreference]
    @State private var carouselEnabled: Bool
    @Binding var carouselDisplayRange: Double
    @State private var isAdjustingRange = false
    @State private var defaultSnapLatched = false

    let onClose: () -> Void
    let onPreferencesChanged: ([V3HomeLibraryPreference], Bool) -> Void
    let onRangeCommit: (Double) -> Void

    init(preferences: [V3HomeLibraryPreference], carouselEnabled: Bool, carouselDisplayRange: Binding<Double>, onClose: @escaping () -> Void, onPreferencesChanged: @escaping ([V3HomeLibraryPreference], Bool) -> Void, onRangeCommit: @escaping (Double) -> Void) {
        _draft = State(initialValue: preferences)
        _carouselEnabled = State(initialValue: carouselEnabled)
        _carouselDisplayRange = carouselDisplayRange
        self.onClose = onClose
        self.onPreferencesChanged = onPreferencesChanged
        self.onRangeCommit = onRangeCommit
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .opacity(isAdjustingRange ? 0.035 : 1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .opacity(isAdjustingRange ? 0.04 : 1)

                Text("长按拖动可调整首页顺序")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .opacity(isAdjustingRange ? 0.04 : 1)

                carouselControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                libraryPreferences
                    .opacity(isAdjustingRange ? 0.035 : 1)
            }
        }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.16), value: isAdjustingRange)
        .onChange(of: draft) { value in onPreferencesChanged(value, carouselEnabled) }
        .onChange(of: carouselEnabled) { value in onPreferencesChanged(draft, value) }
    }

    private var header: some View {
        HStack {
            Button {
                onRangeCommit(carouselDisplayRange)
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text("媒体管理").font(.title2.weight(.bold))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var carouselControls: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $carouselEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("轮播图").font(.body.weight(.semibold))
                    Text("一键控制首页沉浸轮播，关闭不会清除下方媒体库选择")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.green)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .opacity(isAdjustingRange ? 0.04 : 1)

            Divider().opacity(isAdjustingRange ? 0.04 : 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("轮播展示范围")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Text("更小").font(.caption).foregroundColor(.secondary)
                    markedRangeSlider
                    Text("更大").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .opacity(isAdjustingRange ? 0.42 : (carouselEnabled ? 1 : 0.55))
            .allowsHitTesting(carouselEnabled)
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .opacity(isAdjustingRange ? 0.05 : 1)
        )
    }

    private var markedRangeSlider: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 14
            let usableWidth = max(0, geometry.size.width - inset * 2)
            ZStack {
                Slider(value: snappedRangeBinding, in: 0...1, onEditingChanged: handleRangeEditing)

                Circle()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .position(x: inset, y: geometry.size.height / 2)

                Circle()
                    .fill(Color.secondary.opacity(0.62))
                    .frame(width: 3, height: 3)
                    .position(x: inset + usableWidth * 0.30, y: geometry.size.height / 2)

                Circle()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .position(x: inset + usableWidth, y: geometry.size.height / 2)
            }
        }
        .frame(height: 32)
    }

    private var snappedRangeBinding: Binding<Double> {
        Binding(
            get: { carouselDisplayRange },
            set: { rawValue in
                let raw = min(1, max(0, rawValue))
                let distance = abs(raw - 0.30)
                if distance <= 0.022 {
                    if !defaultSnapLatched {
                        let feedback = UISelectionFeedbackGenerator()
                        feedback.prepare()
                        feedback.selectionChanged()
                    }
                    defaultSnapLatched = true
                    carouselDisplayRange = 0.30
                } else {
                    if distance >= 0.05 { defaultSnapLatched = false }
                    carouselDisplayRange = raw
                }
            }
        )
    }

    private func handleRangeEditing(_ editing: Bool) {
        if editing {
            defaultSnapLatched = abs(carouselDisplayRange - 0.30) <= 0.002
            isAdjustingRange = true
        } else {
            isAdjustingRange = false
            onRangeCommit(carouselDisplayRange)
        }
    }

    private var libraryPreferences: some View {
        List {
            Section {
                ForEach($draft) { $preference in
                    HStack(spacing: 12) {
                        Text(preference.name)
                            .font(.body)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Toggle("首页", isOn: $preference.showOnHome)
                            .labelsHidden()
                            .tint(.green)
                            .frame(width: 62)

                        Toggle("轮播", isOn: $preference.includeInCarousel)
                            .labelsHidden()
                            .tint(.green)
                            .frame(width: 62)
                            .opacity(carouselEnabled ? 1 : 0.55)
                    }
                    .frame(minHeight: 44)
                    .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 12))
                }
                .onMove { source, destination in draft.move(fromOffsets: source, toOffset: destination) }
            } header: {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Text("首页").font(.caption2).foregroundColor(.secondary).frame(width: 62)
                    Text("轮播").font(.caption2).foregroundColor(.secondary).frame(width: 62)
                    Spacer().frame(width: 30)
                }
                .textCase(nil)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .environment(\.editMode, .constant(.active))
    }
}