import PhotosUI
import SwiftUI
import UIKit

struct AddMemorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingEntry: MemoryTimelineEntry?
    let onSave: (MemoryTimelineEntry) -> Void

    @State private var title: String
    @State private var date: Date
    @State private var recordBody: String
    @State private var category: MemoryCategory
    @State private var mood: String
    @State private var location: String
    @State private var weather: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoPreview: UIImage?
    @State private var removeExistingPhoto: Bool
    @State private var isLoadingPhoto = false
    @State private var imageErrorMessage: String?

    init(
        existingEntry: MemoryTimelineEntry? = nil,
        onSave: @escaping (MemoryTimelineEntry) -> Void
    ) {
        self.existingEntry = existingEntry
        self.onSave = onSave
        _title = State(initialValue: existingEntry?.title ?? "")
        _date = State(initialValue: existingEntry?.date ?? .now)
        _recordBody = State(initialValue: existingEntry?.body ?? "")
        _category = State(initialValue: existingEntry?.category ?? .date)
        _mood = State(initialValue: existingEntry?.mood ?? "")
        _location = State(initialValue: existingEntry?.location ?? "")
        _weather = State(initialValue: existingEntry?.weather ?? "")
        _removeExistingPhoto = State(initialValue: false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("把这一刻认真写成一条生活记录")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("不用写成长文，也不需要像正式日记那样完整。只要把标题和正文留住，这段生活就会更像真正被记下来了。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("给这段生活一个标题", text: $title)
                        .textInputAutocapitalization(.sentences)

                    DatePicker("日期", selection: $date, displayedComponents: .date)

                    TextField("把当时发生的事写下来", text: $recordBody, axis: .vertical)
                        .lineLimit(6...10)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)

                Section("这段记录的气味") {
                    TextField("那时的心情", text: $mood)
                    TextField("发生在哪里", text: $location)
                    TextField("天气怎么样", text: $weather)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)

                Section(existingEntry == nil ? "补一张图片（可选）" : "记录里的图片") {
                    if let currentPhotoPreview {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(uiImage: currentPhotoPreview)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 188)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous)
                                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                                )

                            Text("图片会作为这条记录的补充语境，一起留在本地。")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.subtitle)

                            Button("移除这张图片", role: .destructive) {
                                clearSelectedPhoto()
                                removeExistingPhoto = true
                            }
                            .font(.footnote.weight(.medium))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(existingEntry == nil
                                 ? "可以补一张照片，把当时的空气感也一起留住。"
                                 : "这条记录现在没有附图，编辑时会先保留这轮的轻量边界。")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.subtitle)

                            Text(existingEntry == nil
                                 ? "这一轮只支持单张图片，不会把记录变成相册。"
                                 : "本轮编辑支持保留或移除原图，不顺手扩成图片替换流程。")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.deepAccent)
                        }
                        .padding(.vertical, 2)
                    }

                    if existingEntry == nil {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(
                                selectedPhotoPreview == nil
                                    ? (isLoadingPhoto ? "正在读取图片…" : "选择一张图片")
                                    : "重新选择图片",
                                systemImage: selectedPhotoPreview == nil ? "photo.badge.plus" : "photo"
                            )
                        }
                        .disabled(isLoadingPhoto)
                    }
                }
                .listRowBackground(AppTheme.Colors.cardBackground)

                Section {
                    Picker("类型选择", selection: $category) {
                        ForEach(MemoryCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .navigationTitle(existingEntry == nil ? "新增记录" : "编辑记录")
            .secondaryPageNavigationStyle()
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadPhoto(from: newItem)
                }
            }
            .alert("图片暂时不可用", isPresented: imageAlertBinding) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(imageErrorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(existingEntry == nil ? "保存" : "更新") {
                        saveMemory()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || isLoadingPhoto)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedBody: String {
        recordBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedMood: String {
        mood.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedWeather: String {
        weather.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedTitle.isEmpty && !normalizedBody.isEmpty
    }

    private var currentPhotoPreview: UIImage? {
        if let selectedPhotoPreview {
            return selectedPhotoPreview
        }

        guard !removeExistingPhoto else { return nil }
        return existingEntry.flatMap { MemoryPhotoStorage.uiImage(for: $0.photoFilename) }
    }

    private var imageAlertBinding: Binding<Bool> {
        Binding(
            get: { imageErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    imageErrorMessage = nil
                }
            }
        )
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            clearSelectedPhoto()
            return
        }

        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                throw MemoryPhotoStorageError.invalidImageData
            }

            selectedPhotoData = data
            selectedPhotoPreview = image
        } catch {
            clearSelectedPhoto()
            imageErrorMessage = error.localizedDescription
        }
    }

    private func saveMemory() {
        do {
            let entryID = existingEntry?.id ?? UUID()
            let photoFilename: String?

            if let existingEntry {
                photoFilename = removeExistingPhoto ? nil : existingEntry.photoFilename
            } else {
                photoFilename = try selectedPhotoData.map { data in
                    try MemoryPhotoStorage.saveImageData(data, for: entryID)
                }
            }

            onSave(
                MemoryTimelineEntry(
                    id: entryID,
                    title: normalizedTitle,
                    body: normalizedBody,
                    date: date,
                    category: category,
                    imageLabel: category.rawValue,
                    photoFilename: photoFilename,
                    mood: normalizedMood,
                    location: normalizedLocation,
                    weather: normalizedWeather,
                    isFeatured: existingEntry?.isFeatured ?? false,
                    spaceId: existingEntry?.spaceId ?? AppDataDefaults.localSpaceId,
                    createdByUserId: existingEntry?.createdByUserId ?? AppDataDefaults.localUserId,
                    createdAt: existingEntry?.createdAt ?? .now,
                    updatedAt: existingEntry?.updatedAt,
                    syncStatus: existingEntry?.syncStatus ?? .localOnly
                )
            )
            dismiss()
        } catch {
            imageErrorMessage = error.localizedDescription
        }
    }

    private func clearSelectedPhoto() {
        selectedPhotoItem = nil
        selectedPhotoData = nil
        selectedPhotoPreview = nil
    }
}
