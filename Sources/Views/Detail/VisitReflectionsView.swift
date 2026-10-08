import SwiftUI

/// The editor belongs to one visit, never to the place-wide legacy notes field.
struct VisitReflectionsView: View {
    @Environment(DataStore.self) private var store
    let placeID: UUID
    let preferredVisitID: UUID?
    var onAddVisit: () -> Void
    @State private var saveError: String?

    var body: some View {
        if let place = store.place(id: placeID) {
            let visit = place.reflectionVisit(preferredID: preferredVisitID)
            VStack(alignment: .leading, spacing: 6) {
                Text("到访感受")
                    .font(.system(size: WaymarkType.footnote))
                    .foregroundStyle(.secondary)
                if let visit {
                    Text(WaymarkDateFormat.dayMonthYear.string(from: visit.date))
                        .font(.system(size: WaymarkType.footnote, weight: .semibold))
                    VisitFeelingEditor(text: visit.note) { value in
                        try store.updateVisitFeeling(value, visitID: visit.id, placeID: placeID)
                    }
                    .id(visit.id)
                    Text("仅保存到这次到访；点击上方其他记录可切换。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("先添加到访记录，即可记录这次的感受。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("添加到访记录", action: onAddVisit)
                }

                if !place.notes.isEmpty {
                    Divider()
                    Text("历史到访感受（未关联记录）")
                        .font(.system(size: WaymarkType.footnote, weight: .semibold))
                    Text(place.notes).font(.system(size: WaymarkType.body)).textSelection(.enabled)
                    Text("这是旧版保存的内容，请选择对应到访后归入；已有感受不会被覆盖。")
                        .font(.caption).foregroundStyle(.secondary)
                    if let visit {
                        Button("归入当前选中的到访") {
                            do { try store.assignLegacyFeeling(toVisit: visit.id, placeID: placeID) }
                            catch { saveError = error.localizedDescription }
                        }
                    }
                }
            }
            .alert("到访感受保存失败", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("好") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }
}
