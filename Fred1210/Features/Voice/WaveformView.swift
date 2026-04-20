import SwiftUI

/// Simple bar-graph waveform. Each bar's height is driven by one sample
/// in ``levels`` (0..1). Bars shift left as new samples append, so the
/// newest level sits at the right edge — matches the mental model of
/// "what's being recorded right now".
struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { geometry in
            let barCount = max(1, levels.count)
            let totalWidth = geometry.size.width
            let barWidth = max(2, (totalWidth - CGFloat(barCount - 1) * 3) / CGFloat(barCount))
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.primary)
                        .frame(
                            width: barWidth,
                            height: max(4, CGFloat(level) * geometry.size.height)
                        )
                        .animation(.easeInOut(duration: 0.08), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
