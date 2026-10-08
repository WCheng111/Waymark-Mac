import SwiftUI

/// Read-only by default. A new visit identity recreates this local editing state.
struct VisitFeelingEditor: View {
    let text: String
    let onSave: (String) throws -> Void
    @State private var isEditing = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if isEditing {
                FeelingTextEditor(text: text, onChange: { save($0) }, onFinish: { value in
                    if save(value) { isEditing = false }
                })
                .frame(height: 140)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.6)))
                Text("编辑中 · Enter 完成 · Shift+Enter 换行")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(text.isEmpty ? "尚未填写到访感受，双击这里开始记录。" : text)
                    .font(.system(size: WaymarkType.body))
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .contentShape(Rectangle())
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    .onTapGesture(count: 2) { isEditing = true }
                    .accessibilityLabel("到访感受（阅读模式）")
                    .accessibilityValue(text)
                    .accessibilityAction(named: "编辑到访感受") { isEditing = true }
                    .contextMenu {
                        Button("编辑到访感受") { isEditing = true }
                        Button("复制全文") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }.disabled(text.isEmpty)
                    }
                Text("阅读模式 · 双击文字编辑")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .alert("到访感受保存失败", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("好") { saveError = nil }
        } message: { Text(saveError ?? "") }
    }

    @discardableResult
    private func save(_ value: String) -> Bool {
        do {
            try onSave(value)
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}
