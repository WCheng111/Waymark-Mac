import SwiftUI

struct PhotoSelectionDecoration: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusMedium)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, Color.accentColor)
                        .font(.system(size: 22)).padding(6).allowsHitTesting(false)
                }
            }
            .accessibilityValue(selected ? "已选中" : "未选中")
    }
}

struct PhotoBatchControls: View {
    @Environment(DataStore.self) private var store
    let placeID: UUID
    let photos: [Photo]
    @Binding var selection: Set<UUID>
    var compact = false
    @State private var editing: Batch?
    @State private var deleting: Batch?
    @State private var confirmDelete = false
    @State private var error: String?

    private struct Batch: Identifiable {
        let id = UUID()
        let photos: [Photo]
        var ids: Set<UUID> { Set(photos.map(\.id)) }
    }
    private var selected: [Photo] { photos.filter { selection.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("已选 \(selected.count) 张").font(.callout).monospacedDigit()
                Spacer()
                Button("全选") { selection = Set(photos.map(\.id)) }.disabled(photos.isEmpty)
                Button("取消选择") { selection.removeAll() }.disabled(selected.isEmpty)
                if !compact { actions }
            }
            if compact { HStack { actions; Spacer() } }
            Text("单击选中或取消，可连续多选；双击查看大图")
                .font(.caption).foregroundStyle(.secondary)
        }
        .sheet(item: $editing) { batch in
            PhotoBatchEditor(photos: batch.photos) { date, caption in
                try store.updatePhotos(ids: batch.ids, inPlace: placeID, capturedDate: date, caption: caption)
            }
        }
        .alert("删除 \(deleting?.photos.count ?? 0) 张照片？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) {
                guard let batch = deleting else { return }
                do {
                    try store.deletePhotos(ids: batch.ids, fromPlace: placeID)
                    selection.subtract(batch.ids)
                } catch { self.error = error.localizedDescription }
                deleting = nil
            }
        } message: {
            Text("将删除所选照片及 Waymark 保存的图片文件，无法撤销。不会删除地点或到访记录。")
        }
        .alert("删除失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
        .onChange(of: photos.map(\.id)) { _, ids in selection.formIntersection(ids) }
        .onChange(of: placeID) { _, _ in selection.removeAll() }
    }

    private var actions: some View {
        Group {
            Button("修改信息") { editing = Batch(photos: selected) }.disabled(selected.isEmpty)
            Button("删除", role: .destructive) {
                deleting = Batch(photos: selected)
                confirmDelete = true
            }.disabled(selected.isEmpty)
        }
    }
}
