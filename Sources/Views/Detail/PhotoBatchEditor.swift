import SwiftUI

struct PhotoBatchEditor: View {
    let photos: [Photo]
    var onSave: (Date?, String?) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var changeDate = false
    @State private var changeCaption = false
    @State private var date: Date
    @State private var caption = ""
    @State private var error: String?

    init(photos: [Photo], onSave: @escaping (Date?, String?) throws -> Void) {
        self.photos = photos
        self.onSave = onSave
        _date = State(initialValue: photos.first?.capturedDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("修改 \(photos.count) 张照片的信息").font(.headline)
            Text("仅修改勾选的字段，应用到本次选中的全部照片。")
                .font(.callout).foregroundStyle(.secondary)
            Toggle("修改拍摄时间", isOn: $changeDate)
            DatePicker("统一拍摄时间", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .disabled(!changeDate)
            Divider()
            Toggle("修改说明", isOn: $changeCaption)
            TextField("统一说明（留空则清除原说明）", text: $caption, axis: .vertical)
                .lineLimit(3...5).textFieldStyle(.roundedBorder).disabled(!changeCaption)
            Text("不会修改原图 EXIF 或地点的到访记录。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存修改") {
                    do {
                        try onSave(changeDate ? date : nil, changeCaption ? caption : nil)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!changeDate && !changeCaption)
            }
        }
        .padding(20).frame(width: 460)
        .alert("修改失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }
}
