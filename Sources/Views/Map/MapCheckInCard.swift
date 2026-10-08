import SwiftUI
import CoreLocation

/// A deliberate second step after picking a map coordinate. The existing
/// editor resolves the address and collects the visit date before saving.
struct MapCheckInCard: View {
    let coordinate: CLLocationCoordinate2D
    var name: String? = nil
    var onCheckIn: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(name ?? "已选位置", systemImage: "mappin.and.ellipse")
                    .font(.system(size: WaymarkType.callout, weight: .semibold))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("取消选点")
                .accessibilityLabel("取消选点")
            }

            Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                .font(.system(size: WaymarkType.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("可继续点击地图调整位置")
                .font(.system(size: WaymarkType.footnote))
                .foregroundStyle(.secondary)

            Button(action: onCheckIn) {
                Label("在这里打卡", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(WaymarkMetric.cardPadding)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusLarge))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}
