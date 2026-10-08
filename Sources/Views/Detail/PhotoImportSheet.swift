import SwiftUI

/// Confirmation step between picking files and writing them into the library:
/// shows the EXIF date the app read out of each photo so a wrong one can be
/// corrected before it decides the photo's place in the timeline.
struct PhotoImportSheet: View {
    @State var drafts: [ImportedPhotoDraft]
    let placeName: String
    var onImport: ([Photo]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var batchDate: Date
    @State private var batchDateApplied = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    init(drafts: [ImportedPhotoDraft], placeName: String, onImport: @escaping ([Photo]) -> Void) {
        _drafts = State(initialValue: drafts)
        _batchDate = State(initialValue: drafts.first?.capturedDate ?? Date())
        self.placeName = placeName
        self.onImport = onImport
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("导入 \(drafts.count) 张照片")
                        .font(.system(size: WaymarkType.callout, weight: .semibold))
                    Text("将归入「\(placeName)」")
                        .font(.system(size: WaymarkType.footnote))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if drafts.contains(where: \.hasCoordinate) {
                    Label("\(drafts.filter(\.hasCoordinate).count) 张带 GPS 位置", systemImage: "location.fill")
                        .font(.system(size: WaymarkType.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    DatePicker("统一日期", selection: $batchDate, displayedComponents: [.date])
                        .fixedSize()
                        .onChange(of: batchDate) { _, _ in batchDateApplied = false }
                    Spacer()
                    Button("应用到全部 \(drafts.count) 张") {
                        PhotoImportService.applyCaptureDate(batchDate, to: &drafts)
                        batchDateApplied = true
                    }
                }
                Text(batchDateApplied ? "已应用统一日期，仍可在下方逐张调整" : "选择日期后点击“应用到全部”，即可批量修改这一批照片")
                    .font(.system(size: WaymarkType.caption))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .disabled(drafts.isEmpty || isImporting)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach($drafts) { $draft in
                        DraftCard(draft: $draft) {
                            drafts.removeAll { $0.id == draft.id }
                        }
                    }
                }
                .padding(12)
            }
            .disabled(isImporting)

            Divider()

            HStack {
                Text("日期修改仅用于 Waymark，不改动原图 EXIF")
                    .font(.system(size: WaymarkType.caption))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    performImport()
                } label: {
                    if isImporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("导入")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(drafts.isEmpty || isImporting)
            }
            .padding(12)
        }
        .frame(width: 640, height: 520)
    }

    private func performImport() {
        isImporting = true
        // Copying + thumbnailing a folder of photos is slow enough to freeze
        // the window, so it runs off the main actor and reports back once.
        let snapshot = drafts
        Task.detached(priority: .userInitiated) {
            let photos = snapshot.compactMap { try? PhotoImportService.makePhoto(from: $0) }
            await MainActor.run {
                onImport(photos)
                dismiss()
            }
        }
    }
}

private struct DraftCard: View {
    @Binding var draft: ImportedPhotoDraft
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let image = NSImage(contentsOf: draft.sourceURL) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 110)
                        .clipped()
                } else {
                    Rectangle().fill(.quaternary).frame(height: 110)
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .padding(5)
            }
            .clipShape(RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusSmall))

            Text(draft.fileName)
                .font(.system(size: WaymarkType.caption))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            DatePicker("", selection: $draft.capturedDate, displayedComponents: [.date])
                .labelsHidden()
                .controlSize(.small)

            TextField("说明（可选）", text: $draft.caption)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
        }
        .padding(8)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusMedium))
    }
}

/// Logs a new visit, or edits an existing one. One view for both because the
/// fields are identical and the only difference is whether the saved `Visit`
/// carries a fresh id or the one it already had.
struct VisitEditorSheet: View {
    var existing: Visit?
    var onSave: (Visit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var note: String

    init(existing: Visit? = nil, onSave: @escaping (Visit) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _date = State(initialValue: existing?.date ?? Date())
        _note = State(initialValue: existing?.note ?? "")
    }

    private var isEditing: Bool { existing != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "编辑到访记录" : "新增到访记录")
                    .font(.system(size: WaymarkType.callout, weight: .semibold))
                Spacer()
            }
            .padding(12)

            Divider()

            Form {
                DatePicker(
                    "到访日期",
                    selection: $date,
                    in: WaymarkDateFormat.visitDateRange,
                    displayedComponents: .date
                )
                TextField("到访感受（可选）", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    var visit = existing ?? Visit()
                    visit.date = date
                    visit.note = note
                    onSave(visit)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 360, height: 260)
    }
}
