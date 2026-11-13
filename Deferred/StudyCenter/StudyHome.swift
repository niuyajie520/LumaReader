// === PROJECT RED LINE / 项目红线 BEGIN ===
// 听力与写作学习中心核心组件保护规则：
// 1. 红黄绿窗口控制与顶部胶囊工具栏布局与悬停显隐必须完整保持。
// 2. 写作题目的选文笔记、高亮及其操作流程（划词即现、编辑、删除）必须严格保留。
// 3. 听写输入框、自适应字号排版，以及摇晃、红闪、红光阴影等错误反馈必须严格保留。
// 4. 听写进度条（dictationProgressRail）必须保持常驻，提供精确百分比与完成统计。
// 5. 听力分类布局（三级文件夹树、图标卡片、一键听写）与错词复习布局必须保持优雅统一。
// 完整规则见项目根目录 AGENTS.md；所有开发者与 AI 必须遵守。
// All developers and AI assistants must follow the project-root AGENTS.md.
// === PROJECT RED LINE / 项目红线 END ===
import SwiftUI
import AppKit
import Combine
import Charts
import GameController
import UniformTypeIdentifiers
#if canImport(SwiftUI) && canImport(AppKit)

// MARK: - Task 2 Row Card & Topic / Bank Management Sheets

struct LumaTask2TopicCardView: View {
    @Environment(\.studyAppearance) private var appearance
    let item: LumaTask2TopicItem
    let isSelected: Bool
    let draftMinutesLeft: Int?

    private var subtitleText: String {
        var parts: [String] = [item.category]
        if item.subCategory != item.category && !item.subCategory.isEmpty {
            parts.append(item.subCategory)
        }
        if let date = item.examDate, !date.isEmpty {
            parts.append(date)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(item.id) · \(item.shortTitle)")
                        .lumaFont(size: 15, weight: .semibold)
                        .foregroundStyle(appearance.ink)
                        .lineLimit(1)
                    if let draftMinutesLeft {
                        Text("进行中 · 剩 \(draftMinutesLeft)m")
                            .lumaFont(size: 11, weight: .semibold, monospacedDigits: true)
                            .foregroundStyle(appearance.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(appearance.selected))
                    }
                }
                Text(item.promptText)
                    .lumaFont(size: 12.5, design: .serif)
                    .foregroundStyle(appearance.ink.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer()
            Text(subtitleText)
                .lumaFont(size: 11.5)
                .foregroundStyle(appearance.ink.opacity(0.68))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(appearance.paper.opacity(0.55)))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .padding(.trailing, 34)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? appearance.selected : appearance.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? appearance.accent : appearance.line, lineWidth: isSelected ? 1.5 : 1.0)
                )
        )
    }
}

struct LumaWritingTopicEditorSheet: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.dismiss) private var dismiss

    let initialItem: LumaTask2TopicItem?
    let isNew: Bool
    let availableCategories: [String]
    let defaultCategory: String
    let suggestedID: String
    let onSave: (LumaTask2TopicItem, String?) -> Void
    let onDelete: ((String) -> Void)?

    @State private var topicID: String = ""
    @State private var shortTitle: String = ""
    @State private var selectedCategory: String = "教育"
    @State private var newCategoryName: String = ""
    @State private var isCreatingNewCategory: Bool = false
    @State private var examDate: String = ""
    @State private var promptText: String = ""
    @State private var positiveText: String = ""
    @State private var negativeText: String = ""
    @State private var notesText: String = ""
    @State private var errorMessage: String = ""
    @State private var loaded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isNew ? "添加写作题目 (Task 2)" : "编辑写作题目 · \(initialItem?.id ?? "")")
                    .lumaFont(size: 22, weight: .bold, design: .serif)
                    .foregroundStyle(appearance.ink)
                Text("可选择八大主题分类或自定义新分类；保存后立即可在题库列表中双击练习、再次编辑或删除。")
                    .lumaFont(size: 12)
                    .foregroundStyle(appearance.ink.opacity(0.65))
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("题号 / 编号").font(.caption.bold())
                            TextField("如 教20 或 自定义-01", text: $topicID).textFieldStyle(.roundedBorder)
                        }.frame(width: 160)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("中文题目名称").font(.caption.bold())
                            TextField("输入简短中文标题", text: $shortTitle).textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("考试日期（可选）").font(.caption.bold())
                            TextField("如 20260510", text: $examDate).textFieldStyle(.roundedBorder)
                        }.frame(width: 130)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("所属写作主题分类").font(.caption.bold())
                        HStack(spacing: 10) {
                            if !isCreatingNewCategory {
                                Picker("主题分类", selection: $selectedCategory) {
                                    ForEach(availableCategories, id: \.self) { cat in
                                        Text(cat).tag(cat)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 200)
                            } else {
                                TextField("输入新主题分类名称", text: $newCategoryName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 280)
                            }
                            Button(isCreatingNewCategory ? "选择已有分类" : "+ 新建分类") {
                                isCreatingNewCategory.toggle()
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("英文题目内容 (IELTS Writing Task 2 Prompt)").font(.caption.bold())
                        TextEditor(text: $promptText)
                            .lumaFont(size: 13.5)
                            .frame(minHeight: 96)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                    }

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("正面 / 支持论点固定搭配（每行一条）").font(.caption.bold())
                            TextEditor(text: $positiveText)
                                .lumaFont(size: 12.5)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("负面 / 反对论点固定搭配（每行一条）").font(.caption.bold())
                            TextEditor(text: $negativeText)
                                .lumaFont(size: 12.5)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("补充备注（可选）").font(.caption.bold())
                        TextField("可填写同义替换词、例子或审题要点", text: $notesText)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack(spacing: 12) {
                if !isNew, let existingID = initialItem?.id, let onDelete {
                    Button(role: .destructive) {
                        onDelete(existingID)
                        dismiss()
                    } label: {
                        Label("删除此题", systemImage: "trash")
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundStyle(appearance.accent)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 16, height: 34))
                Button("保存题目") { saveTopic() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 20, height: 34))
            }
        }
        .padding(24)
        .frame(minWidth: 680, minHeight: 540)
        .background(appearance.background)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let item = initialItem {
                topicID = item.id
                shortTitle = item.shortTitle
                selectedCategory = availableCategories.contains(item.category) ? item.category : (availableCategories.first ?? "教育")
                examDate = item.examDate ?? ""
                promptText = item.promptText
                positiveText = item.positivePoints.joined(separator: "\n")
                negativeText = item.negativePoints.joined(separator: "\n")
                notesText = item.notes ?? ""
            } else {
                topicID = suggestedID
                selectedCategory = availableCategories.contains(defaultCategory) ? defaultCategory : (availableCategories.first ?? "教育")
            }
        }
    }

    private func saveTopic() {
        let trimmedTitle = shortTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedID = topicID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { errorMessage = "请填写中文题目名称"; return }
        guard !trimmedPrompt.isEmpty else { errorMessage = "请填写英文题目内容"; return }
        let finalCategory: String
        var newlyCreatedCategory: String? = nil
        if isCreatingNewCategory {
            let customCat = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !customCat.isEmpty else { errorMessage = "请输入新分类名称"; return }
            finalCategory = customCat
            newlyCreatedCategory = customCat
        } else {
            finalCategory = selectedCategory
        }
        let posList = positiveText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let negList = negativeText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let cleanDate = examDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = LumaTask2TopicItem(
            id: trimmedID.isEmpty ? suggestedID : trimmedID,
            shortTitle: trimmedTitle,
            category: finalCategory,
            subCategory: initialItem?.subCategory ?? finalCategory,
            promptText: trimmedPrompt,
            positivePoints: posList,
            negativePoints: negList,
            examDate: cleanDate.isEmpty ? nil : cleanDate,
            notes: cleanNotes.isEmpty ? nil : cleanNotes,
            isUserCreated: initialItem?.isUserCreated ?? true
        )
        onSave(saved, newlyCreatedCategory)
        dismiss()
    }
}

struct LumaTask1QuestionEditorSheet: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.dismiss) private var dismiss

    let initialItem: Task1QuestionItem?
    let isNew: Bool
    let suggestedID: String
    let onSave: (Task1QuestionItem) -> Void
    let onDelete: ((String) -> Void)?

    @State private var questionID: String = ""
    @State private var shortTitle: String = ""
    @State private var category: Task1ChartCategory = .lineGraph
    @State private var promptText: String = ""
    @State private var notesText: String = ""
    @State private var errorMessage: String = ""
    @State private var loaded: Bool = false

    private var selectableCategories: [Task1ChartCategory] {
        Task1ChartCategory.homeFilterBarCategories.filter { $0 != .all }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "添加小作文题目 (Task 1)" : "编辑小作文题目 · \(initialItem?.id ?? "")")
                .lumaFont(size: 22, weight: .bold, design: .serif)
                .foregroundStyle(appearance.ink)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("题号 / 编号").font(.caption.bold())
                    TextField("如 ORIG-013", text: $questionID).textFieldStyle(.roundedBorder)
                }.frame(width: 150)

                VStack(alignment: .leading, spacing: 6) {
                    Text("题目名称").font(.caption.bold())
                    TextField("输入图表作文标题", text: $shortTitle).textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("图表类型分类").font(.caption.bold())
                    Picker("图表类型", selection: $category) {
                        ForEach(selectableCategories, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("英文题目描述 (Task 1 Prompt)").font(.caption.bold())
                TextEditor(text: $promptText)
                    .lumaFont(size: 13.5)
                    .frame(minHeight: 110)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("审题要点 / 备注（可选）").font(.caption.bold())
                TextField("可填写趋势概括或关键对比特征", text: $notesText).textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                if !isNew, let existingID = initialItem?.id, let onDelete {
                    Button(role: .destructive) {
                        onDelete(existingID)
                        dismiss()
                    } label: {
                        Label("删除此题", systemImage: "trash")
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundStyle(appearance.accent)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 16, height: 34))
                Button("保存题目") {
                    let tTitle = shortTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let tPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let tID = questionID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !tTitle.isEmpty else { errorMessage = "请填写题目名称"; return }
                    guard !tPrompt.isEmpty else { errorMessage = "请填写英文题目描述"; return }
                    let dataset = (initialItem?.category == category && initialItem?.chartDataset != nil)
                        ? initialItem!.chartDataset!
                        : LumaTask1DefaultDataset.make(for: category)
                    let saved = Task1QuestionItem(
                        id: tID.isEmpty ? suggestedID : tID,
                        shortTitle: tTitle,
                        category: category,
                        difficultyBand: initialItem?.difficultyBand ?? "Band 6.5-7.5",
                        promptText: tPrompt,
                        minimumWords: 150,
                        recommendedMinutes: 20,
                        sourceName: initialItem?.sourceName ?? "Luma 自定义题库",
                        sourceURL: initialItem?.sourceURL ?? "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
                        licenseStatus: .originalSelfAuthored,
                        chartDataset: dataset,
                        companionTask2ID: initialItem?.companionTask2ID ?? "T2-CUSTOM",
                        companionTask2Prompt: initialItem?.companionTask2Prompt ?? "Write about the following topic.",
                        notes: notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notesText
                    )
                    onSave(saved)
                    dismiss()
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 20, height: 34))
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420)
        .background(appearance.background)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let item = initialItem {
                questionID = item.id
                shortTitle = item.shortTitle
                category = item.category == .all ? .lineGraph : item.category
                promptText = item.promptText
                notesText = item.notes ?? ""
            } else {
                questionID = suggestedID
            }
        }
    }
}

struct LumaWritingBankManagerSheet: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.dismiss) private var dismiss

    let allTask2Topics: [LumaTask2TopicItem]
    let allTask1Questions: [Task1QuestionItem]
    let availableCategories: [String]
    let deletedTask2Count: Int
    let deletedTask1Count: Int
    let onAddTask2: () -> Void
    let onEditTask2: (LumaTask2TopicItem) -> Void
    let onDeleteTask2: (String) -> Void
    let onAddTask1: () -> Void
    let onEditTask1: (Task1QuestionItem) -> Void
    let onDeleteTask1: (String) -> Void
    let onAddCategory: (String) -> Void
    let onDeleteCategory: (String) -> Void
    let onRestoreDefaults: () -> Void

    @State private var activeTab: String = "task2"
    @State private var filterText: String = ""
    @State private var selectedCategoryFilter: String = "全部"
    @State private var newCategoryInput: String = ""

    private var filteredTask2: [LumaTask2TopicItem] {
        allTask2Topics.filter { item in
            let matchesCat = (selectedCategoryFilter == "全部") || (item.category == selectedCategoryFilter) || (item.subCategory == selectedCategoryFilter)
            let q = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = q.isEmpty
                || item.id.localizedCaseInsensitiveContains(q)
                || item.shortTitle.localizedCaseInsensitiveContains(q)
                || item.promptText.localizedCaseInsensitiveContains(q)
            return matchesCat && matchesQuery
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("写作题库与分类管理中心")
                        .lumaFont(size: 22, weight: .bold, design: .serif)
                        .foregroundStyle(appearance.ink)
                    Text("已内置导入 200 道雅思大作文机经与 800 组正反论点专属搭配；支持自由新增、编辑、分类与删除。")
                        .font(.caption)
                        .foregroundStyle(appearance.ink.opacity(0.68))
                }
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 18, height: 32))
            }

            HStack(spacing: 10) {
                Button("Task 2 大作文 (\(allTask2Topics.count))") { activeTab = "task2" }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: activeTab == "task2", horizontalPadding: 14, height: 32))
                Button("Task 1 小作文 (\(allTask1Questions.count))") { activeTab = "task1" }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: activeTab == "task1", horizontalPadding: 14, height: 32))
                Button("主题分类管理 (\(availableCategories.count))") { activeTab = "categories" }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: activeTab == "categories", horizontalPadding: 14, height: 32))
                Spacer()
                if deletedTask2Count > 0 || deletedTask1Count > 0 {
                    Button("恢复已删除默认题 (\(deletedTask2Count + deletedTask1Count))") {
                        onRestoreDefaults()
                    }
                    .font(.caption)
                }
            }

            if activeTab == "task2" {
                HStack(spacing: 10) {
                    Picker("分类", selection: $selectedCategoryFilter) {
                        Text("全部主题").tag("全部")
                        ForEach(availableCategories, id: \.self) { cat in Text(cat).tag(cat) }
                    }.frame(width: 140)
                    TextField("搜索题号、中文标题或英文题目", text: $filterText).textFieldStyle(.roundedBorder)
                    Button("+ 添加大作文题目") { onAddTask2() }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredTask2) { item in
                            HStack(spacing: 12) {
                                Text(item.id).font(.caption.bold().monospacedDigit()).foregroundStyle(appearance.accent).frame(width: 58, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.shortTitle).lumaFont(size: 13.5, weight: .medium)
                                    Text(item.promptText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Text(item.category).font(.caption2).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(appearance.selected))
                                Button("编辑") { onEditTask2(item) }.font(.caption)
                                Button("删除", role: .destructive) { onDeleteTask2(item.id) }.font(.caption)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                        }
                    }
                }
            } else if activeTab == "task1" {
                HStack {
                    TextField("搜索小作文题目", text: $filterText).textFieldStyle(.roundedBorder)
                    Button("+ 添加小作文题目") { onAddTask1() }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(allTask1Questions) { q in
                            HStack(spacing: 12) {
                                Text(q.id).font(.caption.bold().monospacedDigit()).foregroundStyle(appearance.accent).frame(width: 76, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(q.shortTitle).lumaFont(size: 13.5, weight: .medium)
                                    Text(q.promptText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Text(q.category.rawValue).font(.caption2).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(appearance.selected))
                                Button("编辑") { onEditTask1(q) }.font(.caption)
                                Button("删除", role: .destructive) { onDeleteTask1(q.id) }.font(.caption)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    TextField("输入新主题分类名称", text: $newCategoryInput).textFieldStyle(.roundedBorder).frame(maxWidth: 280)
                    Button("+ 添加分类") {
                        let c = newCategoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !c.isEmpty else { return }
                        onAddCategory(c)
                        newCategoryInput = ""
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                    Spacer()
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(availableCategories, id: \.self) { cat in
                            let count = allTask2Topics.filter { $0.category == cat || $0.subCategory == cat }.count
                            let isBuiltIn = LumaTask2TopicItem.eightMajorCategories.contains(cat)
                            HStack {
                                Image(systemName: LumaTask2TopicItem.symbolName(for: cat)).foregroundStyle(appearance.accent)
                                Text(cat).font(.headline)
                                Text(isBuiltIn ? "雅思八大核心主题" : "自定义主题").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(count) 题").font(.caption.monospacedDigit())
                                if !isBuiltIn {
                                    Button("删除分类", role: .destructive) { onDeleteCategory(cat) }.font(.caption)
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 780, minHeight: 560)
        .background(appearance.background)
    }
}

@MainActor
private struct DictationShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    nonisolated func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = animatableData - floor(animatableData)
        let envelope = sin(progress * .pi)
        let translation = -16.0 * sin(animatableData * .pi * 6.0) * max(0.35, envelope)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}


/// 正在编辑的词库（用于 sheet(item:)）。
struct LumaDeckEditTarget: Identifiable, Equatable {
    let id: String
    let title: String
}

/// 词库编辑器中的一行。
struct LumaVocabularyEditRow: Identifiable, Equatable {
    let id: String
    var word: String
    var meaning: String
}

/// 随时编辑已导入词库：修改单词 / 释义、删除或新增词条。
struct LumaVocabularyDeckEditorSheet: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.dismiss) private var dismiss
    let deckID: String
    let deckTitle: String
    let originalWords: [VocabularyWord]
    let onSave: ([VocabularyWord]) -> String?

    @State private var rows: [LumaVocabularyEditRow] = []
    @State private var search: String = ""
    @State private var errorMessage: String = ""
    @State private var loaded: Bool = false

    private var visibleRowIDs: [String] {
        let query: String = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return rows.map(\.id) }
        return rows.filter { $0.word.localizedStandardContains(query) || $0.meaning.localizedStandardContains(query) }.map(\.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("编辑词库")
                        .lumaFont(size: 24, weight: .medium)
                        .foregroundStyle(appearance.ink)
                    Text(deckTitle + " · \(rows.count) 个词")
                        .lumaFont(size: 12)
                        .foregroundStyle(appearance.ink.opacity(0.55))
                }
                Spacer()
                StudySearchField("搜索词条", text: $search, width: 200)
                Button {
                    addRow()
                } label: {
                    Label("新增", systemImage: "plus")
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
            }

            List {
                ForEach(visibleRowIDs, id: \.self) { rowID in
                    editRow(rowID)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(appearance.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(appearance.line, lineWidth: 1))
            )

            HStack(spacing: 12) {
                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .lumaFont(size: 12.5)
                        .foregroundStyle(appearance.accent)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 16, height: 36))
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 22, height: 36))
            }
        }
        .padding(24)
        .frame(minWidth: 680, minHeight: 520)
        .background(appearance.background)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            rows = originalWords.map { LumaVocabularyEditRow(id: $0.id, word: $0.word, meaning: $0.definitionZH) }
        }
    }

    private func wordBinding(_ rowID: String) -> Binding<String> {
        Binding(
            get: { rows.first(where: { $0.id == rowID })?.word ?? "" },
            set: { value in
                if let i = rows.firstIndex(where: { $0.id == rowID }) { rows[i].word = value }
            }
        )
    }

    private func meaningBinding(_ rowID: String) -> Binding<String> {
        Binding(
            get: { rows.first(where: { $0.id == rowID })?.meaning ?? "" },
            set: { value in
                if let i = rows.firstIndex(where: { $0.id == rowID }) { rows[i].meaning = value }
            }
        )
    }

    private func editRow(_ rowID: String) -> some View {
        HStack(spacing: 10) {
            TextField("英文单词或短语", text: wordBinding(rowID))
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 200)
            TextField("中文释义", text: meaningBinding(rowID))
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 240)
            Button(role: .destructive) {
                rows.removeAll { $0.id == rowID }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("删除此条")
        }
        .padding(.vertical, 3)
    }

    private func addRow() {
        search = ""
        let newID: String = deckID + "_edit_" + UUID().uuidString
        rows.insert(LumaVocabularyEditRow(id: newID, word: "", meaning: ""), at: 0)
    }

    private func save() {
        var seen: Set<String> = []
        var result: [VocabularyWord] = []
        for row in rows {
            let word: String = row.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning: String = row.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            if word.isEmpty && meaning.isEmpty { continue }
            guard VocabularyImport.isValidEnglishTerm(word) else {
                errorMessage = "「\(word.isEmpty ? meaning : word)」不是有效的英文词条"
                return
            }
            guard !meaning.isEmpty else {
                errorMessage = "「\(word)」缺少中文释义"
                return
            }
            guard seen.insert(word.lowercased()).inserted else {
                errorMessage = "「\(word)」重复了"
                return
            }
            if let original = originalWords.first(where: { $0.id == row.id }) {
                result.append(VocabularyWord(id: original.id, word: word, phoneticUK: original.phoneticUK, phoneticUS: original.phoneticUS, partOfSpeech: original.partOfSpeech, definitionZH: meaning, exampleSentence: original.exampleSentence, deckID: deckID, deckTitle: deckTitle))
            } else {
                result.append(VocabularyWord(id: row.id, word: word, definitionZH: meaning, deckID: deckID, deckTitle: deckTitle))
            }
        }
        guard !result.isEmpty else {
            errorMessage = "词库至少需要保留一个词；如需移除整个词库请使用「删除词库」"
            return
        }
        if let issue = onSave(result) {
            errorMessage = issue
        } else {
            dismiss()
        }
    }
}


// MARK: - Main Study Center Host View

@MainActor
public struct LumaStudyCenterHostView: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var mode: String

    @MainActor
    final class HostStateModel: ObservableObject {
        @Published var storageError: String?
        let speech = MacOSSpeechSynthesisManager()
        var clockOwner: UUID?
        var examClockTask: Task<Void, Never>?
        var isExamClockActive: Bool = false
        var writingEntry: WritingExamDraftState?
        var editingDraftID: UUID?
        var suppressDraftAutosave = false
        var allowWritingNavigation = false
        var audioPlaybackFinishedAt: Date? = nil
        @Published var lastSubmittedReactionSeconds: Double? = nil

        func markAudioPlaybackStarted(for text: String, rate: Float, repeats: Int, interval: Double) {
            // native_playback_timing_v6: synthesis waiting is never reaction time.
            audioPlaybackFinishedAt = nil
        }

        func beginWritingEdit(isNew: Bool = false) {
            guard editingDraftID != currentDraft.id else { return }
            editingDraftID = currentDraft.id
            writingEntry = isNew ? nil : storeSnapshot.activeWritingDrafts.values.first { $0.id == currentDraft.id }
            suppressDraftAutosave = false
        }
        @discardableResult func finishWritingEdit(discard: Bool) -> Bool {
            let original = storeSnapshot
            let edited = currentDraft
            let clockWasActive = isExamClockActive
            suppressDraftAutosave = discard
            if discard {
                storeSnapshot.activeWritingDrafts = storeSnapshot.activeWritingDrafts.filter { $0.value.id != currentDraft.id }
                if let writingEntry {
                    currentDraft = writingEntry
                    storeSnapshot.activeWritingDrafts[writingEntry.id.uuidString] = writingEntry
                } else {
                    currentDraft.part1EssayText = ""; currentDraft.part2EssayText = ""
                    currentDraft.elapsedSeconds = 0; currentDraft.remainingSeconds = 3600
                    currentDraft.promptHighlights = nil
                    storeSnapshot.workspace?.writingDraftID = nil
                }
                isExamClockActive = false
            } else {
                storeSnapshot.activeWritingDrafts[currentDraft.id.uuidString] = currentDraft
            }
            guard save() else {
                storeSnapshot = original; currentDraft = edited; suppressDraftAutosave = false; isExamClockActive = clockWasActive
                return false
            }
            editingDraftID = nil; writingEntry = nil
            return true
        }
        @discardableResult func deleteWritingDraft(_ id: UUID) -> Bool {
            let original = storeSnapshot; let active = currentDraft
            let wasSuppressed = suppressDraftAutosave
            if currentDraft.id == id {
                suppressDraftAutosave = true; isExamClockActive = false
                currentDraft.part1EssayText = ""; currentDraft.part2EssayText = ""
                currentDraft.elapsedSeconds = 0; currentDraft.remainingSeconds = 3600
                currentDraft.promptHighlights = nil; editingDraftID = nil; writingEntry = nil
            }
            storeSnapshot.activeWritingDrafts = storeSnapshot.activeWritingDrafts.filter { $0.value.id != id }
            if storeSnapshot.workspace?.writingDraftID == id { storeSnapshot.workspace?.writingDraftID = nil }
            guard save() else { storeSnapshot = original; currentDraft = active; suppressDraftAutosave = wasSuppressed; return false }
            return true
        }
        @discardableResult func deleteWritingSubmission(_ id:UUID) -> Bool {
            guard let record = storeSnapshot.writingSubmissions.first(where: { $0.id == id }) else { return false }
            let original = storeSnapshot; let active = currentDraft; let wasSuppressed = suppressDraftAutosave
            if currentDraft.id == record.draftSessionID {
                suppressDraftAutosave = true; isExamClockActive = false
                currentDraft.part1EssayText = ""; currentDraft.part2EssayText = ""
                currentDraft.elapsedSeconds = 0; currentDraft.remainingSeconds = 3600
                currentDraft.promptHighlights = nil; storeSnapshot.workspace?.writingDraftID = nil
            }
            storeSnapshot.activeWritingDrafts = storeSnapshot.activeWritingDrafts.filter { $0.value.id != record.draftSessionID }
            storeSnapshot.writingSubmissions.removeAll { $0.id == id }
            storeSnapshot.writingRevisions?.removeAll { $0.submissionID == id }
            guard save() else { storeSnapshot = original; currentDraft = active; suppressDraftAutosave = wasSuppressed; return false }
            return true
        }
        func submitDictationInput(_ input: String? = nil, newWordStrategy: NewWordDictationStrategy? = nil) -> DictationSubmitOutcome? {
            let now = Date()
            let latency: Double
            if let finishedAt = audioPlaybackFinishedAt {
                latency = max(0.2, now.timeIntervalSince(finishedAt))
            } else {
                latency = 2.0
            }
            lastSubmittedReactionSeconds = latency
            guard let result = dictationMachine.submitAnswer(input ?? dictationInput, durationSeconds: latency, newWordStrategy: newWordStrategy) else { return nil }
            showMeaning = dictationMachine.attemptLogs.last?.isCorrect == false
            return result
        }
        var persistence: StudyPersistenceManager?
        private var deferredSaveTask: Task<Void, Never>?
        init(storageDirectory: URL? = nil) {
            do {
                let directory: URL
                if let storageDirectory { directory = storageDirectory }
                else { directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("LumaReader/StudyCenter", isDirectory: true) }
                let manager = try StudyPersistenceManager(storageDirectory: directory)
                var saved = try manager.loadAndMigrateIfNeeded()
                let existingDeckIDs = Set((saved.importedWords ?? []).map(\.deckID))
                let missingScenarioDecks = !BundledCoraVocabulary.defaultDeckOrder.allSatisfy { existingDeckIDs.contains($0) }
                // V1.1.0：听力词库已由用户指定的两份资料完整替换，不再重新播种旧 Cora 场景词本。
                let replacedListeningPack = (saved.installedVocabularyPackIDs ?? []).contains("replaced.listening.20261110")
                if storageDirectory == nil && !replacedListeningPack && (!(saved.installedVocabularyPackIDs ?? []).contains(BundledCoraVocabulary.packID) || missingScenarioDecks) {
                    if missingScenarioDecks {
                        saved.installedVocabularyPackIDs = (saved.installedVocabularyPackIDs ?? []).filter { $0 != BundledCoraVocabulary.packID }
                    }
                    do {
                        let seeded = try BundledCoraVocabulary.addingTo(saved)
                        try manager.save(seeded)
                        saved = seeded
                    } catch {
                        storageError = "Cora 词本添加失败，已有学习记录已保留：\(error.localizedDescription)"
                    }
                }
                persistence = manager; storeSnapshot = saved
                selectedAccent = TTSVoiceAccent(rawValue: saved.preferredAccent) ?? .british
                speechRateMultiplier = saved.preferredSpeechRate < 0.7 ? saved.preferredSpeechRate * 2 : saved.preferredSpeechRate
                if let workspaceDeck = saved.workspace?.selectedDeckID, !workspaceDeck.isEmpty {
                    selectedDeck = workspaceDeck
                }
                if let session = saved.dictationSession {
                    selectedDeck = saved.workspace?.selectedDeckID ?? session.currentWord?.deckID ?? session.attemptLogs.last?.deckID ?? selectedDeck
                    if session.dateString == LumaStudyCenterHostView.todayDateString() {
                        dictationMachine = session
                    } else {
                        dictationMachine = DictationSessionStateMachine(
                            mode: session.mode,
                            dateString: LumaStudyCenterHostView.todayDateString(),
                            initialWords: session.pendingQueue,
                            existingStubbornWordsForToday: saved.stubbornWords
                        )
                    }
                }
                activeDictationDeckKey = selectedDeck
                if let state = saved.workspace {
                    let currentKey = Self.sessionKey(mode: dictationMachine.mode, date: dictationMachine.dateString, deck: selectedDeck)
                    if let currentWordID = dictationMachine.currentWord?.id {
                        if state.inputWordID == currentWordID {
                            dictationInput = state.dictationInput
                            showMeaning = state.showMeaning
                            revealedWordID = state.revealedWordID
                        } else if state.deckInputWordIDs?[currentKey] == currentWordID {
                            dictationInput = state.deckInputs?[currentKey] ?? ""
                            showMeaning = state.deckShowMeaning?[currentKey] ?? false
                            revealedWordID = state.deckRevealedWordIDs?[currentKey]
                        }
                    }
                    if let id = state.writingDraftID,
                       var draft = saved.activeWritingDrafts.values.first(where: { $0.id == id }) {
                        if draft.part2EssayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && practiceSeconds != 3600 {
                            draft.isSingleTaskMode = true
                            draft.activePart = .part1
                            if draft.remainingSeconds > 1200 {
                                draft.remainingSeconds = max(60, 1200 - draft.elapsedSeconds)
                            }
                        }
                        currentDraft = draft
                        if let question = LumaStudyCenterHostView.builtInPracticeQuestions.first(where: { $0.id == draft.questionID }) {
                            selectedExamQuestion = question
                        }
                    }
                }
                if !manager.skippedLegacyEntries.isEmpty {
                    storageError = "已读取学习记录；有 \(manager.skippedLegacyEntries.count) 条旧记录与新版格式不兼容被跳过（原文件已完整备份在 backups 文件夹）。"
                } else if manager.recoveryPerformed { storageError = "检测到学习记录损坏，已恢复上次有效备份；损坏原文件保存在备份目录中。" }
            } catch DecodingError.keyNotFound(let key, _) {
                storageError = "旧学习记录缺少字段「\(key.stringValue)」，原文件已保留，请勿清空记录。"
            } catch { storageError = "学习记录读取失败，原文件已保留：\(error.localizedDescription)" }
        }

        func remember(_ mode: String) {
            var state = storeSnapshot.workspace ?? StudyWorkspaceState()
            if mode.hasPrefix("学习_听力") {
                state.listeningMode = mode
                if mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习" {
                    state.activePracticeListeningMode = mode
                }
            }
            if mode.contains("写作") || mode == "学习_草稿" || mode == "学习_模拟机考" {
                state.writingMode = mode
                if mode.contains("模拟机考") {
                    state.activePracticeWritingMode = mode
                }
            }
            storeSnapshot.workspace = state
            scheduleSave(after: 0.8)
        }

        static func sessionKey(mode: DictationSessionMode, date: String, deck: String) -> String {
            mode.rawValue + "|" + date + "|" + deck
        }

        func tickExamClock(seconds: Int = 1) {
            guard seconds > 0, isExamClockActive, !currentDraft.isPaused, currentDraft.remainingSeconds > 0 else { return }
            let isSubmitted = storeSnapshot.writingSubmissions.contains { $0.draftSessionID == currentDraft.id }
            guard !isSubmitted else {
                isExamClockActive = false
                return
            }
            let used = min(seconds, currentDraft.remainingSeconds)
            currentDraft.remainingSeconds -= used
            currentDraft.elapsedSeconds += used
            currentDraft.lastSavedAt = Date()
            storeDraft(currentDraft)
        }

        func startContinuousExamClockIfNeeded(onExpire: @escaping @MainActor (WritingExamDraftState) -> Void) {
            isExamClockActive = true
            guard examClockTask == nil else { return }
            examClockTask = Task { @MainActor [weak self] in
                var previous = ContinuousClock.now
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { break }
                    guard let self else { break }
                    let now = ContinuousClock.now
                    let elapsed = previous.duration(to: now)
                    let secs = Int(elapsed.components.seconds)
                    guard secs > 0 else { continue }
                    previous = previous.advanced(by: .seconds(secs))
                    if self.isExamClockActive && !self.currentDraft.isPaused && self.currentDraft.remainingSeconds > 0 {
                        self.tickExamClock(seconds: secs)
                        if self.currentDraft.remainingSeconds == 0 {
                            self.isExamClockActive = false
                            onExpire(self.currentDraft)
                        }
                    }
                }
            }
        }

        func storeDraft(_ draft: WritingExamDraftState) {
            guard !suppressDraftAutosave else { return }
            storeSnapshot.activeWritingDrafts = storeSnapshot.activeWritingDrafts.filter { $0.value.id != draft.id }
            storeSnapshot.activeWritingDrafts[draft.id.uuidString] = draft
            // The disk snapshot remains authoritative; coalesce only a very short burst of keystrokes/timer ticks.
            scheduleSave(after: 2.0)
        }

        /// Coalesces high-frequency typing/timer updates into one atomic disk write.
        /// Explicit actions, navigation and app termination still call save() immediately.
        func scheduleSave(after seconds: Double = 1.0) {
            guard deferredSaveTask == nil else { return }
            let delay = max(0.25, seconds)
            deferredSaveTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .milliseconds(Int(delay * 1_000))) }
                catch { return }
                guard let self else { return }
                self.deferredSaveTask = nil
                _ = self.save()
            }
        }

        func existingUnsubmittedDraft(for questionID: String, singleTask: Bool? = nil, activePart: ExamPart? = nil) -> WritingExamDraftState? {
            let submittedIDs = Set(storeSnapshot.writingSubmissions.map(\.draftSessionID))
            let matchesMode: (WritingExamDraftState) -> Bool = { draft in
                if let singleTask, draft.isSingleTaskMode != singleTask { return false }
                if let activePart, singleTask == true, draft.activePart != activePart { return false }
                return true
            }
            if currentDraft.questionID == questionID && !submittedIDs.contains(currentDraft.id) && matchesMode(currentDraft) &&
               (!currentDraft.part1EssayText.isEmpty || !currentDraft.part2EssayText.isEmpty || currentDraft.elapsedSeconds > 0 || storeSnapshot.activeWritingDrafts.values.contains(where: { $0.id == currentDraft.id })) {
                return currentDraft
            }
            return storeSnapshot.activeWritingDrafts.values
                .filter { $0.questionID == questionID && !submittedIDs.contains($0.id) && matchesMode($0) }
                .sorted { $0.lastSavedAt > $1.lastSavedAt }
                .first
        }

        @discardableResult func save() -> Bool {
            deferredSaveTask?.cancel()
            deferredSaveTask = nil
            guard let persistence else { return false }
            var workspace = storeSnapshot.workspace ?? StudyWorkspaceState()
            workspace.selectedDeckID = selectedDeck
            workspace.dictationInput = dictationInput
            workspace.inputWordID = dictationMachine.currentWord?.id
            workspace.showMeaning = showMeaning
            workspace.revealedWordID = revealedWordID

            let deck = activeDictationDeckKey.isEmpty ? (dictationMachine.currentWord?.deckID ?? selectedDeck) : activeDictationDeckKey
            let key = Self.sessionKey(mode: dictationMachine.mode, date: dictationMachine.dateString, deck: deck)
            var deckInputs = workspace.deckInputs ?? [:]
            var deckInputWordIDs = workspace.deckInputWordIDs ?? [:]
            var deckShowMeaning = workspace.deckShowMeaning ?? [:]
            var deckRevealedWordIDs = workspace.deckRevealedWordIDs ?? [:]
            deckInputs[key] = dictationInput
            if let wordID = dictationMachine.currentWord?.id {
                deckInputWordIDs[key] = wordID
            } else {
                deckInputWordIDs.removeValue(forKey: key)
            }
            deckShowMeaning[key] = showMeaning
            if let revealedWordID {
                deckRevealedWordIDs[key] = revealedWordID
            } else {
                deckRevealedWordIDs.removeValue(forKey: key)
            }
            workspace.deckInputs = deckInputs
            workspace.deckInputWordIDs = deckInputWordIDs
            workspace.deckShowMeaning = deckShowMeaning
            workspace.deckRevealedWordIDs = deckRevealedWordIDs

            let isCurrentSubmitted = storeSnapshot.writingSubmissions.contains { $0.draftSessionID == currentDraft.id }
            let hasDraftProgress = !currentDraft.part1EssayText.isEmpty || !currentDraft.part2EssayText.isEmpty || currentDraft.elapsedSeconds > 0
            if !suppressDraftAutosave && !isCurrentSubmitted && (hasDraftProgress || storeSnapshot.activeWritingDrafts.values.contains(where: { $0.id == currentDraft.id })) {
                storeSnapshot.activeWritingDrafts = storeSnapshot.activeWritingDrafts.filter { $0.value.id != currentDraft.id }
                storeSnapshot.activeWritingDrafts[currentDraft.id.uuidString] = currentDraft
                workspace.writingDraftID = currentDraft.id
            }
            storeSnapshot.workspace = workspace
            storeSnapshot.dictationSession = dictationMachine
            if storeSnapshot.dictationSessions == nil { storeSnapshot.dictationSessions = [:] }
            storeSnapshot.dictationSessions?[key] = dictationMachine
            storeSnapshot.preferredAccent = selectedAccent.rawValue
            storeSnapshot.preferredSpeechRate = speechRateMultiplier
            if let udReading = UserDefaults.standard.dictionary(forKey: "luma.study.dailyReadingSeconds") as? [String: Int], !udReading.isEmpty {
                var mergedReading = storeSnapshot.dailyReadingSeconds ?? [:]
                for (k, v) in udReading {
                    mergedReading[k] = max(mergedReading[k, default: 0], v)
                }
                storeSnapshot.dailyReadingSeconds = mergedReading
            }
            do {
                try persistence.save(storeSnapshot)
                // 不再每次保存都自动合并云盘：自动合并会把已删除的草稿从云盘副本里“复活”。
                // 云盘同步改为手动（「⋯」菜单 → 同步学习数据到云盘）。
                return true
            } catch {
                storageError = "学习记录保存失败：\(error.localizedDescription)"
                return false
            }
        }

        func syncWithConnectedCloudDrives(additionalRoots: [URL] = []) -> Int {
            let result = StudyCloudSyncManager.sync(
                localSnapshot: storeSnapshot,
                localPersistence: persistence,
                cloudRoots: additionalRoots
            )
            storeSnapshot = result.merged
            return result.syncedDirectories.count
        }

        // MARK: - Task 1 & Task 2 Custom Topic / Category CRUD

        var allTask1Questions: [Task1QuestionItem] {
            let deleted = Set(storeSnapshot.deletedTask1QuestionIDs ?? [])
            let custom = storeSnapshot.customTask1Questions ?? []
            let customByID = Dictionary(uniqueKeysWithValues: custom.map { ($0.id, $0) })
            var result: [Task1QuestionItem] = []
            var seen = Set<String>()
            for item in LumaStudyCenterHostView.builtInPracticeQuestions where !deleted.contains(item.id) {
                let effective = customByID[item.id] ?? item
                result.append(effective)
                seen.insert(effective.id)
            }
            for item in custom where !deleted.contains(item.id) && !seen.contains(item.id) {
                result.append(item)
                seen.insert(item.id)
            }
            return result.isEmpty ? LumaStudyCenterHostView.builtInPracticeQuestions : result
        }

        var allTask2Topics: [LumaTask2TopicItem] {
            let deleted = Set(storeSnapshot.deletedTask2TopicIDs ?? [])
            let custom = storeSnapshot.customTask2Topics ?? []
            let customByID = Dictionary(uniqueKeysWithValues: custom.map { ($0.id, $0) })
            var result: [LumaTask2TopicItem] = []
            var seen = Set<String>()
            for item in custom where !deleted.contains(item.id) {
                if LumaStudyCenterHostView.builtInTask2Topics.first(where: { $0.id == item.id }) == nil {
                    result.append(item)
                    seen.insert(item.id)
                }
            }
            for item in LumaStudyCenterHostView.builtInTask2Topics where !deleted.contains(item.id) {
                let effective = customByID[item.id] ?? item
                if !seen.contains(effective.id) {
                    result.append(effective)
                    seen.insert(effective.id)
                }
            }
            return result
        }

        var availableTask2Categories: [String] {
            var cats = LumaTask2TopicItem.eightMajorCategories
            for c in (storeSnapshot.customTask2Categories ?? []) where !cats.contains(c) && !c.isEmpty {
                cats.append(c)
            }
            for t in (storeSnapshot.customTask2Topics ?? []) where !cats.contains(t.category) && !t.category.isEmpty {
                cats.append(t.category)
            }
            return cats
        }

        func addOrUpdateTask2Topic(_ item: LumaTask2TopicItem, newCategory: String? = nil) {
            if let newCategory, !newCategory.isEmpty {
                addTask2Category(newCategory)
            }
            var custom = storeSnapshot.customTask2Topics ?? []
            if let idx = custom.firstIndex(where: { $0.id == item.id }) {
                custom[idx] = item
            } else {
                custom.insert(item, at: 0)
            }
            storeSnapshot.customTask2Topics = custom
            storeSnapshot.deletedTask2TopicIDs?.removeAll { $0 == item.id }
            save()
        }

        func deleteTask2Topic(id: String) {
            storeSnapshot.customTask2Topics?.removeAll { $0.id == id }
            var deleted = storeSnapshot.deletedTask2TopicIDs ?? []
            if !deleted.contains(id) { deleted.append(id) }
            storeSnapshot.deletedTask2TopicIDs = deleted
            save()
        }

        func addTask2Category(_ name: String) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            var cats = storeSnapshot.customTask2Categories ?? []
            if !cats.contains(trimmed) && !LumaTask2TopicItem.eightMajorCategories.contains(trimmed) {
                cats.append(trimmed)
                storeSnapshot.customTask2Categories = cats
                save()
            }
        }

        func deleteTask2Category(_ name: String) {
            storeSnapshot.customTask2Categories?.removeAll { $0 == name }
            save()
        }

        func addOrUpdateTask1Question(_ item: Task1QuestionItem) {
            var custom = storeSnapshot.customTask1Questions ?? []
            if let idx = custom.firstIndex(where: { $0.id == item.id }) {
                custom[idx] = item
            } else {
                custom.insert(item, at: 0)
            }
            storeSnapshot.customTask1Questions = custom
            storeSnapshot.deletedTask1QuestionIDs?.removeAll { $0 == item.id }
            save()
        }

        func deleteTask1Question(id: String) {
            storeSnapshot.customTask1Questions?.removeAll { $0.id == id }
            var deleted = storeSnapshot.deletedTask1QuestionIDs ?? []
            if !deleted.contains(id) { deleted.append(id) }
            storeSnapshot.deletedTask1QuestionIDs = deleted
            save()
        }

        func restoreDeletedBuiltInQuestions() {
            storeSnapshot.deletedTask2TopicIDs = []
            storeSnapshot.deletedTask1QuestionIDs = []
            save()
        }

        @Published var storeSnapshot: StudyStoreSnapshot = StudyStoreSnapshot()
        @Published var selectedExamQuestion: Task1QuestionItem = LumaStudyCenterHostView.builtInPracticeQuestions[2]
        @Published var currentDraft: WritingExamDraftState = WritingExamDraftState(
            id: UUID(),
            questionID: "ORIG-003",
            examTitle: "原创写作练习 · 岛屿改造",
            activePart: .part1,
            part1EssayText: "",
            part2EssayText: "",
            remainingSeconds: 3600,
            elapsedSeconds: 0,
            isPaused: false,
            isSingleTaskMode: false,
            lastSavedAt: Date(),
            containsLegacyNonEnglishNotice: false
        )
        @Published var dictationMachine = DictationSessionStateMachine(
            mode: .newTask,
            dateString: LumaStudyCenterHostView.todayDateString(),
            initialWords: LumaStudyCenterHostView.builtInVocabularyWords
        )
        @Published var dictationInput: String = ""
        @Published var dictationFeedback: String = "支持听写反应时长追踪：语音播完后犹豫超过 5.0 秒自动标记为「慢反应词」加入提速巩固；第 6 次答错进入顽固单词。"
        @Published var selectedAccent: TTSVoiceAccent = .british
        @Published var speechRateMultiplier: Float = 1.0
        @Published var showMeaning = false
        @Published var revealedWordID: String? = nil
        @Published var mixedWrongDecks: Set<String> = []
        @Published var mixedWrongShuffle = true
        @Published var mixedWrongSheetShown = false
        // Listening continuity v1
        @Published var activeDictationDeckKey = ""
        @Published var selectedDeck = "vocab_daily"
        @Published var practiceSeconds = 1200
        @Published var speechSettingsShown = false
        @Published var evaluatingSubmission: UUID?
        @Published var statsScope: StudyStatisticsScope = .all
        @Published var statsTimeWindow: StudyStatsTimeWindow = .allTime

        // V.1.0.1: Reuse the folder index across view refreshes and mode switches.
        // Compare complete inputs so same-count edits and folder moves invalidate it.
        private struct FinderIndexInputs: Equatable {
            let words: [String: [VocabularyWord]]
            let decks: [String]
            let categories: [String]
            let categoryMap: String
            let folders: String
            let redirects: String
            let wordFolders: String
        }
        private var finderIndexInputs: FinderIndexInputs?
        private var finderIndexValue: (allFolderPaths: [[String]], wordsByFolderPath: [String: [VocabularyWord]])?

        func cachedFinderHierarchy(words: [String: [VocabularyWord]], decks: [String], categories: [String],
                                   categoryMap: String, folders: String, redirects: String, wordFolders: String,
                                   build: () -> (allFolderPaths: [[String]], wordsByFolderPath: [String: [VocabularyWord]]))
            -> (allFolderPaths: [[String]], wordsByFolderPath: [String: [VocabularyWord]]) {
            let input = FinderIndexInputs(words:words, decks:decks, categories:categories, categoryMap:categoryMap,
                                          folders:folders, redirects:redirects, wordFolders:wordFolders)
            if finderIndexInputs == input, let cached = finderIndexValue { return cached }
            let value = build()
            finderIndexInputs = input
            finderIndexValue = value
            return value
        }

        private var cachedVocabCount: Int = -1
        private var cachedFirstWordID: String = ""
        private var cachedLastWordID: String = ""
        private var cachedSelectedDeckForDict: String = ""
        var vocabRevision: Int = 0
        private var cachedLastBuildRevision: Int = -1
        private var cachedAllWords: [VocabularyWord] = []
        private var cachedWordsByDeck: [String: [VocabularyWord]] = [:]
        private var cachedDeckTitles: [String: String] = [:]
        private var cachedVisibleBaseDecks: [String] = []

        func invalidateVocabCache() {
            vocabRevision &+= 1
        }
        func releaseDerivedVocabularyCaches() {
            cachedAllWords = []; cachedWordsByDeck = [:]; cachedDeckTitles = [:]; cachedVisibleBaseDecks = []
            cachedLastBuildRevision = -1
        }

        private func ensureVocabIndex() {
            let imported = storeSnapshot.importedWords ?? []
            let count = imported.count
            let firstID = imported.first?.id ?? ""
            let lastID = imported.last?.id ?? ""
            let dictDeck = BuiltInIELTSDictionaryEngine.allDictionaries.contains(where: { $0.id == selectedDeck }) ? selectedDeck : ""
            if cachedLastBuildRevision == vocabRevision &&
               cachedVocabCount == count &&
               cachedFirstWordID == firstID &&
               cachedLastWordID == lastID &&
               cachedSelectedDeckForDict == dictDeck {
                return
            }
            cachedLastBuildRevision = vocabRevision
            cachedVocabCount = count
            cachedFirstWordID = firstID
            cachedLastWordID = lastID
            cachedSelectedDeckForDict = dictDeck

            var combined = LumaStudyCenterHostView.builtInVocabularyWords
            combined.reserveCapacity(combined.count + count)
            combined.append(contentsOf: imported)
            if !dictDeck.isEmpty, let book = BuiltInIELTSDictionaryEngine.allDictionaries.first(where: { $0.id == dictDeck }) {
                if !combined.contains(where: { $0.deckID == book.id }) {
                    combined.append(contentsOf: book.words)
                }
            }
            cachedAllWords = combined

            var byDeck: [String: [VocabularyWord]] = [:]
            var titles: [String: String] = BundledCoraVocabulary.defaultTitleByDeckID
            for w in combined {
                byDeck[w.deckID, default: []].append(w)
                if !w.deckTitle.isEmpty {
                    titles[w.deckID] = w.deckTitle
                }
            }
            cachedWordsByDeck = byDeck
            cachedDeckTitles = titles

            let hidden: Set<String> = Set(["vocab_daily", "fixture", "custom", "d1", "d"] + BuiltInIELTSDictionaryEngine.allDictionaries.map(\.id))
            cachedVisibleBaseDecks = byDeck.keys.filter { !hidden.contains($0) }.sorted()
        }

        var fastAllWords: [VocabularyWord] {
            ensureVocabIndex()
            return cachedAllWords
        }
        var fastWordsByDeck: [String: [VocabularyWord]] {
            ensureVocabIndex()
            return cachedWordsByDeck
        }
        var fastDeckTitles: [String: String] {
            ensureVocabIndex()
            return cachedDeckTitles
        }
        var fastVisibleBaseDecks: [String] {
            ensureVocabIndex()
            return cachedVisibleBaseDecks
        }
    }

    @State private var showWritingExit = false
    @State private var writingExitResolved = false
    @State private var dictationShake: CGFloat = 0
    @State private var dictationWrongFlash = false
    @State private var dictationErrorShake: CGFloat = 0
    @State private var dictationErrorFlash: Bool = false
    @State private var dictationErrorPulse = 0
    @State private var dictationErrorFeedbackTask: Task<Void,Never>?
    @State private var pendingDictationPlayback: Task<Void, Never>?
    @StateObject private var kokoro = KokoroNeuralBridge.shared
    @State private var deckToRename: String? = nil
    @AppStorage("luma.study.pinnedDecks") private var pinnedDecksRaw: String = ""
    @AppStorage("luma.study.customDeckOrder") private var customDeckOrderRaw: String = ""
    @AppStorage("luma.study.listeningCategories") private var listeningCategoriesRaw: String = "Part 1|Part 2|Part 3|Part 4"
    @AppStorage("luma.study.deckCategoryMap") private var deckCategoryMapRaw: String = ""
    @State private var selectedListeningCategory: String = "全部"
    @State private var showListeningCategoryBar: Bool = false
    @AppStorage("luma.study.finderViewMode") private var finderViewMode: String = "icons"
    @AppStorage("luma.study.finderCustomFolders") private var finderCustomFoldersRaw: String = ""
    @AppStorage("luma.study.finderFolderRedirects") private var finderFolderRedirectsRaw: String = ""
    @AppStorage("luma.study.finderWordFolderMap") private var finderWordFolderMapRaw: String = ""
    @AppStorage("luma.study.finderFolderIcons") private var finderFolderIconMapRaw: String = ""
    @State private var finderIconDraft: String = ""
    @State private var finderIconEditingPath: [String]? = nil
    @State private var finderIconUserPicked: Bool = false
    @State private var finderCurrentPath: [String] = []
    @State private var finderPathHistory: [[String]] = [[]]
    @State private var finderHistoryIndex: Int = 0
    @State private var finderSearchQuery: String = ""
    @State private var finderExpandedPaths: Set<String> = ["Part 1", "Part 2", "Part 3", "Part 4"]
    @State private var finderDropTargetPath: String? = nil
    @State private var showFinderNewFolderSheet: Bool = false
    @State private var finderNewFolderParentPath: [String] = []
    @State private var finderNewFolderName: String = ""
    @State private var finderRenamingPath: [String]? = nil
    @State private var finderRenameInput: String = ""
    @State private var showFinderRenameAlert: Bool = false
    @State private var finderCol1Selected: String = "Part 1"
    @State private var finderCol2Selected: String? = "租房场景"
    @State private var finderCol3Selected: String? = nil
    @State private var showListeningCategoryWordBrowser: Bool = false
    @State private var showAllCategoryWords: Bool = false
    @State private var selectedScenarioPreviewDeckID: String? = nil
    @State private var categoryWordSearchQuery: String = "" 
    @State private var dropTargetListeningCategory: String? = nil
    @State private var showListeningCategoryEditor: Bool = false
    @State private var editingListeningCategoryOldName: String? = nil
    @State private var listeningCategoryNameInput: String = ""
    @State private var pendingDeckForNewCategory: String? = nil
    @State private var dropTargetDeckID: String? = nil
    @State private var deckRenameText: String = ""
    @State private var deckToDelete: String? = nil
    @State private var deckEditing: LumaDeckEditTarget? = nil
    private enum DictationSettingsTab: String, CaseIterable {
        case practice = "练习"
        case voice = "发音"
        case more = "更多"
    }

    @State private var dictationMoreShown = false
    @State private var dictationSettingsTab: DictationSettingsTab = .practice
    @AppStorage("luma.listening.speechRate") private var globalListeningSpeechRate: Double = 1.0
    @AppStorage("luma.listening.defaultShowMeaning") private var globalDefaultShowMeaning: Bool = false
    @AppStorage("luma.listening.defaultShowHint") private var globalDefaultShowHint: Bool = false
    @AppStorage("luma.writing.practiceSeconds") private var globalWritingPracticeSeconds: Int = 1200
    @State private var dictationAnswerFontSize: CGFloat = 140
    @State private var dictationAnswerWraps = false
    @State private var dictationScrollOffsetY: CGFloat = 0
    @State private var dictationSuccessTick = 0
    @Environment(\.lumaDynamicMotion) private var lumaDynamicMotion
    @ScaledMetric(relativeTo: .largeTitle) private var dictationFontCeiling: CGFloat = 140
    @State private var speechSettingsTab: String = "neural" 
    @State private var writingExitDestination = "学习_写作_Task1题库"
    @State private var exitToReading = false
    @State private var exitToExternal = false
    @State private var submissionToDelete: UUID?
    @State private var draftToDelete: UUID?
    @State private var clockToken = UUID()
    // listening_daily_goal_v1
    @State private var readingQuizSpeechIssue: (word: String, message: String)?
    @StateObject private var listeningDailyTimer = StudyDailyTimer()
    @StateObject private var vm: HostStateModel
    @StateObject private var audio = SpeechAudioPipeline()
    @State private var importDraft: VocabularyImportDraft?
    @State private var reviewSession: WritingReviewSession?
    @State private var importShown = false
    @State private var deckSearch = ""
    @State private var dictSearchQuery = ""
    @State private var selectedDictionaryBookID: String? = nil
    @State private var showFirstLetterHint = false
    @State private var showListeningShortcuts = false
    @State private var resumePlaybackRate: Float?
    @State private var selectedTask2QuestionID: String = "教01"
    @State private var selectedTask2Category: String = "全部"
    @State private var task2SearchQuery: String = ""
    @State private var showTask2Editor = false
    @State private var editingTask2Item: LumaTask2TopicItem? = nil
    @State private var showTask1Editor = false
    @State private var editingTask1Item: Task1QuestionItem? = nil
    @State private var showMockExamSetup = false
    @State private var mockTask1ID = ""
    @State private var mockTask2ID = ""
    @State private var showWritingBankManager = false
    @State private var selectedHeatmapCell: StudyHeatmapDayCell? = nil
    @State private var customPhraseToImport: String = ""
    @State private var customPhraseMeaningZH: String = ""
    @State private var writingVocabToastMessage: String? = nil
    @State private var cloudSyncBannerText: String? = nil
    @State private var topSyncToast: String? = nil
    @FocusState private var answerFocused: Bool
    @FocusState private var task2SearchFocused: Bool

    @State private var categoryWordLimit: Int = 80
    /// 1.11.0 选择题背词：当前背诵的词库（与听写会话的 selectedDeck 分开，互不影响）。
    @State private var readingReviewWords: [VocabularyWord] = []
    @State private var readingVocabularyPosition = ReadingVocabularyPosition()
    @State private var readingFolderPath: [String] = []
    @State private var readingFolderSearch = ""
    @State private var readingFolderCardID: String?
    @State private var listeningCardID: String?
    @State private var readingQuizReturn = "学习_阅读词汇"
    @AppStorage("luma.choiceQuiz.deck") private var choiceQuizDeckID: String = ""
    @ObservedObject private var choiceLibrary = LumaChoiceLibrary.shared
    @AppStorage("luma.confusable.scope") private var confusableScope: String = "all"

    private var allWords: [VocabularyWord] {
        vm.fastAllWords
    }

    private var ttsEngine: MacOSSpeechSynthesisManager { vm.speech }
    private let evaluateWriting: (@MainActor (WritingSubmissionRecord, Task1QuestionItem) async throws -> IELTSFourCriteriaEstimate)?

    public init(mode: Binding<String>, storageDirectory: URL? = nil, session: LumaStudySession? = nil, evaluateWriting: (@MainActor (WritingSubmissionRecord, Task1QuestionItem) async throws -> IELTSFourCriteriaEstimate)? = nil) {
        self._vm = StateObject(wrappedValue: session?.model ?? HostStateModel(storageDirectory: storageDirectory))
        self._mode = mode
        self.evaluateWriting = evaluateWriting
    }

    private var isPractice: Bool { mode.contains("模拟机考") || (mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习") }

    private var hasUnfinishedListeningSession: Bool {
        let activeDeck = vm.dictationMachine.currentWord?.deckID ?? vm.dictationMachine.attemptLogs.last?.deckID ?? vm.selectedDeck
        guard visibleListeningDeckIDs.contains(activeDeck) else { return false }
        return !vm.dictationMachine.isSessionFinished &&
        (!vm.dictationMachine.completedWordIDs.isEmpty ||
         !vm.dictationMachine.attemptLogs.isEmpty ||
         !vm.dictationInput.isEmpty ||
         vm.dictationMachine.requiresCorrection)
    }

    private var hasUnfinishedWritingDraft: Bool {
        let submittedIDs = Set(vm.storeSnapshot.writingSubmissions.map(\.draftSessionID))
        guard !submittedIDs.contains(vm.currentDraft.id) else { return false }
        return !vm.currentDraft.part1EssayText.isEmpty || !vm.currentDraft.part2EssayText.isEmpty || vm.currentDraft.elapsedSeconds > 0
    }

    /// 当前处在「⋯」菜单里的页面时，在菜单按钮上显示页面名，保证用户知道自己在哪。
    private var studyMoreMenuCurrentTitle: String? {
        switch mode {
        case "学习_听力_慢反应词": return "慢反应词"
        case "学习_听力_顽固单词": return "顽固单词"
        case "学习_草稿": return "草稿"
        case "学习_写作_历史作文", "学习_写作_评分反馈": return "历史作文"
        default: return nil
        }
    }

    public var body: some View {
        ZStack {
            appearance.background.ignoresSafeArea()

            VStack(spacing: ["学习_听力", "学习_听力_我的词库", "学习_听力_今日计划", "学习_听力_错词复习"].contains(mode) ? 0 : 12) {
                // 听写练习页（今日计划/错词复习）顶部仅保留「词汇听写 34 / 968」与右侧「1.5× │ ☰」「01:03:01」两枚胶囊，
                // 词库、多本重练、错词、记录、语音及设置统一收纳在「☰」菜单中。
                if mode != "学习_听力_今日计划" && mode != "学习_听力_错词复习" && !mode.hasPrefix("学习_阅读") && !mode.hasPrefix("学习_背词") && !mode.hasPrefix("学习_易混词") && !mode.contains("模拟机考") {
                HStack(spacing: 12) {
                    if mode.contains("听力") || ((mode.contains("写作") || mode == "学习_草稿") && !mode.contains("模拟机考")) {
                        HStack(spacing: 6) {
                            if mode.contains("听力") {
                                Button("词库") {
                                    showListeningCategoryBar = false
                                    mode = "学习_听力"
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_听力" || mode == "学习_听力_我的词库", horizontalPadding: 12, height: 32))

                                Button("错词") { ttsEngine.stop(); audio.stop(); kokoro.stop(); mode = "学习_听力_错词" }
                                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_听力_错词", horizontalPadding: 12, height: 32))

                                Button("分类") {
                                    showListeningCategoryBar = false
                                    mode = "学习_听力_分类"
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_听力_分类", horizontalPadding: 12, height: 32))
                                if hasUnfinishedListeningSession {
                                    Button {
                                        mode = vm.dictationMachine.mode == .wrongWordReview ? "学习_听力_错词复习" : "学习_听力_今日计划"
                                    } label: {
                                        Label("继续听写", systemImage: "play.fill")
                                    }
                                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                                }

                            } else {
                                if hasUnfinishedWritingDraft {
                                    Button { mode = "学习_写作_模拟机考" } label: { Label("继续写作", systemImage: "play.fill") }
                                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                                }
                                Button("Task 1") {
                                    if vm.practiceSeconds == 2400 { vm.practiceSeconds = 1200 }
                                    mode = "学习_写作_Task1题库"
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_写作_Task1题库", horizontalPadding: 12, height: 32))
                                Button("Task 2") {
                                    if vm.practiceSeconds == 1200 { vm.practiceSeconds = 2400 }
                                    mode = "学习_写作_Task2题库"
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_写作_Task2题库", horizontalPadding: 12, height: 32))
                                Button {
                                    presentMockExamSetup()
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 10.5, weight: .semibold))
                                        Text("模拟考试")
                                            .lumaFont(size: 11.5, weight: .semibold)
                                    }
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: false, horizontalPadding: 12, height: 32))
                                .help("60 分钟完整模拟：自选一篇 Task 1 + 一篇 Task 2")
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .studyGlassCapsule(cornerRadius: 22)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)

                    if let banner = topSyncToast {
                        Text(banner)
                            .lumaFont(size: 11)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 320, alignment: .trailing)
                            .transition(.opacity.combined(with: .offset(x: 12)))
                            .onTapGesture { topSyncToast = nil }
                    }

                    Menu {
                        if mode.contains("听力") {
                            Section("听力") {
                                Button {
                                    NotificationCenter.default.post(name: LumaMiniPracticeNotification.open, object: nil,
                                                                    userInfo: ["source": "listening", "scope": vm.selectedDeck])
                                } label: { Label("小窗听写（悬浮置顶）", systemImage: "pip") }
                                Button { mode = "学习_听力_学习记录" } label: { Label("学习记录", systemImage: "chart.bar.xaxis") }
                                Button { mode = "学习_听力_慢反应词" } label: { Label("慢反应词 (\((vm.storeSnapshot.slowReactionWords ?? []).count))", systemImage: "tortoise") }
                                Button { mode = "学习_听力_顽固单词" } label: { Label("顽固单词", systemImage: "exclamationmark.triangle") }
                            }
                        } else if mode.contains("写作") || mode == "学习_草稿" {
                            Section("写作") {
                                Button { presentMockExamSetup() } label: { Label("模拟考试（Task 1 + Task 2）", systemImage: "timer") }
                                Button { startFreeWriting() } label: { Label("自由写作（无题目）", systemImage: "square.and.pencil") }
                                if mode.contains("模拟机考") {
                                    Button {
                                        launchExam(for: vm.selectedExamQuestion, singleTask: vm.currentDraft.isSingleTaskMode, forceNew: true)
                                    } label: { Label("重新开始本篇", systemImage: "arrow.counterclockwise") }
                                }
                                Button { mode = "学习_草稿" } label: { Label("草稿", systemImage: "doc.text") }
                                Button { mode = "学习_写作_历史作文" } label: { Label("历史作文", systemImage: "clock.arrow.circlepath") }
                            }
                        }
                        Section {
                            Button {
                                let count = vm.syncWithConnectedCloudDrives()
                                cloudSyncBannerText = count > 0
                                    ? "☁️ 已将 luma_study_store.json (词库/慢反应词/顽固词/写作草稿与作文) 同步至 \(count) 个云盘目录"
                                    : "☁️ 已保存本地学习中心快照（连接 iCloud/OneDrive/Google Drive 后自动跨设备同步）"
                                topSyncToast = count > 0 ? "已同步至 \(count) 个云盘" : "已保存本地快照（连接云盘后自动同步）"
                            } label: { Label("同步学习数据到云盘", systemImage: "icloud.and.arrow.up") }
                            Button {
                                if mode.contains("模拟机考") {
                                    exitToReading = true; showWritingExit = true
                                } else {
                                    vm.save()
                                    NotificationCenter.default.post(name: Notification.Name("LumaReader.ResumeReadingWorkspace"), object: nil)
                                }
                            } label: { Label("继续阅读  ⌥⌘5", systemImage: "book.pages") }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "ellipsis")
                            if let current = studyMoreMenuCurrentTitle {
                                Text(current)
                            }
                        }
                    }
                    .menuStyle(.button)
                    .menuIndicator(.hidden)
                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: studyMoreMenuCurrentTitle != nil, horizontalPadding: 12, height: 32))
                    .fixedSize()
                    .help("更多：不常用页面、云盘同步、继续阅读")
                }
                .padding(.leading, isPractice ? 102 : 32)
                .padding(.trailing, 32)
                .padding(.vertical, 10)
                .padding(.top, mode.contains("模拟机考") ? 44 : (isPractice ? 12 : 0))
                .background {
                    if mode == "学习_听力" || mode == "学习_听力_我的词库" {
                        appearance.background
                    }
                }
                .zIndex(1)
                .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9), value: topSyncToast)
                .task(id: topSyncToast) {
                    guard topSyncToast != nil else { return }
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    topSyncToast = nil
                }
                }

                if let error = vm.storageError {
                    HStack {
                        Text(error).foregroundStyle(.red).textSelection(.enabled)
                        Spacer()
                        Button("关闭提示") { vm.storageError = nil }
                    }.padding(.horizontal, 24)
                }

                switch mode {
                case "学习": studyHome
                case "学习_听力", "学习_听力_我的词库": listeningHome
                case "学习_听力_分类": listeningCategoriesDedicatedView
                case "学习_听力_权威词典": builtInDictionariesDedicatedView
                case "学习_草稿":
                    List(Array(vm.storeSnapshot.activeWritingDrafts.values).filter { draft in
                        !vm.storeSnapshot.writingSubmissions.contains { $0.draftSessionID == draft.id }
                    }.sorted { $0.lastSavedAt > $1.lastSavedAt }, id: \.id) { draft in
                        HStack {
                            VStack(alignment:.leading,spacing:6) {
                                Text(draft.examTitle).font(.headline)
                                Text(draft.part1EssayText.isEmpty ? draft.part2EssayText : draft.part1EssayText).lineLimit(2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("编辑草稿") {
                                if let question = vm.allTask1Questions.first(where: { $0.id == draft.questionID }) {
                                    vm.selectedExamQuestion = question; vm.currentDraft = draft
                                    vm.beginWritingEdit(); mode = "学习_写作_模拟机考"
                                } else if let topic2 = vm.allTask2Topics.first(where: { $0.id == draft.questionID }) {
                                    vm.selectedExamQuestion = topic2.asExamQuestionItem(fallbackTask1: Self.builtInPracticeQuestions[0])
                                    vm.currentDraft = draft
                                    vm.beginWritingEdit(); mode = "学习_写作_模拟机考"
                                }
                            }
                            Button("删除",role:.destructive) { draftToDelete = draft.id }
                        }.padding(.vertical,8)
                    }
                case "学习_听力_今日计划":
                    listeningCenterView(submode: .newTask)
                case "学习_听力_错词复习":
                    listeningCenterView(submode: .wrongWordReview)
                case "学习_听力_错词":
                    wrongWordsCenterPage
                case "学习_阅读词汇", "学习_阅读错词", "学习_阅读分类", "学习_背词", "学习_易混词":
                    readingVocabularySection
                case "学习_雅思阅读":
                    IELTSReadingPractice()
                case "学习_背词_练习":
                    choiceQuizPage
                case "学习_易混词_练习":
                    LumaConfusablePracticePage(scope: confusableScope, onExit: { mode = "学习_易混词" })
                case "学习_听力_慢反应词":
                    slowReactionWordsDedicatedView
                case "学习_听力_顽固单词":
                    stubbornWordsDedicatedView
                case "学习_听力_学习记录":
                    listeningRecordsDedicatedView
                case "学习_模拟机考", "学习_写作_模拟机考":
                    VStack(spacing: 0) {
                        IELTSWritingExamSplitPaneView(
                            question: vm.selectedExamQuestion,
                            draft: $vm.currentDraft,
                            onAutoSave: { updated in
                                vm.storeDraft(updated)
                            },
                            onSubmitExam: { submittedDraft in
                                submitWritingExam(submittedDraft)
                            },
                            onNavigateBack: {
                                writingExitDestination = "学习_写作_Task1题库"
                                exitToReading = false; showWritingExit = true
                            }
                        )
                    }
                case "学习_写作_Task2题库":
                    task2QuestionBankView
                case "学习_写作_历史作文", "学习_写作_评分反馈":
                    writingHistoryAndFeedbackView
                case "学习_统计":
                    studyStatisticsView
                default:
                    Task1QuestionBankHomeView(
                        allCatalogItems: vm.allTask1Questions,
                        onLaunchExam: { chosen in
                            launchExam(for: chosen, singleTask: vm.practiceSeconds != 3600, initialPart: .part1)
                        },
                        onAddQuestion: {
                            editingTask1Item = nil
                            showTask1Editor = true
                        },
                        onEditQuestion: { item in
                            editingTask1Item = item
                            showTask1Editor = true
                        },
                        onDeleteQuestion: { id in
                            vm.deleteTask1Question(id: id)
                        },
                        onChangeCategory: { item, newCat in
                            let updated = Task1QuestionItem(
                                id: item.id,
                                shortTitle: item.shortTitle,
                                category: newCat,
                                difficultyBand: item.difficultyBand,
                                promptText: item.promptText,
                                minimumWords: item.minimumWords,
                                recommendedMinutes: item.recommendedMinutes,
                                sourceName: item.sourceName,
                                sourceURL: item.sourceURL,
                                licenseStatus: item.licenseStatus,
                                chartDataset: LumaTask1DefaultDataset.make(for: newCat),
                                companionTask2ID: item.companionTask2ID,
                                companionTask2Prompt: item.companionTask2Prompt,
                                notes: item.notes
                            )
                            vm.addOrUpdateTask1Question(updated)
                        },
                        onOpenBankManager: {
                            showWritingBankManager = true
                        }
                    )
                }
            }
        }
        .fileImporter(isPresented: $importShown, allowedContentTypes: [.plainText, .utf8PlainText, .tabSeparatedText, .commaSeparatedText, .json]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                importDraft = try VocabularyImportDraft(data: data, filename: url.lastPathComponent)
            } catch { vm.storageError = "导入失败，现有词库和记录未更改：\(error.localizedDescription)" }
        }
        .sheet(item: $importDraft) { draft in
            VocabularyImportReview(draft: draft, existing: allWords, onConfirm: saveImportedWords)
                .environment(\.studyAppearance, appearance)
        }
        .sheet(item: $reviewSession) { session in
            WritingReviewPanel(
                session: session,
                onSave: saveWritingRevision,
                onImportWordsToListening: { words in
                    _ = saveImportedWords(words)
                }
            )
        }
        .sheet(isPresented: $showTask2Editor) {
            LumaWritingTopicEditorSheet(
                initialItem: editingTask2Item,
                isNew: editingTask2Item == nil,
                availableCategories: vm.availableTask2Categories,
                defaultCategory: selectedTask2Category == "全部" ? "教育" : selectedTask2Category,
                suggestedID: String(format: "自定义-%02d", (vm.storeSnapshot.customTask2Topics?.count ?? 0) + 1),
                onSave: { saved, newCat in
                    vm.addOrUpdateTask2Topic(saved, newCategory: newCat)
                    selectedTask2QuestionID = saved.id
                },
                onDelete: { id in
                    vm.deleteTask2Topic(id: id)
                }
            )
        }
        .sheet(isPresented: $showMockExamSetup) {
            writingMockExamSetupSheet
        }
        .sheet(isPresented: $showTask1Editor) {
            LumaTask1QuestionEditorSheet(
                initialItem: editingTask1Item,
                isNew: editingTask1Item == nil,
                suggestedID: String(format: "ORIG-%03d", vm.allTask1Questions.count + 1),
                onSave: { saved in
                    vm.addOrUpdateTask1Question(saved)
                },
                onDelete: { id in
                    vm.deleteTask1Question(id: id)
                }
            )
        }
        .sheet(isPresented: $showWritingBankManager) {
            LumaWritingBankManagerSheet(
                allTask2Topics: vm.allTask2Topics,
                allTask1Questions: vm.allTask1Questions,
                availableCategories: vm.availableTask2Categories,
                deletedTask2Count: (vm.storeSnapshot.deletedTask2TopicIDs ?? []).count,
                deletedTask1Count: (vm.storeSnapshot.deletedTask1QuestionIDs ?? []).count,
                onAddTask2: { editingTask2Item = nil; showTask2Editor = true },
                onEditTask2: { item in editingTask2Item = item; showTask2Editor = true },
                onDeleteTask2: { id in vm.deleteTask2Topic(id: id) },
                onAddTask1: { editingTask1Item = nil; showTask1Editor = true },
                onEditTask1: { item in editingTask1Item = item; showTask1Editor = true },
                onDeleteTask1: { id in vm.deleteTask1Question(id: id) },
                onAddCategory: { cat in vm.addTask2Category(cat) },
                onDeleteCategory: { cat in vm.deleteTask2Category(cat) },
                onRestoreDefaults: { vm.restoreDeletedBuiltInQuestions() }
            )
        }
        // 1.12.1: 去掉整页 value: mode 的隐式动画——它会让整棵听写页面（含侧栏宽度变化）在切换瞬间一起做布局动画，造成卡顿和不跟手。
        // 离开写作确认：改用应用内自绘对话框（系统 alert 在写作计时界面里按钮会失效）
        .sheet(isPresented: $showWritingExit, onDismiss: {
            if !writingExitResolved { cancelWritingExit() }
            writingExitResolved = false
        }) {
            writingExitDialog
        }
        .alert("删除这份草稿？",isPresented:Binding(get:{draftToDelete != nil},set:{if !$0 {draftToDelete = nil}})) {
            Button("删除草稿",role:.destructive) { if let id = draftToDelete { _ = vm.deleteWritingDraft(id) }; draftToDelete = nil }
            Button("保留草稿",role:.cancel) { draftToDelete = nil }
        } message: { Text("已提交的历史作文不会被删除。") }
        .alert("删除这篇作文？",isPresented:Binding(get:{submissionToDelete != nil},set:{if !$0 {submissionToDelete = nil}})) {
            Button("删除作文",role:.destructive) { if let id = submissionToDelete { _ = vm.deleteWritingSubmission(id) }; submissionToDelete = nil }
            Button("保留作文",role:.cancel) { submissionToDelete = nil }
        } message: { Text("这篇作文及其重写版本将被删除。") }
        .onAppear {
            if mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习" { listeningDailyTimer.start() }
            if mode.contains("模拟机考") { vm.beginWritingEdit() }
            syncActiveWritingQuestionForAI()
            vm.remember(mode)
            if mode == "学习_模拟机考" || mode == "学习_写作_模拟机考" {
                vm.startContinuousExamClockIfNeeded { expiredDraft in
                    submitWritingExam(expiredDraft)
                }
            }
            #if DEBUG
            let debugEnv = ProcessInfo.processInfo.environment
            if debugEnv["LUMA_DEBUG_MOCK_SHEET"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { presentMockExamSetup() }
            }
            if debugEnv["LUMA_DEBUG_FREE_WRITING"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { startFreeWriting() }
            }
            #endif
        }
        // listening_pause_input_v2
        .onChange(of: listeningDailyTimer.running) { _, running in
            if running {
                let rate = resumePlaybackRate; resumePlaybackRate = nil
                answerFocused = true
                if let rate {
                    speakCurrentWord(overrideRate: rate)
                } else if pendingDictationPlayback == nil {
                    scheduleDictationPlayback()
                }
            } else {
                pendingDictationPlayback?.cancel()
                pendingDictationPlayback = nil
                answerFocused = false
                ttsEngine.stop(); audio.stop(); kokoro.stop(); kokoro.suspendPreload()
                vm.scheduleSave(after: 0.3)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumaReader.DictationAudioFinished"))) { notification in
            guard listeningDailyTimer.running,
                  let spoken = notification.userInfo?["text"] as? String,
                  spoken == vm.dictationMachine.currentWord?.word.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            vm.audioPlaybackFinishedAt = Date()
        }
        // model_replay_state_v8
        .onChange(of: kokoro.isSwitching) { _, switching in
            if switching { ttsEngine.stop(); audio.stop(); kokoro.stop(); answerFocused = false }
        }
        .onReceive(kokoro.$statusText) { status in
            if kokoro.isPreparingAudio || status.contains("失败") { vm.dictationFeedback = status }
        }
        .onChange(of: vm.dictationInput) { _, _ in vm.scheduleSave(after: 0.8) }
        .onChange(of: vm.currentDraft) { _, updated in vm.storeDraft(updated); syncActiveWritingQuestionForAI(draft: updated) }
        .onChange(of: vm.selectedExamQuestion) { _, newQ in syncActiveWritingQuestionForAI(question: newQ) }
        .onChange(of: selectedTask2QuestionID) { _, newID in
            if let t2 = vm.allTask2Topics.first(where: { $0.id == newID }) {
                let fallbackT1 = vm.allTask1Questions.first ?? Self.builtInPracticeQuestions[0]
                syncActiveWritingQuestionForAI(question: t2.asExamQuestionItem(fallbackTask1: fallbackT1))
            }
        }
        .onChange(of: vm.practiceSeconds) { _, newSecs in
            guard vm.currentDraft.questionID != "FREE-WRITING" else { return }
            let isSingle = (newSecs != 3600)
            if vm.currentDraft.isSingleTaskMode != isSingle {
                vm.currentDraft.isSingleTaskMode = isSingle
                if isSingle {
                    vm.currentDraft.activePart = (newSecs == 2400) ? .part2 : .part1
                    if vm.currentDraft.remainingSeconds > newSecs {
                        vm.currentDraft.remainingSeconds = max(60, newSecs - vm.currentDraft.elapsedSeconds)
                    }
                }
                vm.storeDraft(vm.currentDraft)
            }
        }
        .onChange(of: vm.speechRateMultiplier) { _, newRate in
            if abs(globalListeningSpeechRate - Double(newRate)) > 0.01 {
                globalListeningSpeechRate = Double(newRate)
            }
            vm.save()
            if mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习" {
                speakCurrentWord()
            }
        }
        .onChange(of: globalListeningSpeechRate) { _, newRate in
            if abs(Double(vm.speechRateMultiplier) - newRate) > 0.01 {
                vm.speechRateMultiplier = Float(newRate)
            }
        }
        .onChange(of: globalDefaultShowMeaning) { _, show in
            if vm.showMeaning != show { vm.showMeaning = show; vm.save() }
        }
        .onChange(of: globalDefaultShowHint) { _, show in
            if showFirstLetterHint != show { showFirstLetterHint = show }
        }
        .onChange(of: globalWritingPracticeSeconds) { _, secs in
            if vm.practiceSeconds != secs { vm.practiceSeconds = secs }
        }
        .onChange(of: vm.selectedAccent) { _, _ in
            vm.save()
            if mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习" {
                speakCurrentWord()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("LumaReader.RequestWritingExit"))) { _ in
            guard mode.contains("模拟机考") else { return }
            exitToExternal = true; exitToReading = false; showWritingExit = true
        }
        // auto_recall_v3
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习" else { return }
            guard vm.dictationMachine.currentWord != nil else { return }
            // Stay paused after app switching or sleep; the existing play control resumes explicitly.
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            listeningDailyTimer.pause(); ttsEngine.stop(); audio.stop(); kokoro.stop(); kokoro.suspendPreload(); audio.releaseUnusedMemory(); vm.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumaReader.MemoryPressure"))) { _ in audio.releaseUnusedMemory() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumaReader.AppDidResignActive"))) { _ in
            listeningDailyTimer.pause(); ttsEngine.stop(); audio.stop(); kokoro.stop(); kokoro.suspendPreload()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in listeningDailyTimer.pause(); vm.save() }
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("LumaReader.WritingToolbarAction"))) { note in
            guard let action = note.userInfo?["action"] as? String else { return }
            switch action {
            case "mock": presentMockExamSetup()
            case "free": startFreeWriting()
            case "restart":
                launchExam(for: vm.selectedExamQuestion, singleTask: vm.currentDraft.isSingleTaskMode, forceNew: true)
            case "drafts":
                vm.save()
                mode = "学习_草稿"
            case "history":
                mode = "学习_写作_历史作文"
            case "sync":
                let count = vm.syncWithConnectedCloudDrives()
                cloudSyncBannerText = count > 0
                    ? "☁️ 已将 luma_study_store.json 同步至 \(count) 个云盘目录"
                    : "☁️ 已保存本地学习中心快照"
                topSyncToast = count > 0 ? "已同步至 \(count) 个云盘" : "已保存本地快照"
            case "reading":
                exitToReading = true; showWritingExit = true
            default: break
            }
        }
        .onChange(of:appearance.visualThemeSystem) { _,_ in
            dictationErrorFeedbackTask?.cancel()
            withTransaction(Transaction(animation:nil)) { dictationErrorFlash = false; dictationErrorShake = 0 }
        }
        .onDisappear {
            pendingDictationPlayback?.cancel()
            pendingDictationPlayback = nil
            dictationErrorFeedbackTask?.cancel(); dictationErrorFlash = false; kokoro.suspendPreload(); listeningDailyTimer.pause(); if vm.clockOwner == clockToken { vm.clockOwner = nil }; vm.save(); ttsEngine.stop(); audio.stop(); kokoro.stop()
        }
        .onChange(of: mode) { previous, destination in
            if destination == "学习_听力_今日计划" || destination == "学习_听力_错词复习" { listeningDailyTimer.start() }
            else {
                pendingDictationPlayback?.cancel()
                pendingDictationPlayback = nil
                listeningDailyTimer.pause()
            }
            if previous.contains("模拟机考"), !destination.contains("模拟机考"), !vm.allowWritingNavigation {
                writingExitDestination = destination; exitToReading = false
                mode = previous; showWritingExit = true; return
            }
            vm.allowWritingNavigation = false
            if destination.contains("模拟机考") { vm.beginWritingEdit() }
            vm.remember(destination)
            ttsEngine.stop()
            audio.stop()
            kokoro.stop()
            if destination == "学习_模拟机考" || destination == "学习_写作_模拟机考" {
                vm.startContinuousExamClockIfNeeded { expiredDraft in
                    submitWritingExam(expiredDraft)
                }
            }
        }
        .onReceive(audio.$errorMessage) { message in if let message { vm.dictationFeedback = message } }
        .task {
            await kokoro.ensureDaemonRunning()
            if kokoro.isReady {
                enableLocalSpeechServiceSettings()
                if visibleListeningDeckIDs.contains(vm.selectedDeck) {
                    kokoro.preload(phrases: Array(vm.dictationMachine.pendingQueue.dropFirst().prefix(3).map(\.word)), startIndex: 0, speed: vm.speechRateMultiplier)
                }
                let voiceName = kokoro.activeSlots[kokoro.currentSlot] ?? kokoro.currentSlot.defaultVoice
                vm.dictationFeedback = "本地神经语音已就绪 · \(kokoro.currentSlot.kittenDisplayName) · \(voiceName)"
            } else if let service = vm.storeSnapshot.speechService, service.enabled {
                await audio.connect(service)
            }
        }
    }

    /// 自动根据题目 ID 或标题解析完整的 Task 1 / Task 2 题目（支持全部 Task 1 图表题、200 道 Task 2 机经大作文及自定义题目），无需用户手动向 AI 提交题目。
    private func resolveExamQuestion(for questionID: String, examTitle: String = "") -> Task1QuestionItem {
        if let q1 = vm.allTask1Questions.first(where: { $0.id == questionID }) {
            return q1
        }
        let fallbackT1 = vm.allTask1Questions.first ?? Self.builtInPracticeQuestions[0]
        if let t2 = vm.allTask2Topics.first(where: { $0.id == questionID }) {
            return t2.asExamQuestionItem(fallbackTask1: fallbackT1)
        }
        if !examTitle.isEmpty,
           let byTitle = vm.allTask2Topics.first(where: { examTitle.contains($0.shortTitle) || examTitle.contains($0.id) }) {
            return byTitle.asExamQuestionItem(fallbackTask1: fallbackT1)
        }
        if vm.selectedExamQuestion.id == questionID {
            return vm.selectedExamQuestion
        }
        return fallbackT1
    }

    /// 实时将当前正在练习或选中的写作题目、图表数据与草稿同步至全局 AI 上下文，使 AI 无需用户提交题目即可自动感知当前题目。
    private func syncActiveWritingQuestionForAI(question: Task1QuestionItem? = nil, draft: WritingExamDraftState? = nil) {
        let activeDraft = draft ?? vm.currentDraft
        let resolvedQ = question ?? resolveExamQuestion(for: activeDraft.questionID, examTitle: activeDraft.examTitle)
        let activePart = activeDraft.activePart
        let isSingle = activeDraft.isSingleTaskMode
        let modeDesc: String
        let promptDesc: String
        if isSingle {
            if activePart == .part1 {
                modeDesc = "Task 1 小作文专项练习 (20分钟 · ≥150词)"
                promptDesc = resolvedQ.promptText
            } else {
                modeDesc = "Task 2 大作文专项练习 (40分钟 · ≥250词)"
                promptDesc = resolvedQ.companionTask2Prompt ?? resolvedQ.promptText
            }
        } else {
            modeDesc = "雅思写作完整模拟考试 (Task 1 + Task 2 · 60分钟)"
            promptDesc = "【Task 1 题目】：\(resolvedQ.promptText)\n【Task 2 题目】：\(resolvedQ.companionTask2Prompt ?? "无")"
        }
        var chartInfo = ""
        if (!isSingle || activePart == .part1), let ds = resolvedQ.chartDataset {
            let xLabels = ds.xAxisLabels.joined(separator: ", ")
            let seriesStr = ds.series.map { "\($0.name) (\($0.unit)): \($0.values.map { String(format: "%.1f", $0) }.joined(separator: ", "))" }.joined(separator: " | ")
            if !seriesStr.isEmpty {
                chartInfo = "图表类型：\(resolvedQ.category.rawValue)｜横轴：\(xLabels)｜数据：\(seriesStr)"
            }
        }
        let ud = UserDefaults.standard
        ud.set(resolvedQ.id, forKey: "luma.ai.activeWritingQuestionID")
        ud.set("\(resolvedQ.id) · \(resolvedQ.shortTitle)", forKey: "luma.ai.activeWritingTitle")
        ud.set(modeDesc, forKey: "luma.ai.activeWritingMode")
        ud.set(promptDesc, forKey: "luma.ai.activeWritingPrompt")
        ud.set(chartInfo, forKey: "luma.ai.activeWritingChartData")
        ud.set(activeDraft.part1EssayText, forKey: "luma.ai.activeWritingPart1Draft")
        ud.set(activeDraft.part2EssayText, forKey: "luma.ai.activeWritingPart2Draft")
    }

    private var writingMockExamSetupSheet: some View {
        let task1Items = vm.allTask1Questions
        let task2Items = vm.allTask2Topics
        let selected1 = task1Items.first { $0.id == mockTask1ID } ?? task1Items.first
        let selected2 = task2Items.first { $0.id == mockTask2ID } ?? task2Items.first
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("模拟考试")
                        .lumaFont(size: 21, weight: .bold, design: .serif)
                        .foregroundStyle(appearance.ink)
                    Text("一次考试 = 一篇 Task 1 + 一篇 Task 2 · 60 分钟")
                        .lumaFont(size: 12)
                        .foregroundStyle(appearance.ink.opacity(0.62))
                }
                Spacer()
                Button { showMockExamSetup = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(appearance.surface.opacity(0.8)))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Task 1 题目")
                    .lumaFont(size: 12, weight: .semibold)
                    .foregroundStyle(appearance.accent)
                Picker("", selection: $mockTask1ID) {
                    ForEach(task1Items) { item in
                        Text("\(item.id) · \(item.shortTitle)").tag(item.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let selected1 {
                    Text(selected1.promptText)
                        .lumaFont(size: 11.5, design: .serif)
                        .foregroundStyle(appearance.ink.opacity(0.72))
                        .lineLimit(2)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Task 2 题目")
                    .lumaFont(size: 12, weight: .semibold)
                    .foregroundStyle(appearance.accent)
                Picker("", selection: $mockTask2ID) {
                    ForEach(task2Items) { item in
                        Text("\(item.id) · \(item.shortTitle)").tag(item.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let selected2 {
                    Text(selected2.promptText)
                        .lumaFont(size: 11.5, design: .serif)
                        .foregroundStyle(appearance.ink.opacity(0.72))
                        .lineLimit(2)
                }
            }

            Divider().overlay(appearance.line.opacity(0.6))

            HStack {
                Spacer()
                Button("取消") { showMockExamSetup = false }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 16, height: 32))
                Button("开始考试") { startMockExam() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 18, height: 32))
                    .disabled(selected1 == nil || selected2 == nil)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 680)
        .background(appearance.paper)
        .environment(\.studyAppearance, appearance)
        .onAppear {
            if selected1 == nil { mockTask1ID = task1Items.first?.id ?? "" }
            if selected2 == nil { mockTask2ID = task2Items.first?.id ?? "" }
        }
    }

    private func presentMockExamSetup() {
        if mockTask1ID.isEmpty { mockTask1ID = vm.allTask1Questions.first?.id ?? "" }
        if mockTask2ID.isEmpty { mockTask2ID = vm.allTask2Topics.first?.id ?? "" }
        showMockExamSetup = true
    }

    private func startMockExam() {
        guard let t1 = vm.allTask1Questions.first(where: { $0.id == mockTask1ID }) ?? vm.allTask1Questions.first,
              let t2 = vm.allTask2Topics.first(where: { $0.id == mockTask2ID }) ?? vm.allTask2Topics.first else { return }
        let combined = Task1QuestionItem(
            id: "MOCK-\(t1.id)-\(t2.id)",
            shortTitle: "模拟考试 · \(t1.shortTitle) + \(t2.shortTitle)",
            category: t1.category,
            difficultyBand: t1.difficultyBand,
            promptText: t1.promptText,
            minimumWords: t1.minimumWords,
            recommendedMinutes: 60,
            sourceName: t1.sourceName,
            sourceURL: t1.sourceURL,
            licenseStatus: t1.licenseStatus,
            chartDataset: t1.chartDataset,
            companionTask2ID: t2.id,
            companionTask2Prompt: t2.promptText,
            notes: nil
        )
        vm.practiceSeconds = 3600
        showMockExamSetup = false
        launchExam(for: combined, singleTask: false, forceNew: true)
    }

    private func startFreeWriting() {
        vm.save()
        let blank = Task1QuestionItem(
            id: "FREE-WRITING",
            shortTitle: "自由写作",
            category: .processDiagram,
            difficultyBand: "",
            promptText: "",
            minimumWords: 250,
            recommendedMinutes: 60,
            sourceName: "Luma",
            sourceURL: "",
            licenseStatus: .originalSelfAuthored,
            chartDataset: nil,
            companionTask2ID: nil,
            companionTask2Prompt: nil,
            notes: nil
        )
        vm.selectedExamQuestion = blank
        vm.practiceSeconds = 3600
        vm.currentDraft = WritingExamDraftState(
            id: UUID(),
            questionID: blank.id,
            examTitle: "自由写作",
            activePart: .part2,
            part1EssayText: "",
            part2EssayText: "",
            remainingSeconds: 3600,
            elapsedSeconds: 0,
            isPaused: false,
            isSingleTaskMode: true,
            lastSavedAt: Date(),
            containsLegacyNonEnglishNotice: false
        )
        vm.beginWritingEdit(isNew: true)
        vm.storeDraft(vm.currentDraft)
        syncActiveWritingQuestionForAI(question: blank, draft: vm.currentDraft)
        vm.startContinuousExamClockIfNeeded { expiredDraft in
            submitWritingExam(expiredDraft)
        }
        mode = "学习_写作_模拟机考"
    }

    private func launchExam(for chosen: Task1QuestionItem, singleTask: Bool, initialPart: ExamPart = .part1, forceNew: Bool = false) {
        vm.save()
        vm.selectedExamQuestion = chosen
        let isMockExamMode = (vm.practiceSeconds == 3600) && !singleTask
        let effectiveSingleTask = !isMockExamMode
        let targetPart: ExamPart = effectiveSingleTask ? initialPart : .part1
        let targetSeconds: Int = effectiveSingleTask ? (targetPart == .part1 ? 1200 : 2400) : 3600

        if !forceNew, let existing = vm.existingUnsubmittedDraft(for: chosen.id, singleTask: nil, activePart: effectiveSingleTask ? targetPart : nil) {
            var resumed = existing
            resumed.isSingleTaskMode = effectiveSingleTask
            if effectiveSingleTask {
                resumed.activePart = targetPart
                if resumed.remainingSeconds > targetSeconds {
                    resumed.remainingSeconds = max(60, targetSeconds - resumed.elapsedSeconds)
                }
            }
            vm.currentDraft = resumed
            vm.beginWritingEdit()
            vm.storeDraft(vm.currentDraft)
            syncActiveWritingQuestionForAI(question: chosen, draft: vm.currentDraft)
            vm.startContinuousExamClockIfNeeded { expiredDraft in
                submitWritingExam(expiredDraft)
            }
            mode = "学习_写作_模拟机考"
            return
        }
        vm.currentDraft = WritingExamDraftState(
            id: UUID(),
            questionID: chosen.id,
            examTitle: "\(chosen.id) · \(chosen.shortTitle)",
            activePart: targetPart,
            part1EssayText: "",
            part2EssayText: "",
            remainingSeconds: targetSeconds,
            elapsedSeconds: 0,
            isPaused: false,
            isSingleTaskMode: effectiveSingleTask,
            lastSavedAt: Date(),
            containsLegacyNonEnglishNotice: false
        )
        vm.beginWritingEdit(isNew: true)
        vm.storeDraft(vm.currentDraft)
        syncActiveWritingQuestionForAI(question: chosen, draft: vm.currentDraft)
        vm.startContinuousExamClockIfNeeded { expiredDraft in
            submitWritingExam(expiredDraft)
        }
        mode = "学习_写作_模拟机考"
    }

    private var writingExitDialog: some View {
        VStack(alignment: .leading, spacing: 14) {
                Text("离开本次写作？")
                    .lumaFont(size: 16, weight: .semibold)
                    .foregroundStyle(appearance.ink)
                Text("保存会保留当前草稿；放弃会恢复到进入本次编辑前的版本。")
                    .lumaFont(size: 13)
                    .foregroundStyle(appearance.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    Button { finishWritingExit(discard: false) } label: {
                        Text("保存并退出")
                            .lumaFont(size: 13, weight: .semibold)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Capsule(style: .continuous).fill(appearance.accent))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    Button { finishWritingExit(discard: true) } label: {
                        Text("放弃本次更改")
                            .lumaFont(size: 13, weight: .medium)
                            .foregroundStyle(Color.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Capsule(style: .continuous).fill(appearance.surface.opacity(0.65)))
                            .overlay(Capsule(style: .continuous).strokeBorder(Color.red.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Button { cancelWritingExit() } label: {
                        Text("继续编辑")
                            .lumaFont(size: 13, weight: .medium)
                            .foregroundStyle(appearance.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Capsule(style: .continuous).fill(appearance.surface.opacity(0.65)))
                            .overlay(Capsule(style: .continuous).strokeBorder(appearance.line.opacity(0.7), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
            }
        .padding(24)
        .frame(width: 340)
        .background(appearance.surface)
        .environment(\.studyAppearance, appearance)
    }

    private func cancelWritingExit() {
        writingExitResolved = true
        showWritingExit = false
        exitToReading = false; exitToExternal = false
        NotificationCenter.default.post(name:Notification.Name("LumaReader.WritingExitCancelled"),object:nil)
    }

    private func finishWritingExit(discard:Bool) {
        writingExitResolved = true
        showWritingExit = false
        if !vm.finishWritingEdit(discard:discard), vm.storageError == nil {
            // 磁盘写入失败时不再卡住界面：草稿仍保留在内存中，后续自动保存会继续重试
            vm.storageError = "草稿暂时未能写入磁盘，内容仍保留，稍后会自动重试保存。"
        }
        let toExternal = exitToExternal, toReading = exitToReading, destination = writingExitDestination
        exitToExternal = false; exitToReading = false
        // 等面板收起后再切换页面，避免两段动画叠在一起造成卡顿
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if toExternal {
                vm.allowWritingNavigation = true
                NotificationCenter.default.post(name:Notification.Name("LumaReader.WritingExitApproved"),object:nil)
            } else if toReading {
                vm.allowWritingNavigation = false
                NotificationCenter.default.post(name:Notification.Name("LumaReader.ResumeReadingWorkspace"),object:nil,userInfo:["writingExitApproved":true])
            } else {
                vm.allowWritingNavigation = true
                withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9)) { mode = destination }
            }
        }
    }

    private func submitWritingExam(_ submittedDraft: WritingExamDraftState) {
        guard !vm.storeSnapshot.writingSubmissions.contains(where: { $0.draftSessionID == submittedDraft.id }) else { mode = "学习_写作_历史作文"; return }
        let policy = ExamEnglishInputPolicy()
        let p1Words = policy.countIELTSWords(in: submittedDraft.part1EssayText)
        let p2Words = policy.countIELTSWords(in: submittedDraft.part2EssayText)
        let record = WritingSubmissionRecord(
            id: UUID(),
            draftSessionID: submittedDraft.id,
            questionID: submittedDraft.questionID,
            examTitle: submittedDraft.examTitle,
            part1EssayText: submittedDraft.part1EssayText,
            part2EssayText: submittedDraft.part2EssayText,
            part1WordCount: p1Words,
            part2WordCount: p2Words,
            durationSeconds: submittedDraft.elapsedSeconds,
            submittedAt: Date(),
            dateString: Self.todayDateString(),
            aiEvaluation: nil
        )
        let matchedQuestion = resolveExamQuestion(for: record.questionID, examTitle: record.examTitle)
        syncActiveWritingQuestionForAI(question: matchedQuestion, draft: submittedDraft)
        let initialAudit = IELTSOfficialRubricEngine.audit(record: record, question: matchedQuestion)
        var initialRecord = record
        initialRecord.aiEvaluation = initialAudit.deterministicEstimate
        vm.storeDraft(submittedDraft)
        vm.storeSnapshot.writingSubmissions.insert(initialRecord, at: 0)
        vm.save()
        vm.allowWritingNavigation = true
        mode = "学习_写作_评分反馈"

        if let evaluateWriting {
            vm.evaluatingSubmission = initialRecord.id
            Task { @MainActor in
                defer { if vm.evaluatingSubmission == initialRecord.id { vm.evaluatingSubmission = nil } }
                if let rawAI = try? await evaluateWriting(initialRecord, matchedQuestion) {
                    let calibrated = IELTSOfficialRubricEngine.calibrate(aiEstimate: rawAI, with: initialAudit)
                    if let idx = vm.storeSnapshot.writingSubmissions.firstIndex(where: { $0.id == initialRecord.id }) {
                        vm.storeSnapshot.writingSubmissions[idx].aiEvaluation = calibrated
                        vm.save()
                    }
                }
            }
        }
    }

    // MARK: - 1. Listening Shelf, Kokoro Neural Voice Toolbar, Visual-Center Dictation Box & Reaction Latency Pod

    private var dictationModeTitle: String {
        switch vm.dictationMachine.mode {
        case .wrongWordReview: return "错词复习"
        case .stubbornWordReview: return "顽固单词复习"
        case .slowReactionReview: return "⚡ 慢反应词 · 提速巩固"
        default: return "词汇听写"
        }
    }

    private func deckTitle(for id: String) -> String {
        if id.hasPrefix("__mixed_wrong__") { return "多词本错词合练" }
        let baseTitle = vm.fastDeckTitles[id] ?? BundledCoraVocabulary.defaultTitleByDeckID[id] ?? "我的词库"
        if let partCat = BundledCoraVocabulary.defaultCategoryByDeckID[id] {
            return "\(partCat) · \(baseTitle)"
        }
        return baseTitle
    }

    private func wrongWordsForDeck(_ deck: String, dueOnly: Bool = false) -> [VocabularyWord] {
        if deck.hasPrefix("__mixed_wrong__") {
            return String(deck.dropFirst("__mixed_wrong__".count)).components(separatedBy: "\u{1F}")
                .flatMap { wrongWordsForDeck($0, dueOnly: dueOnly) }
        }
        guard visibleListeningDeckIDs.contains(deck) else { return [] }
        let wrongIDs = Set(vm.storeSnapshot.dictationLogs.filter { !$0.isCorrect && $0.deckID == deck }.map(\.wordID))
        return allWords.filter {
            $0.deckID == deck &&
            wrongIDs.contains($0.id) &&
            (!dueOnly || (vm.storeSnapshot.reviewSchedule?[$0.id]?.dueAt ?? .distantPast) <= Date())
        }
    }

    private func openWrongWordReviewPage() {
        if vm.selectedDeck.hasPrefix("__mixed_wrong__") {
            startDictation(mode: .wrongWordReview, resume: true)
            mode = "学习_听力_错词复习"
            return
        }
        ttsEngine.stop(); audio.stop(); kokoro.stop()
        guard !visibleListeningDeckIDs.isEmpty else {
            mode = "学习_听力_错词复习"
            return
        }
        var targetDeck = visibleListeningDeckIDs.contains(vm.selectedDeck) ? vm.selectedDeck : visibleListeningDeckIDs[0]
        if wrongWordsForDeck(targetDeck).isEmpty,
           let deckWithWrongs = visibleListeningDeckIDs.first(where: { !wrongWordsForDeck($0).isEmpty }) {
            targetDeck = deckWithWrongs
        }
        vm.selectedDeck = targetDeck
        if !wrongWordsForDeck(targetDeck).isEmpty {
            selectDeckAndStartDictation(deck: targetDeck, mode: .wrongWordReview, resume: true)
        } else {
            vm.dictationMachine = DictationSessionStateMachine(
                mode: .wrongWordReview,
                dateString: Self.todayDateString(),
                initialWords: [],
                existingStubbornWordsForToday: vm.storeSnapshot.stubbornWords,
                previousLogs: vm.storeSnapshot.dictationLogs
            )
            vm.dictationInput = ""
            vm.showMeaning = false
            vm.revealedWordID = nil
        }
        mode = "学习_听力_错词复习"
    }

    private var dictationDeckBinding: Binding<String> {
        Binding(
            get: { vm.selectedDeck },
            set: { newDeck in
                selectDeckAndStartDictation(deck: newDeck, mode: vm.dictationMachine.mode, resume: true)
            }
        )
    }

    private var dictationVoiceBinding: Binding<KokoroVoiceSlot> {
        Binding(
            get: { kokoro.currentSlot },
            set: { slot in
                kokoro.currentSlot = slot
                if kokoro.useAppleSystemSpeech && vm.selectedAccent != slot.accent {
                    vm.selectedAccent = slot.accent
                } else {
                    speakCurrentWord()
                }
                answerFocused = true
            }
        )
    }

    private func openSpeechSettings() {
        speechSettingsTab = kokoro.useAppleSystemSpeech ? "apple" : "neural"
        Task {
            await kokoro.ensureDaemonRunning()
        }
        vm.speechSettingsShown = true
    }

    private func closeSpeechSettings() {
        kokoro.useAppleSystemSpeech = (speechSettingsTab == "apple")
        if !kokoro.useAppleSystemSpeech && kokoro.isReady {
            if visibleListeningDeckIDs.contains(vm.selectedDeck) {
                kokoro.preload(phrases: Array(vm.dictationMachine.pendingQueue.dropFirst().prefix(3).map(\.word)), startIndex: 0, speed: vm.speechRateMultiplier)
            }
        }
        vm.save()
        vm.speechSettingsShown = false
        speakCurrentWord()
    }

    private var speechSettingsTabs: [StudyTabItem] {
        [
            StudyTabItem(id: "neural", title: "本地模型与声线", symbol: "waveform"),
            StudyTabItem(id: "apple", title: "Apple 语音与服务", symbol: "speaker.wave.2")
        ]
    }

    /// 统一的发音设置弹窗：支持 Kitten、Apple 系统语音与自定义语音服务。
    private var speechSettingsSheet: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("发音设置", systemImage: "gearshape")
                    .lumaFont(size: 20, weight: .medium)
                Spacer()
                Button("完成") { closeSpeechSettings() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 16, height: 32))
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)
            Divider().opacity(0.4)
            Form {
                Picker("设置类别", selection: Binding(get: { speechSettingsTab }, set: { id in
                    speechSettingsTab = id
                    kokoro.useAppleSystemSpeech = (id == "apple")
                    if id == "apple" { kokoro.stop(); kokoro.suspendPreload() }
                    else { Task { await kokoro.ensureDaemonRunning() } }
                })) {
                    ForEach(speechSettingsTabs) { item in Label(item.title, systemImage: item.symbol).tag(item.id) }
                }.pickerStyle(.menu)
            }
            .formStyle(.grouped).scrollContentBackground(.hidden)
            .frame(height: 86)

            Group {
                if speechSettingsTab == "apple" {
                    SpeechSettingsPanel(
                        audio: audio,
                        settings: Binding(
                            get: { vm.storeSnapshot.speechService ?? SpeechServiceSettings() },
                            set: { updated in
                                vm.storeSnapshot.speechService = updated
                                vm.save()
                                if updated.enabled {
                                    Task {
                                        await audio.connect(updated)
                                    }
                                }
                            }
                        ),
                        voiceID: Binding(
                            get: { vm.storeSnapshot.selectedVoiceIdentifier ?? "" },
                            set: {
                                kokoro.useAppleSystemSpeech = true
                                vm.storeSnapshot.selectedVoiceIdentifier = $0
                                vm.save()
                            }
                        ),
                        accent: Binding(
                            get: { vm.selectedAccent },
                            set: { newAccent in
                                kokoro.useAppleSystemSpeech = true
                                if vm.selectedAccent != newAccent {
                                    if let curID = vm.storeSnapshot.selectedVoiceIdentifier, !curID.isEmpty {
                                        let matching = ttsEngine.availableVoices(for: newAccent).filter {
                                            $0.localeIdentifier.lowercased().replacingOccurrences(of: "_", with: "-").hasPrefix(newAccent.rawValue.lowercased())
                                        }
                                        if !matching.contains(where: { $0.id == curID }) {
                                            vm.storeSnapshot.selectedVoiceIdentifier = ""
                                        }
                                    }
                                    vm.selectedAccent = newAccent
                                    vm.save()
                                }
                            }
                        ),
                        rate: Binding(
                            get: { vm.speechRateMultiplier },
                            set: { vm.speechRateMultiplier = $0; vm.save() }
                        ),
                        repeats: Binding(
                            get: { vm.storeSnapshot.speechRepeatCount ?? 1 },
                            set: { vm.storeSnapshot.speechRepeatCount = $0; vm.save() }
                        ),
                        interval: Binding(
                            get: { vm.storeSnapshot.speechInterval ?? 0.5 },
                            set: { vm.storeSnapshot.speechInterval = $0; vm.save() }
                        ),
                        voices: ttsEngine.availableVoices(for: vm.selectedAccent),
                        onClose: {
                            kokoro.useAppleSystemSpeech = true
                            vm.save()
                            vm.speechSettingsShown = false
                            speakCurrentWord()
                        }
                    )
                } else {
                    KokoroVoiceSettingsSheet(
                        kokoro: kokoro,
                        sampleWord: vm.dictationMachine.currentWord?.word ?? "Luma Reader",
                        embedded: true,
                        onClose: { closeSpeechSettings() }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 620, idealWidth: 660, minHeight: 540, idealHeight: 620)
        .background(appearance.background)
        .foregroundStyle(appearance.ink)
        .tint(appearance.accent)
        .environment(\.studyAppearance, appearance)
        .preferredColorScheme(appearance.isDark ? .dark : .light)
    }

    private var dictationToolbar: some View {
        HStack(spacing: 8) {
            Picker("词库", selection: dictationDeckBinding) {
                if vm.selectedDeck.hasPrefix("__mixed_wrong__") {
                    Text("多词本错词合练").tag(vm.selectedDeck)
                }
                ForEach(visibleListeningDeckIDs, id: \.self) { id in
                    Text(deckTitle(for: id)).tag(id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)
            .help("切换词库（自动继续该词库进度）")
            .sheet(isPresented: $vm.mixedWrongSheetShown) { mixedWrongReviewSheet }

            Picker("发音人", selection: dictationVoiceBinding) {
                ForEach(KokoroVoiceSlot.allCases) { slot in
                    Text(kokoro.useAppleSystemSpeech ? slot.displayName : slot.kittenDisplayName).tag(slot)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 106)
            .help("切换当前发音人")

            Picker("语速", selection: $vm.speechRateMultiplier) {
                Text("0.5x").tag(Float(0.5))
                Text("0.75x").tag(Float(0.75))
                Text("0.85x").tag(Float(0.85))
                Text("1.0x").tag(Float(1.0))
                Text("1.15x").tag(Float(1.15))
                Text("1.25x").tag(Float(1.25))
                Text("1.5x").tag(Float(1.5))
                Text("1.8x").tag(Float(1.8))
                Text("2.0x").tag(Float(2.0))
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 84)
            .help("语速（WSOLA 硬件不变调倍速）")

            Button {
                openSpeechSettings()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(kokoro.isReady ? appearance.accent : appearance.ink.opacity(0.38))
                        .frame(width: 7, height: 7)
                    Image(systemName: "slider.horizontal.3")
                }
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 34))
            .help(kokoro.isReady ? "发音设置（Kitten 语音已就绪）" : "发音设置（配置 4 槽位自然发音或语音服务）")
            .accessibilityLabel("发音设置")
            .sheet(isPresented: $vm.speechSettingsShown) {
                speechSettingsSheet
            }

            Menu {
                Button("重新开始本轮", systemImage: "arrow.clockwise") {
                    selectDeckAndStartDictation(deck: vm.selectedDeck, mode: vm.dictationMachine.mode, resume: false)
                }
                Button("错词复习", systemImage: "arrow.counterclockwise") {
                    openWrongWordReviewPage()
                }
                Button("多词本错词合练…", systemImage: "square.stack") {
                    showMixedWrongSelector()
                }
                Button("慢反应词提速 (1.25x)", systemImage: "bolt.badge.clock") {
                    vm.speechRateMultiplier = 1.25
                    selectDeckAndStartDictation(deck: vm.selectedDeck, mode: .slowReactionReview, resume: false)
                }
                Button("停止播放", systemImage: "stop.fill") {
                    ttsEngine.stop(); audio.stop(); kokoro.stop()
                }
                if isImportedDeck(vm.selectedDeck) {
                    Divider()
                    deckActions(vm.selectedDeck)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 34, height: 34)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .studyGlassCapsule(cornerRadius: 17)
            .help("更多词库与听写操作")
        }
    }

    private var dictationProgressLine: String {
        let remaining: Int = vm.dictationMachine.pendingQueue.count
        let done: Int = vm.dictationMachine.completedWordIDs.count
        let today: Int = DictationSessionStateMachine.todayDictatedWordCount(from: vm.storeSnapshot.dictationLogs, on: Self.todayDateString())
        return "已完成 \(done) · 剩余 \(remaining) · 今日 \(today) 词"
    }

    // MARK: - 听写视觉中心大输入框与错误震动/红光脉冲动效

    private var dictationTintColor: Color {
        dictationErrorFlash ? Color.red : appearance.accent
    }

    private var dictationBoxBaseFill: Color {
        if dictationErrorFlash {
            let alpha: Double = appearance.isDark ? 0.18 : 0.11
            return Color.red.opacity(alpha)
        }
        return appearance.paper
    }

    private var dictationGlowGradient: RadialGradient {
        let alpha: Double = dictationErrorFlash ? 0.24 : (answerFocused ? 0.14 : 0.06)
        let colors: [Color] = [dictationTintColor.opacity(alpha), Color.clear]
        return RadialGradient(colors: colors, center: .center, startRadius: 10, endRadius: 290)
    }



    private var dictationInputColor: Color {
        dictationErrorFlash ? Color.red : appearance.ink
    }

    private var dictationBorderColor: Color {
        if dictationErrorFlash { return Color.red }
        return answerFocused ? appearance.accent : appearance.line
    }

    private var dictationBorderWidth: CGFloat {
        if dictationErrorFlash { return 3.0 }
        return answerFocused ? 2.4 : 1.2
    }

    private var dictationShadowColor: Color {
        let alpha: Double = dictationErrorFlash ? 0.30 : (answerFocused ? 0.20 : 0.06)
        return dictationTintColor.opacity(alpha)
    }

    private var dictationShadowRadius: CGFloat {
        dictationErrorFlash ? 20 : 14
    }

    private var dictationScale: CGFloat {
        dictationErrorFlash ? 1.018 : 1.0
    }

    // MARK: - 听写页语义色：跟随当前主题、莫奈取色与玻璃设置
    // 名称保持不变，取值改为 StudyAppearance（由 LibraryStore 的 ReadingPalette 生成，含莫奈）。
    // 选用“暗莓 / 玫瑰”主题时即为原暗莓配色；开启莫奈时随封面 / 壁纸取色变化。
    // 只有暂停用的琥珀色与答错红色是固定的功能色。

    private var dictTheme: StudyAppearance { StudyAppearance.liveOverride ?? appearance }
    private var dictBgColor: Color { dictTheme.paper }
    private var dictCardColor: Color { dictTheme.surface }
    private var dictCapsuleColor: Color { dictTheme.surface }
    private var dictTextPrimary: Color { dictTheme.ink }
    // 深色 68% / 浅色 78%：经典主题下次要文字对纸色与表面色均 ≥ 4.5:1（WCAG AA）。
    private var dictTextMuted: Color { dictTextSecondary }
    private var dictTextSecondary: Color { dictTheme.ink.opacity(dictTheme.isDark ? 0.68 : 0.78) }
    private var dictAccentPink: Color { dictTheme.accent }
    private var dictWrongDotPink: Color { dictTheme.accent.opacity(0.82) }
    private var dictPauseAmber: Color { Color(red: 0xE6/255.0, green: 0xB4/255.0, blue: 0x65/255.0) }
    private var dictPauseFill: Color { dictPauseAmber.opacity(0.18) }
    private var dictTrackFill: Color { dictTheme.accent.opacity(0.20) }
    /// 强调色实底上的文字：按强调色亮度在纸色与墨色之间选，保证对比度。
    private var dictOnAccent: Color {
        let rgb = NSColor(dictTheme.accent).usingColorSpace(.sRGB)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let lum = rgb.map { 0.2126 * lin($0.redComponent) + 0.7152 * lin($0.greenComponent) + 0.0722 * lin($0.blueComponent) } ?? 0.5
        let lightAccent = lum > 0.36
        if dictTheme.isDark { return lightAccent ? dictTheme.paper : dictTheme.ink }
        return lightAccent ? dictTheme.ink : dictTheme.paper
    }
    /// 动态设计是否生效（设置中的“界面风格”，并受减少动态效果约束）。
    private var dictRichMotion: Bool { lumaDynamicMotion && !reduceMotion }

    private static func formatSpeedText(_ rate: Float) -> String {
        if abs(rate - Float(Int(rate))) < 0.01 {
            return String(format: "%.1f×", rate)
        }
        let s = String(format: "%.2f", rate)
        let trimmed = s.hasSuffix("0") ? String(s.dropLast()) : s
        return trimmed + "×"
    }

    private static func formatTimerDigits(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let hrs = clamped / 3600
        let mins = (clamped % 3600) / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    /// 听写页左上角「< 返回」胶囊按钮（保存当前听写进度并返回听力词库主页）
    private var dictationBackButton: some View {
        Button {
            ttsEngine.stop(); audio.stop(); kokoro.stop()
            vm.save()
            mode = "学习_听力"
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("返回")
                    .lumaFont(size: 14.5, weight: .medium)
            }
            .padding(.horizontal, 16)
            .frame(height: LumaControlMetric.backCapsuleHeight)
        }
        .buttonStyle(LumaIconButtonStyle(ink: dictTextPrimary, accent: dictAccentPink,
                                         baseStroke: dictAccentPink.opacity(0.42),
                                         motionEnabled: !reduceMotion))
        // 玻璃材质随设置“液态玻璃效果”开关，色调随主题 / 莫奈。
        .studyGlassCapsule(cornerRadius: LumaControlMetric.backCapsuleHeight / 2)
        .fixedSize()
        .layoutPriority(2)
        .accessibilityIdentifier("study.dictation.back")
        .help("保存进度并返回听力词库主页")
        .accessibilityLabel("返回听力词库")
    }

    /// 顶部右侧三合一功能胶囊（参考书库主页右上角「+  ⋯  ⚙」三键胶囊排版）：
    /// 依次为：「01:44:08 计时暂停键」 │ 「1.5× 倍速键」 │ 「⋯ (ellipsis.circle) 更多功能菜单键」
    private var dictationTopRightCapsules: some View {
        let paused = !listeningDailyTimer.running
        return HStack(spacing: 4) {
            // 1. 计时器按钮：纯等宽数字「01:44:08」，点击暂停变柔和琥珀色，再次点击恢复计时
            Button {
                if listeningDailyTimer.running {
                    listeningDailyTimer.pause()
                } else {
                    listeningDailyTimer.start()
                }
            } label: {
                Text(Self.formatTimerDigits(listeningDailyTimer.seconds))
                    .lumaFont(size: 16, weight: .medium, design: .monospaced)
                    .monospacedDigit()
                    .tracking(1.0)
                    .foregroundStyle(dictTextPrimary)
                    .frame(width: 110, height: 40)
                    .background(
                        Capsule(style: .continuous)
                            .fill(paused ? dictPauseFill : Color.clear)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(paused ? dictPauseAmber : Color.clear, lineWidth: paused ? 1.2 : 0)
                    )
                    .contentShape(Rectangle())
            }
            .help(paused ? "继续听写 · ⌥⌘P" : "暂停听写 · ⌥⌘P")
            .accessibilityLabel("练习计时")

            Rectangle()
                .fill(dictTextPrimary.opacity(0.16))
                .frame(width: 1, height: 18)

            // 2. 倍速按钮：「1.5×」点击弹出 0.5× ~ 2.0× 倍速菜单
            Menu {
                ForEach([Float(0.5), 0.75, 0.85, 1.0, 1.15, 1.25, 1.5, 1.8, 2.0], id: \.self) { spd in
                    Button {
                        vm.speechRateMultiplier = spd
                    } label: {
                        if abs(vm.speechRateMultiplier - spd) < 0.01 {
                            Label(Self.formatSpeedText(spd), systemImage: "checkmark")
                        } else {
                            Text(Self.formatSpeedText(spd))
                        }
                    }
                }
            } label: {
                Text(Self.formatSpeedText(vm.speechRateMultiplier))
                    .lumaFont(size: 16, weight: .semibold, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(dictAccentPink)
                    .frame(width: 64, height: 40)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .help("选择语音播报倍速")
            .contextMenu {
                Button("听写快捷键…") { showListeningShortcuts = true }
            }

            Rectangle()
                .fill(dictTextPrimary.opacity(0.16))
                .frame(width: 1, height: 18)

            // 3. 三个点功能键（参考主页右上角 ellipsis.circle 排版）：统一收纳词库、多本重练、错词、记录、语音与设置
            Button {
                if !dictationMoreShown { dictationSettingsTab = .practice }
                dictationMoreShown.toggle()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(dictTextPrimary.opacity(0.92))
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .help("听写设置")
            .accessibilityLabel("听写设置")
            .accessibilityIdentifier("study.dictation.more")
            .popover(isPresented: $dictationMoreShown, arrowEdge: .top) {
                dictationMorePanel
            }
        }
        .buttonStyle(LumaIconButtonStyle(ink: dictTextPrimary, accent: dictAccentPink, motionEnabled: !reduceMotion))
        .padding(5)
        .studyGlassCapsule(cornerRadius: 25)
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    paused ? dictPauseAmber.opacity(0.75) : dictAccentPink.opacity(0.45),
                    lineWidth: 1.0
                )
        )
        .shadow(color: (paused ? dictPauseAmber : dictAccentPink).opacity(0.14), radius: 8, x: 0, y: 0)
        .sheet(isPresented: $vm.speechSettingsShown) {
            speechSettingsSheet
        }
        .sheet(isPresented: $vm.mixedWrongSheetShown) {
            mixedWrongReviewSheet
        }
    }

    private var dictationMorePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("听写设置").lumaFont(size: 17, weight: .semibold)
                Spacer()
                Button("完成") { dictationMoreShown = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Picker("设置分类", selection: $dictationSettingsTab) {
                ForEach(DictationSettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            Divider().opacity(0.25)
            Form {
                switch dictationSettingsTab {
                case .practice: dictationPracticeSettings
                case .voice: dictationVoiceSettings
                case .more: dictationAdditionalSettings
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 416, height: 390)
        .foregroundStyle(dictTextPrimary)
        .tint(dictAccentPink)
        .background(dictBgColor)
        .environment(\.studyAppearance, appearance)
        .preferredColorScheme(appearance.isDark ? .dark : .light)
        .onChange(of: deckToRename != nil || deckToDelete != nil || deckEditing != nil || showListeningCategoryEditor) { _, editing in
            if editing { dictationMoreShown = false }
        }
    }

    @AppStorage("luma.dictation.newWordStrategy") private var newWordStrategy = NewWordDictationStrategy.quick

    @ViewBuilder
    private var dictationPracticeSettings: some View {
        let rowBg = dictCardColor.opacity(0.84)
        Section("本轮练习") {
            if vm.dictationMachine.mode == .newTask {
                Picker("新词练习模式", selection: $newWordStrategy) {
                    Text("快速过词").tag(NewWordDictationStrategy.quick)
                    Text("循环复习").tag(NewWordDictationStrategy.repeating)
                }
                .pickerStyle(.menu)
                .help("快速过词：错一次就跳过。循环复习：订正后按 5、55、155、255 词间隔复现。")
            }
            Picker("当前词库", selection: dictationDeckBinding) {
                if vm.selectedDeck.hasPrefix("__mixed_wrong__") {
                    Text("多词本错词合练").tag(vm.selectedDeck)
                }
                ForEach(visibleListeningDeckIDs, id: \.self) { id in
                    Text(deckTitle(for: id)).tag(id)
                }
            }
            .pickerStyle(.menu)

            Toggle("显示中文释义", isOn: Binding(
                get: { vm.showMeaning },
                set: { vm.showMeaning = $0; vm.save() }
            ))

            Toggle("显示首字母提示", isOn: $showFirstLetterHint)

            LabeledContent("播报倍速") {
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(vm.speechRateMultiplier) },
                        set: { vm.speechRateMultiplier = Float($0) }
                    ), in: 0.5...2.0, step: 0.05)
                    Text(Self.formatSpeedText(vm.speechRateMultiplier))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .listRowBackground(rowBg)
    }

    @ViewBuilder
    private var dictationVoiceSettings: some View {
        let rowBg = dictCardColor.opacity(0.84)
        Section("语音播放") {
            Picker("发音引擎", selection: $kokoro.useAppleSystemSpeech) {
                Text("本地神经语音（Kitten）").tag(false)
                Text("Apple 系统语音").tag(true)
            }
            .pickerStyle(.menu)

            Picker("当前声线", selection: dictationVoiceBinding) {
                ForEach(KokoroVoiceSlot.allCases) { slot in
                    Text(kokoro.useAppleSystemSpeech ? slot.displayName : slot.kittenDisplayName).tag(slot)
                }
            }
            .pickerStyle(.menu)

            Button("试听当前声线", systemImage: "speaker.wave.2.fill") {
                speakCurrentWord()
            }

            LabeledContent("重复间隔") {
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { vm.storeSnapshot.speechInterval ?? 0.5 },
                        set: { vm.storeSnapshot.speechInterval = $0; vm.save() }
                    ), in: 0.2...2.0, step: 0.1)
                    Text(String(format: "%.1fs", vm.storeSnapshot.speechInterval ?? 0.5))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .listRowBackground(rowBg)

        Section {
            DisclosureGroup("模型与音色") {
                if !kokoro.useAppleSystemSpeech {
                    Picker("本地神经模型", selection: Binding(
                        get: { kokoro.selectedModel },
                        set: { kokoro.switchModel($0) }
                    )) {
                        Text("Kitten Micro · 40M (轻量快速)").tag("kitten-micro")
                        Text("Kitten Nano · 15M (超低内存)").tag("kitten-nano")
                    }
                    .pickerStyle(.menu)
                    .disabled(kokoro.isSwitching)
                }

                if !kokoro.useAppleSystemSpeech {
                    DisclosureGroup("各声线的具体音色") {
                        ForEach(KokoroVoiceSlot.allCases) { slot in
                            Picker(slot.kittenDisplayName, selection: Binding(
                                get: { kokoro.activeSlots[slot] ?? kokoro.defaultVoice(for: slot) },
                                set: { newVoice in
                                    kokoro.selectVoice(newVoice, for: slot)
                                    speakCurrentWord()
                                }
                            )) {
                                ForEach(kokoro.voicesForSlot(slot), id: \.self) { voiceID in
                                    Text(voiceID).tag(voiceID)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                LabeledContent("引擎状态") {
                    Text(kokoro.statusText)
                        .font(.caption)
                        .foregroundStyle(kokoro.isReady ? dictAccentPink : dictTextSecondary)
                }

                if !kokoro.hasBundledModels {
                    Button(role: .destructive) {
                        kokoro.deleteModel(kokoro.selectedModel)
                    } label: {
                        Label("删除当前模型文件 (\(kokoro.modelTitle))", systemImage: "trash")
                    }
                }
            }
        }
        .listRowBackground(rowBg)
    }

    @ViewBuilder
    private var dictationAdditionalSettings: some View {
        let rowBg = dictCardColor.opacity(0.84)
        Section("复习入口") {
            Button("错词复习", systemImage: "arrow.counterclockwise") {
                dictationMoreShown = false
                openWrongWordReviewPage()
            }
            Button("慢反应词提速 (1.25×)", systemImage: "bolt.badge.clock") {
                dictationMoreShown = false
                vm.speechRateMultiplier = 1.25
                selectDeckAndStartDictation(deck: vm.selectedDeck, mode: .slowReactionReview, resume: false)
            }
            Button("顽固单词", systemImage: "exclamationmark.triangle") {
                dictationMoreShown = false
                vm.save()
                mode = "学习_听力_顽固单词"
            }
        }
        .listRowBackground(rowBg)

        Section("学习数据") {
            Button("学习记录", systemImage: "chart.bar.doc.horizontal") {
                dictationMoreShown = false
                vm.save()
                mode = "学习_听力_学习记录"
            }
            Button("同步学习数据到云盘", systemImage: "icloud.and.arrow.up") {
                dictationMoreShown = false
                let count = vm.syncWithConnectedCloudDrives()
                topSyncToast = count > 0 ? "已同步至 \(count) 个云盘" : "已保存本地快照"
            }
        }
        .listRowBackground(rowBg)

        Section("词库操作") {
            Button("多词本错词合练…", systemImage: "square.stack") {
                dictationMoreShown = false
                showMixedWrongSelector()
            }
            Button("重新开始本轮", systemImage: "arrow.clockwise") {
                dictationMoreShown = false
                selectDeckAndStartDictation(deck: vm.selectedDeck, mode: vm.dictationMachine.mode, resume: false)
            }
            if isImportedDeck(vm.selectedDeck) {
                Menu("管理当前词库") {
                    deckActions(vm.selectedDeck)
                }
            }
        }
        .listRowBackground(rowBg)

        Section {
            Button("听写快捷键…", systemImage: "keyboard") {
                dictationMoreShown = false
                DispatchQueue.main.async { showListeningShortcuts = true }
            }
        }
        .listRowBackground(rowBg)
    }

    /// 进度压缩为一行紧凑文字（取代原通栏进度条）；数据与原卡片完全相同：已完成 / 总数、剩余、今日、百分比。
    private func dictationProgressCard(total: Int, todayCount: Int) -> some View {
        let done = vm.dictationMachine.completedWordIDs.count
        let remaining = vm.dictationMachine.pendingQueue.count
        let pct = min(100.0, max(0.0, Double(done) / Double(total) * 100.0))
        let line = "已完成 \(done) / \(total) · 剩余 \(remaining) · 今日 \(todayCount) · " + String(format: "%.1f%%", pct)

        let ratio = min(1.0, max(0.0, Double(done) / Double(total)))

        return HStack(spacing: 6) {
            // 小进度环：两种设计都显示（状态不只靠动效表达）；动态设计下填充以弹簧推进，答对时轻跳一次。
            ZStack {
                Circle().stroke(dictTrackFill, lineWidth: 2.5)
                Circle().trim(from: 0, to: ratio)
                    .stroke(dictAccentPink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 14, height: 14)
            .animation(dictRichMotion ? LumaMotionToken.dynamicMorph : nil, value: ratio)
            // Capture the Bool on the main actor; the Sendable animation callback must not read self.
            .keyframeAnimator(initialValue: CGFloat(1), trigger: dictationSuccessTick) { [richMotion = dictRichMotion] ring, scale in
                ring.scaleEffect(richMotion ? scale : 1)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(1.45, duration: 0.14, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.32, spring: .bouncy)
                }
            }
            .accessibilityHidden(true)

            Text(line)
                .lumaFont(size: 12, weight: .medium, monospacedDigits: true)
                .foregroundStyle(dictTextSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .contentTransition(dictRichMotion ? .numericText(value: Double(done)) : .identity)
                .animation(dictRichMotion ? LumaMotionToken.dynamicState : nil, value: done)
        }
        // 答对（完成数增加，只在提交后发生）时触发一次环形轻跳；“上一个”导致的减少不触发。
        .onChange(of: done) { old, new in
            if new > old, dictRichMotion { dictationSuccessTick += 1 }
        }
        .help(line)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本轮进度")
        .accessibilityValue(line)
    }

    private var dictationLogsNewestFirst: some Sequence<DictationAttemptLog> {
        let batches: [ReversedCollection<[DictationAttemptLog]>] = [
            vm.dictationMachine.attemptLogs.reversed(),
            vm.storeSnapshot.dictationLogs.reversed()
        ]
        return batches.joined()
    }

    /// 收集最近实际出错的最多 5 个英文词汇（未揭晓当前词答案前绝不提前透露当前词）
    private var recentWrongWordStrings: [String] {
        let currentUnrevealedID: String? = {
            guard let cur = vm.dictationMachine.currentWord else { return nil }
            if vm.dictationMachine.requiresCorrection && vm.revealedWordID == cur.id {
                return nil
            }
            return cur.id
        }()
        var seen = Set<String>()
        var result: [String] = []
        let allLogs = dictationLogsNewestFirst
        for log in allLogs where !log.isCorrect {
            if let unrevealed = currentUnrevealedID, log.wordID == unrevealed {
                continue
            }
            let w = log.word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !w.isEmpty else { continue }
            let key = w.lowercased()
            if seen.insert(key).inserted {
                result.append(w)
                if result.count >= 5 { break }
            }
        }
        return result
    }

    private static func measureWrongPillWidth(_ word: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 14.5, weight: .medium)
        let textW = ceil((word as NSString).size(withAttributes: [.font: font]).width)
        return textW + 8 + 8 + 32 + 4
    }

    private func recentWrongPill(_ word: String) -> some View {
        Button {
            speakArbitraryWord(word)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(dictWrongDotPink)
                    .frame(width: 8, height: 8)
                Text(word)
                    .lumaFont(size: 14.5, weight: .medium)
                    .foregroundStyle(dictTextPrimary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 16)
            .frame(height: LumaControlMetric.chipVisualHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(dictCapsuleColor)
            )
            .frame(height: LumaControlMetric.minimumHitHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(StudyFluidPressStyle())
        .fixedSize(horizontal: true, vertical: true)
        .help("播放 \(word)")
        .accessibilityLabel("播放错词 \(word)")
        .transition(dictRichMotion ? .opacity.combined(with: .scale(scale: 0.6, anchor: .leading)) : .identity)
    }

    /// 最近错词行：固定高度（54pt）、永远只有一行，根据当前容器剩余宽度动态测量显示 5 / 3 / 1 个完整胶囊
    private var dictationRecentWrongWordsCard: some View {
        let candidates = recentWrongWordStrings
        return HStack(spacing: 18) {
            Text("最近错词")
                .lumaFont(size: 12, weight: .medium)
                .foregroundStyle(dictTextSecondary)
                .fixedSize()

            GeometryReader { geo in
                let avail = max(0, geo.size.width)
                let fittingWords: [String] = {
                    guard !candidates.isEmpty else { return [] }
                    var chosen: [String] = []
                    var usedWidth: CGFloat = 0
                    let minGap: CGFloat = 12
                    for w in candidates.prefix(5) {
                        let pw = Self.measureWrongPillWidth(w)
                        let nextWidth = chosen.isEmpty ? pw : (usedWidth + minGap + pw)
                        if nextWidth <= avail {
                            chosen.append(w)
                            usedWidth = nextWidth
                        } else {
                            break
                        }
                    }
                    return chosen
                }()

                if candidates.isEmpty {
                    HStack {
                        Text("暂无最近错词记录")
                            .lumaFont(size: 13.5)
                            .foregroundStyle(dictTextSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else if !fittingWords.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(fittingWords.enumerated()), id: \.offset) { idx, w in
                            recentWrongPill(w)
                            if idx < fittingWords.count - 1 {
                                Spacer(minLength: 10)
                            }
                        }
                        if fittingWords.count == 1 {
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else if let firstLong = candidates.first {
                    // 单个超长单词超过容器宽度时：单行水平滚动查看全文，绝不换行或省略截断
                    ScrollView(.horizontal, showsIndicators: false) {
                        recentWrongPill(firstLong)
                            .frame(height: geo.size.height)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .frame(height: LumaControlMetric.minimumHitHeight)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .animation(dictRichMotion ? LumaMotionToken.dynamicChip : nil, value: candidates)
    }

    /// 输入框与底部六按钮之间的一行静态状态文字：
    /// 格式：「word · 第 X 次出错 · 最近反应时间 Y.Ys」，未揭晓答案前绝不提前泄露当前词
    private func dictationStaticStatusLine(currentWord: VocabularyWord) -> String {
        if vm.dictationMachine.requiresCorrection && vm.revealedWordID == currentWord.id {
            let sessionErr = vm.dictationMachine.sessionErrorCounts[currentWord.id, default: 1]
            let historyErr = vm.storeSnapshot.dictationLogs.lazy.filter {
                $0.wordID == currentWord.id && !$0.isCorrect && $0.sessionID != vm.dictationMachine.sessionID
            }.count
            let totalErr = max(1, sessionErr + historyErr)
            let react = vm.dictationMachine.attemptLogs.last(where: { $0.wordID == currentWord.id })?.durationSeconds
                ?? vm.lastSubmittedReactionSeconds
                ?? 2.0
            return String(format: "%@ · 第 %d 次出错 · 最近反应时间 %.1fs", currentWord.word, totalErr, react)
        }
        let allLogs = dictationLogsNewestFirst
        if let wrongLog = allLogs.first(where: { !$0.isCorrect && $0.wordID != currentWord.id }) {
            let totalErr = max(
                1,
                wrongLog.sessionErrorCountForWord,
                vm.storeSnapshot.dictationLogs.lazy.filter { $0.wordID == wrongLog.wordID && !$0.isCorrect }.count
            )
            let react = wrongLog.durationSeconds > 0 ? wrongLog.durationSeconds : (vm.lastSubmittedReactionSeconds ?? 2.0)
            return String(format: "%@ · 第 %d 次出错 · 最近反应时间 %.1fs", wrongLog.word, totalErr, react)
        }
        if let lastCompleted = allLogs.first(where: { $0.wordID != currentWord.id }) {
            let totalErr = vm.storeSnapshot.dictationLogs.lazy.filter { $0.wordID == lastCompleted.wordID && !$0.isCorrect }.count
            let react = lastCompleted.durationSeconds > 0 ? lastCompleted.durationSeconds : (vm.lastSubmittedReactionSeconds ?? 2.0)
            return String(format: "%@ · 第 %d 次出错 · 最近反应时间 %.1fs", lastCompleted.word, totalErr, react)
        }
        return ""
    }

    
    // === PROJECT RED LINE / 项目红线 BEGIN ===
    // 听写进度条（dictationProgressRail）：提供主听写进度通栏、今日听写数、剩余词数与精确百分比。
    // Preserve dictation progress rail, geometry, and real-time statistics.
    // === PROJECT RED LINE / 项目红线 END ===
    private func dictationProgressRail(total: Int, todayCount: Int) -> some View {
        let done = vm.dictationMachine.completedWordIDs.count
        let remaining = vm.dictationMachine.pendingQueue.count
        let ratio = min(1.0, max(0.0, Double(done) / Double(total)))
        let pct = ratio * 100.0
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("听写进度", systemImage: "chart.bar.fill")
                    .lumaFont(size: 12.5, weight: .semibold)
                    .foregroundStyle(dictTextSecondary)
                Spacer(minLength: 8)
                Text("已完成 \(done) / \(total)")
                    .lumaFont(size: 12.5, weight: .medium, monospacedDigits: true)
                    .foregroundStyle(dictTextPrimary)
                    .contentTransition(dictRichMotion ? .numericText(value: Double(done)) : .identity)
                Text(String(format: "%.1f%%", pct))
                    .lumaFont(size: 15, weight: .bold, design: .rounded, monospacedDigits: true)
                    .foregroundStyle(dictAccentPink)
                    .contentTransition(dictRichMotion ? .numericText(value: pct) : .identity)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(dictTrackFill)
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [dictAccentPink.opacity(0.62), dictAccentPink],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * ratio))
                        .shadow(color: dictAccentPink.opacity(0.28), radius: 5, y: 1)
                }
            }
            .frame(height: 8)
            HStack(spacing: 8) {
                Text("剩余 \(remaining) 词")
                Spacer(minLength: 8)
                Text("今日已听写 \(todayCount) 词")
            }
            .lumaFont(size: 10.5, weight: .medium, monospacedDigits: true)
            .foregroundStyle(dictTextSecondary.opacity(0.9))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .studyGlassCapsule(cornerRadius: 16)
        .animation(dictRichMotion ? LumaMotionToken.dynamicMorph : nil, value: ratio)
        .animation(dictRichMotion ? LumaMotionToken.dynamicState : nil, value: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("听写进度")
        .accessibilityValue("已完成 \(done) / \(total)，" + String(format: "%.1f%%", pct))
    }

// === PROJECT RED LINE / 项目红线 BEGIN ===
    // 听写输入框、自适应字号排版，以及摇晃、红闪、红光等错误反馈必须严格保留。
    // Preserve dictation typography, adaptive sizing, shake effect, red flash, and error glow.
    // === PROJECT RED LINE / 项目红线 END ===
    private func dictationAnswerBox(width: CGFloat, minimumHeight: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let borderCol = dictationErrorFlash ? Color.red : dictAccentPink.opacity(answerFocused ? 0.85 : 0.65)
        let text = vm.dictationInput.isEmpty ? "输入听到的英文词汇" : vm.dictationInput
        let availableWidth = max(1, width - 56)
        let scale = min(1, minimumHeight / 260)
        let wrapHeadroom = availableWidth - DictationAnswerMetrics.width(text, size: 36)
        let targetSize = DictationAnswerMetrics.fittedSize(
            text: text, availableWidth: availableWidth,
            ceiling: min(180, max(140, dictationFontCeiling)) * scale
        )
        return ZStack {
            shape.fill(dictBgColor)
            shape.fill(
                RadialGradient(
                    colors: [
                        (dictationErrorFlash ? Color.red : dictAccentPink).opacity(dictTheme.visualThemeSystem == "manga" ? 0 : (dictationErrorFlash ? 0.18 : 0.06)),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 280
                )
            )

            TextField("输入听到的英文词汇", text: $vm.dictationInput,
                      prompt: Text("输入听到的英文词汇").foregroundStyle(dictTextSecondary), axis: .vertical)
                .focused($answerFocused)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .modifier(DictationAnswerFont(size: min(dictationAnswerFontSize, targetSize)))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(dictationErrorFlash ? Color.red : dictTextPrimary)
                .multilineTextAlignment(.center)
                .frame(width: max(1, availableWidth - (dictationAnswerWraps ? 24 : 0)))
                .padding(.horizontal, 28)
                .padding(.vertical, 32 * scale)
                .frame(maxWidth: .infinity, minHeight: minimumHeight)
                .accessibilityIdentifier("study.dictation.answer")
                .disabled(!listeningDailyTimer.running || kokoro.isSwitching)
                .onAppear {
                    if listeningDailyTimer.running && !kokoro.isSwitching { answerFocused = true }
                }
                .onSubmit {
                    submitCurrentDictation()
                }
                .onChange(of: targetSize, initial: true) { _, target in
                    let next = DictationAnswerMetrics.settledSize(current: dictationAnswerFontSize, target: target)
                    guard next != dictationAnswerFontSize else { return }
                    // Never interpolate through an oversized font while shrinking.
                    withAnimation(!reduceMotion && next > dictationAnswerFontSize ? .easeOut(duration: 0.10) : nil) {
                        dictationAnswerFontSize = next
                    }
                }
                .onChange(of: wrapHeadroom, initial: true) { _, headroom in
                    let next = DictationAnswerMetrics.shouldWrap(headroom: headroom, wasWrapped: dictationAnswerWraps)
                    if next != dictationAnswerWraps { withAnimation(nil) { dictationAnswerWraps = next } }
                }
        }
        .frame(width: width)
        .frame(minHeight: minimumHeight)
        .overlay(shape.strokeBorder(borderCol, lineWidth:dictationErrorFlash && dictTheme.visualThemeSystem == "manga" ? 3.5 : (dictationErrorFlash ? 2.4:1.4)))
        .shadow(color:(dictationErrorFlash && dictTheme.visualThemeSystem == "manga" ? Color.black : (dictationErrorFlash ? Color.red:dictAccentPink)).opacity(0.16),
                radius:dictTheme.visualThemeSystem == "manga" ? 0:14,
                x:dictationErrorFlash && dictTheme.visualThemeSystem == "manga" ? 2:0,
                y:dictationErrorFlash && dictTheme.visualThemeSystem == "manga" ? 2:0)
        .overlay(DictationThemeErrorAccent(system:dictTheme.visualThemeSystem,trigger:dictationErrorPulse,active:dictationErrorFlash))
        .modifier(DictationShakeEffect(animatableData:dictTheme.visualThemeSystem == "monet" ? dictationErrorShake:0))
        .modifier(IndependentDictationShakeEffect(animatableData:dictTheme.visualThemeSystem != "monet" && !reduceMotion ? dictationErrorShake:0,system:dictTheme.visualThemeSystem))
        .contentShape(shape)
        .onTapGesture { answerFocused = true }
        .transaction { if reduceMotion { $0.animation = nil } }
    }

    @ViewBuilder private var dictationAnswerHints: some View {
        if let word = vm.dictationMachine.currentWord {
            VStack(spacing: 6) {
                if vm.showMeaning {
                    Text(word.definitionZH.isEmpty ? (BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: word.word) ?? "暂无释义") : word.definitionZH)
                        .lumaFont(size: 18, weight: .medium)
                        .foregroundStyle(dictAccentPink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if showFirstLetterHint {
                    Text(Self.buildFirstLetterHint(for: word.word))
                        .lumaFont(size: 16, weight: .semibold, design: .monospaced)
                        .foregroundStyle(dictAccentPink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if vm.dictationMachine.requiresCorrection {
                    if vm.revealedWordID == word.id {
                        let lastAttempt = vm.dictationMachine.attemptLogs.last { $0.wordID == word.id && !$0.isCorrect }
                        let currentInput = vm.dictationInput
                        let attempt = currentInput.isEmpty ? lastAttempt?.userTyped ?? "" : currentInput
                        let font = Font.system(size: 22, weight: .bold, design: .rounded)
                        if DictationAnswerPolicy.matches(attempt, targetWord: word.word) {
                            Text(word.word)
                                .font(font)
                                .foregroundStyle(dictTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(
                                WordErrorLetterAnalyzer.highlightedAttributedWord(
                                    word.word,
                                    typedAttempts: [attempt],
                                    baseFont: font,
                                    normalColor: dictTextPrimary,
                                    errorColor: .red
                                )
                            )
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Button("查看拼写 (⌘')") { vm.revealedWordID = word.id; vm.save() }
                            .buttonStyle(.plain)
                            .lumaFont(size: 14, weight: .medium)
                            .foregroundStyle(dictAccentPink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(dictCapsuleColor))
                    }
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
    }


    private func dictationControlLabel(title: String, symbol: String, selected: Bool = false,
                                       prominent: Bool = false, disabled: Bool = false) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
            Text(title).font(.system(size: 14, weight: selected || prominent ? .semibold : .medium))
        }
        .foregroundStyle(prominent ? dictBgColor : (selected ? dictAccentPink : (disabled ? dictTextSecondary : dictTextPrimary)))
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(selected ? dictCardColor : Color.clear, in: Capsule())
        .contentShape(Capsule())
    }

    private func dictationControlGroup<Content: View>(prominent: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0, content: content)
            .background(prominent ? dictAccentPink : dictCapsuleColor, in: Capsule())
            .overlay(Capsule().strokeBorder(dictTextSecondary.opacity(0.35), lineWidth: 1))
    }

    private func dictationBottomCapsuleButton(
        title: String, symbol: String, selected: Bool = false,
        prominent: Bool = false, disabled: Bool = false, action: @escaping () -> Void
    ) -> some View {
        dictationControlGroup(prominent: prominent) {
            Button(action: action) {
                dictationControlLabel(title: title, symbol: symbol, selected: selected, prominent: prominent, disabled: disabled)
            }
            .buttonStyle(.plain)
            .disabled(disabled)
        }
        .fixedSize()
    }

    @ViewBuilder private func listeningCenterView(submode: DictationSessionMode) -> some View {
        if vm.fastVisibleBaseDecks.isEmpty && submode != .slowReactionReview {
            VStack(spacing: 14) {
                Image(systemName: "tray.and.arrow.down").font(.system(size: 38, weight: .light)).foregroundStyle(dictAccentPink)
                Text(submode == .wrongWordReview ? "还没有错词" : "还没有词库").font(.title3.weight(.semibold)).foregroundStyle(dictTextPrimary)
                Button("导入词库", systemImage: "square.and.arrow.down") { mode = "学习_听力"; importShown = true }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 16, height: 34))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(dictBgColor)
            .onAppear {
                ttsEngine.stop(); audio.stop(); kokoro.stop()
            }
        } else if submode == .wrongWordReview && wrongWordsForDeck(vm.selectedDeck).isEmpty && (vm.dictationMachine.mode != .wrongWordReview || vm.dictationMachine.currentWord == nil) && vm.dictationMachine.attemptLogs.isEmpty {
            deckManagement(
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center, spacing: 14) {
                        Color.clear.frame(width: 78, height: 1).allowsHitTesting(false)
                        dictationBackButton
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text("错词复习")
                                .lumaFont(size: 28, weight: .semibold)
                                .foregroundStyle(dictTextPrimary)
                            Text("0 / 0")
                                .lumaFont(size: 21, weight: .regular, design: .rounded)
                                .monospacedDigit()
                                .foregroundStyle(dictTextSecondary)
                        }
                        Spacer(minLength: 12)
                        dictationTopRightCapsules
                    }
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal").font(.system(size: 38, weight: .light)).foregroundStyle(dictAccentPink)
                        Text("当前词库还没有错词").font(.title3.weight(.semibold)).foregroundStyle(dictTextPrimary)
                        Button("去听写本词库", systemImage: "headphones") {
                            selectDeckAndStartDictation(deck: vm.selectedDeck, mode: .newTask, resume: true)
                            mode = "学习_听力_今日计划"
                        }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 16, height: 34))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .studyPagePadding()
                .background(dictBgColor)
            )
            .onAppear {
                ttsEngine.stop(); audio.stop(); kokoro.stop()
            }
        } else {
            listeningCenterContent(submode: submode)
                .onAppear {
                    if !vm.selectedDeck.hasPrefix("__mixed_wrong__"), !vm.fastVisibleBaseDecks.contains(vm.selectedDeck), let first = visibleListeningDeckIDs.first {
                        if submode == .wrongWordReview && wrongWordsForDeck(first).isEmpty {
                            vm.selectedDeck = first
                        } else {
                            selectDeckAndStartDictation(deck: first, mode: submode, resume: true)
                        }
                    }
                }
        }
    }

    private func dictationInlineButton(
        title: String, symbol: String, selected: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { dictationControlLabel(title: title, symbol: symbol, selected: selected) }
            .buttonStyle(.plain)
            .fixedSize()
    }

    /// 头部两行：①左侧安全留白（避开红绿灯）+ 返回 + 标题/紧凑进度 + 计时·倍速·更多胶囊；②最近错词。
    private func dictationPracticeHeader(total: Int, todayCount: Int) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Color.clear.frame(width: 72, height: 1).allowsHitTesting(false)
                dictationBackButton
                VStack(alignment: .leading, spacing: 2) {
                    Text(dictationModeTitle)
                        .lumaFont(size: 16, weight: .semibold)
                        .foregroundStyle(dictTextPrimary)
                        .lineLimit(1)
                    dictationProgressCard(total: total, todayCount: todayCount)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                dictationTopRightCapsules
            }
            dictationRecentWrongWordsCard
                .padding(.leading, 84)
        }
        .modifier(DictationHeaderEntrance(enabled: dictRichMotion))
    }

    private var dictationPracticeStatus: some View {
        VStack(spacing: 10) {
            dictationAnswerHints
            if let word = vm.dictationMachine.currentWord {
                Text(dictationStaticStatusLine(currentWord: word))
                    .lumaFont(size: 12.5).monospacedDigit()
                    .foregroundStyle(dictTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 20)
            }
        }
    }

    private func dictationPracticeActions(availableWidth: CGFloat) -> some View {
        // One unified action area: the same six native Buttons, actions, shortcuts,
        // disabled conditions and Tab order. Secondary actions are icon-only with help text.
        let compact = availableWidth < LumaControlMetric.actionBarCompactThreshold
        let layout = compact
            ? AnyLayout(VStackLayout(spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            HStack(spacing: 2) {
                dictationIconAction(
                    symbol: "backward.end.fill",
                    label: "上一个",
                    help: "上一个词",
                    disabled: previousDictationWord == nil || vm.dictationMachine.requiresCorrection
                ) {
                    revisitPreviousWord()
                }

                dictationActionDivider

                dictationIconAction(
                    symbol: kokoro.isPreparingAudio ? "hourglass" : "speaker.wave.2.fill",
                    label: "重播",
                    help: kokoro.isPreparingAudio ? "语音准备中… · ⌘R" : "重播 · ⌘R",
                    value: kokoro.isPreparingAudio ? "准备中" : "",
                    busy: kokoro.isPreparingAudio
                ) {
                    replayCurrentWord()
                }

                dictationIconAction(
                    symbol: "tortoise.fill",
                    label: "慢放",
                    help: "慢放 0.75× · ⇧⌘R"
                ) {
                    replayCurrentWord(overrideRate: 0.75)
                }

                dictationActionDivider

                dictationIconAction(
                    symbol: "character.bubble",
                    label: vm.showMeaning ? "隐藏中文" : "显示中文",
                    help: (vm.showMeaning ? "隐藏中文" : "显示中文") + " · ⌥⌘M",
                    selected: vm.showMeaning
                ) {
                    vm.showMeaning.toggle()
                    vm.save()
                }

                dictationIconAction(
                    symbol: "lightbulb",
                    label: showFirstLetterHint ? "隐藏提示" : "首字母提示",
                    help: (showFirstLetterHint ? "隐藏提示" : "首字母提示") + " · ⌘/",
                    selected: showFirstLetterHint
                ) {
                    showFirstLetterHint.toggle()
                }
            }

            Button {
                submitCurrentDictation()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "return").font(.system(size: 14, weight: .semibold))
                    Text("提交").lumaFont(size: 14.5, weight: .semibold)
                }
                .padding(.horizontal, 20)
                .frame(minWidth: 96)
                .frame(height: LumaControlMetric.actionHeight)
            }
            .buttonStyle(LumaIconButtonStyle(ink: dictTextPrimary, accent: dictAccentPink, emphasis: .prominent,
                                             onAccent: dictOnAccent, motionEnabled: !reduceMotion))
            .disabled(!listeningDailyTimer.running || kokoro.isSwitching)
            .help("提交答案 · 回车")
            .accessibilityLabel("提交")
        }
        .padding(LumaControlMetric.actionBarPadding)
        .studyGlassCapsule(cornerRadius: compact ? LumaControlMetric.actionBarCompactRadius : LumaControlMetric.actionBarRadius)
        .overlay(
            RoundedRectangle(cornerRadius: compact ? LumaControlMetric.actionBarCompactRadius : LumaControlMetric.actionBarRadius,
                             style: .continuous)
                .strokeBorder(dictTextSecondary.opacity(0.22), lineWidth: 1)
        )
        .fixedSize()
        .frame(maxWidth: .infinity)
    }

    private var dictationActionDivider: some View {
        Rectangle()
            .fill(dictTextPrimary.opacity(0.14))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
    }

    /// 底部操作区的 44×44 图标按钮：开关类按选中切换 outline → fill，且同时改变颜色与底色。
    private func dictationIconAction(
        symbol: String, label: String, help: String, value: String = "",
        selected: Bool = false, disabled: Bool = false, busy: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: LumaControlMetric.actionIconPointSize, weight: .semibold))
                .symbolVariant(selected ? .fill : .none)
                .contentTransition(dictRichMotion ? .symbolEffect(.replace) : .identity)
                // 动态：语音准备期间沙漏旋转（准备结束即停止）；静态：只显示沙漏图标。
                .symbolEffect(.rotate, isActive: busy && dictRichMotion)
                .frame(width: LumaControlMetric.actionHeight, height: LumaControlMetric.actionHeight)
        }
        .buttonStyle(LumaIconButtonStyle(ink: dictTextPrimary, accent: dictAccentPink,
                                         emphasis: selected ? .selected : .plain,
                                         motionEnabled: !reduceMotion))
        .disabled(disabled)
        .help(help)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @State private var actionBarHeight: CGFloat = 0

    private func listeningCenterContent(submode: DictationSessionMode) -> some View {
        deckManagement(
            GeometryReader { viewport in
                let contentWidth = max(1, viewport.size.width - 48)
                // Keep the original broad card. Short windows scroll the practice canvas
                // instead of using the window height to shrink the input sideways.
                let answerScale = contentWidth / 940
                let answerWidth = 916 * answerScale
                let answerHeight = 260 * answerScale
                let total = max(1, dictationTotalWords)
                let todayCount = DictationSessionStateMachine.todayDictatedWordCount(
                    from: vm.storeSnapshot.dictationLogs, on: Self.todayDateString()
                )
                VStack(spacing: 0) {
                    ScrollView(.vertical) {
                        if vm.dictationMachine.currentWord != nil {
                            DictationPracticeLayout(minimumHeight: max(0, viewport.size.height - 32 - actionBarHeight)) {
                                dictationPracticeHeader(total: total, todayCount: todayCount)
                                dictationProgressRail(total: total, todayCount: todayCount)
                                dictationAnswerBox(width: answerWidth, minimumHeight: answerHeight)
                                dictationPracticeStatus
                            }
                            .frame(width: contentWidth)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        } else {
                            VStack(spacing: 20) {
                                dictationPracticeHeader(total: total, todayCount: todayCount)
                                dictationSummaryView
                            }
                            .padding(24)
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    // 返回胶囊随画布滚动；对齐目标按静止位置计算，红黄绿不跟随滚动漂移。
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    } action: { _, offset in
                        if abs(dictationScrollOffsetY - offset) > 0.5 { dictationScrollOffsetY = offset }
                    }
                    if vm.dictationMachine.currentWord != nil {
                        dictationPracticeActions(availableWidth: contentWidth)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                actionBarHeight = height
                            }
                    }
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(dictTheme.background.ignoresSafeArea())
            .alert("听写快捷键", isPresented: $showListeningShortcuts) {
                Button("好", role: .cancel) {}
            } message: { Text(DictationShortcutPolicy.helpText) }
            .background(
                StudyKeyboardEventMonitor { event in
                    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    // Preserve single-line Return semantics with a vertical native field.
                    // Local AppKit monitoring also covers bridged text controls. Never
                    // consume IME confirmation, another window's input, or a sheet.
                    if (event.keyCode == 36 || event.keyCode == 76),
                       flags.intersection([.command, .option, .control, .shift]).isEmpty,
                       answerFocused, !dictationMoreShown,
                       event.window?.isKeyWindow == true, event.window?.isMainWindow == true,
                       event.window?.attachedSheet == nil,
                       let editor = event.window?.firstResponder as? NSTextView,
                       !editor.hasMarkedText(), listeningDailyTimer.running, !kokoro.isSwitching {
                        if !event.isARepeat { submitCurrentDictation(editorText: editor.string) }
                        return true
                    }
                    // 1.12.2: 切到后台计时会自动暂停；回来后单按空格即可继续计时（不用再点按钮）。
                    if event.keyCode == 49, flags.intersection([.command, .option, .control, .shift]).isEmpty,
                       !listeningDailyTimer.running, !event.isARepeat,
                       mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习",
                       event.window?.isKeyWindow == true, event.window?.isMainWindow == true,
                       event.window?.attachedSheet == nil, !dictationMoreShown, !showListeningShortcuts,
                       vm.dictationMachine.currentWord != nil, !kokoro.isSwitching {
                        listeningDailyTimer.start()
                        return true
                    }
                    guard event.window?.isKeyWindow == true, event.window?.isMainWindow == true,
                          event.window?.attachedSheet == nil, !dictationMoreShown, !showListeningShortcuts,
                          vm.dictationMachine.currentWord != nil, !event.isARepeat else { return false }
                    if let editor = event.window?.firstResponder as? NSTextView,
                       editor.hasMarkedText() || (editor.isEditable && !answerFocused && listeningDailyTimer.running) { return false }
                    var modifiers: UInt8 = 0
                    if flags.contains(.command) { modifiers |= DictationShortcutPolicy.command }
                    if flags.contains(.option) { modifiers |= DictationShortcutPolicy.option }
                    if flags.contains(.shift) { modifiers |= DictationShortcutPolicy.shift }
                    if flags.contains(.control) { modifiers |= DictationShortcutPolicy.control }
                    guard let action = DictationShortcutPolicy.action(keyCode: event.keyCode,
                        characters: event.charactersIgnoringModifiers ?? "", modifiers: modifiers) else { return false }
                    switch action {
                    case .replay: replayCurrentWord()
                    case .slowReplay: replayCurrentWord(overrideRate: 0.75)
                    case .togglePause:
                        if listeningDailyTimer.running { listeningDailyTimer.pause() } else { listeningDailyTimer.start() }
                    case .toggleMeaning: vm.showMeaning.toggle(); vm.save()
                    case .toggleHint: showFirstLetterHint.toggle()
                    case .previous: revisitPreviousWord()
                    case .revealAnswer:
                        guard vm.dictationMachine.requiresCorrection, let word = vm.dictationMachine.currentWord else { return false }
                        vm.revealedWordID = word.id; vm.save()
                    case .help: showListeningShortcuts = true
                    }
                    return true
                }
            )
        )
    }

    private static func buildFirstLetterHint(for word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        if trimmed.count <= 2 {
            return "首字母提示：\(first) _ (共 \(trimmed.count) 个字母)"
        }
        let last = trimmed.last!
        let middle = Array(repeating: "_", count: max(1, trimmed.count - 2)).joined(separator: " ")
        return "首字母提示：\(first) \(middle) \(last) (共 \(trimmed.count) 个字母)"
    }

    // MARK: - Wrong Words Center

    private func wrongWordsCenterModel() -> WrongWordsCenterModel {
        let now = Date()
        let today = Self.todayDateString()
        let slowRecords = vm.storeSnapshot.slowReactionWords ?? []
        var slowByID: [String: SlowReactionWordRecord] = [:]
        for record in slowRecords { slowByID[record.wordID] = record }
        let stubbornIDs = Set(vm.storeSnapshot.stubbornWords.map(\.wordID))
        let stubbornToday = Set(vm.storeSnapshot.stubbornWords.filter { $0.dateString == today }.map(\.wordID))
        let logs = vm.storeSnapshot.dictationLogs
        let errorLogs = logs.filter { !$0.isCorrect }
        let errorsByID = Dictionary(grouping:errorLogs, by: \.wordID)
        var latestLogByWord: [String: DictationAttemptLog] = [:]
        for log in logs { latestLogByWord[log.wordID] = log }
        func mastery(for wordID: String) -> WrongWordMastery {
            let progress = vm.storeSnapshot.reviewSchedule?[wordID]
            if (progress?.stage ?? 0) >= 3 { return .mastered }
            if (progress?.stage ?? 0) > 0 || progress?.lastReviewedAt != nil { return .reviewing }
            return .fresh
        }
        var groups: [WrongWordDeckGroup] = []
        for deck in visibleListeningDeckIDs {
            let words = wrongWordsForDeck(deck)
            guard !words.isEmpty else { continue }
            let entries = words.map { word -> WrongWordEntry in
                let progress = vm.storeSnapshot.reviewSchedule?[word.id]
                let dueAt = progress?.dueAt
                let isDue = (dueAt ?? .distantPast) <= now && !stubbornToday.contains(word.id)
                let latest = latestLogByWord[word.id]
                let reaction: Double? = slowByID[word.id]?.lastReactionSeconds
                    ?? ((latest?.durationSeconds ?? 0) > 0 ? latest?.durationSeconds : nil)
                return WrongWordEntry(
                    wordID: word.id,
                    word: word.word,
                    meaning: word.definitionZH,
                    deckID: word.deckID,
                    deckTitle: word.deckTitle,
                    errorCount: errorsByID[word.id]?.count ?? 0,
                    dueAt: dueAt,
                    lastReactionSeconds: reaction,
                    isDue: isDue,
                    isSlowReaction: slowByID[word.id] != nil,
                    isStubborn: stubbornIDs.contains(word.id),
                    lastAttemptAt: latest?.timestamp,
                    mastery: mastery(for: word.id)
                )
            }.sorted {
                if $0.isDue != $1.isDue { return $0.isDue }
                if $0.errorCount != $1.errorCount { return $0.errorCount > $1.errorCount }
                return $0.word.localizedStandardCompare($1.word) == .orderedAscending
            }
            groups.append(WrongWordDeckGroup(deckID: deck, title: deckTitle(for: deck), entries: entries))
        }
        groups.sort {
            if $0.dueCount != $1.dueCount { return $0.dueCount > $1.dueCount }
            if $0.totalErrors != $1.totalErrors { return $0.totalErrors > $1.totalErrors }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        let entries = groups.flatMap(\.entries)
        var diagnosisMap: [String: [String]] = [:]
        for entry in entries {
            if let hint = WordErrorLetterAnalyzer.diagnoseSpellingPattern(
                targetWord: entry.word,
                typedAttempts: (errorsByID[entry.wordID] ?? []).map(\.userTyped)
            ), !hint.isEmpty {
                diagnosisMap[hint, default: []].append(entry.wordID)
            }
        }
        var diagnoses: [WrongWordDiagnosis] = []
        for (label, ids) in diagnosisMap {
            diagnoses.append(WrongWordDiagnosis(label: label, count: ids.count, wordIDs: ids))
        }
        diagnoses.sort { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.label < rhs.label
        }
        let reviewed = entries.reduce(into: 0) { count, entry in
            if entry.mastery != .fresh { count += 1 }
        }
        let mastered = entries.reduce(into: 0) { count, entry in
            if entry.mastery == .mastered { count += 1 }
        }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "M/d"
        var dayMap: [String: (attempts: Int, correct: Int, errors: Int)] = [:]
        for log in logs {
            var value = dayMap[log.dateString] ?? (0, 0, 0)
            value.attempts += 1
            if log.isCorrect { value.correct += 1 } else { value.errors += 1 }
            dayMap[log.dateString] = value
        }
        var days: [WrongWordDayPoint] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let key = formatter.string(from: day)
            let value = dayMap[key] ?? (0, 0, 0)
            days.append(WrongWordDayPoint(key: key, label: labelFormatter.string(from: day),
                                          attempts: value.attempts, correct: value.correct, errors: value.errors))
        }
        let weekAttempts = days.reduce(0) { $0 + $1.attempts }
        let weekCorrect = days.reduce(0) { $0 + $1.correct }
        let weekErrors = days.reduce(0) { $0 + $1.errors }
        let accuracy = weekAttempts == 0 ? 0 : Double(weekCorrect) / Double(weekAttempts)
        let records = logs.suffix(300).reversed().map { log in
            WrongWordPracticeRecord(
                id: log.id,
                word: log.word,
                typed: log.userTyped,
                isCorrect: log.isCorrect,
                date: log.timestamp,
                durationSeconds: log.durationSeconds,
                deckTitle: deckTitle(for: log.deckID),
                isSlowReaction: log.isSlowReaction
            )
        }
        return WrongWordsCenterModel(
            groups: groups,
            totalWords: entries.count,
            dueWords: entries.reduce(0) { $0 + ($1.isDue ? 1 : 0) },
            totalErrors: errorLogs.count,
            todayErrors: errorLogs.filter { $0.dateString == today }.count,
            slowCount: slowRecords.count,
            stubbornCount: stubbornIDs.count,
            reviewedWords: reviewed,
            masteredCount: mastered,
            records: records,
            days: days,
            last7Accuracy: accuracy,
            last7Errors: weekErrors,
            diagnoses: diagnoses
        )
    }

    private var wrongWordsCenterPage: some View {
        let model = wrongWordsCenterModel()
        return WrongWordsCenterView(
            model: model,
            onStartDue: { deck in
                vm.selectedDeck = deck
                selectDeckAndStartDictation(deck: deck, mode: .wrongWordReview, resume: true, dueOnly: true)
                mode = "学习_听力_错词复习"
            },
            onStartAll: { deck in
                vm.selectedDeck = deck
                selectDeckAndStartDictation(deck: deck, mode: .wrongWordReview, resume: true, dueOnly: false)
                mode = "学习_听力_错词复习"
            },
            onStartSlow: { mode = "学习_听力_慢反应词" },
            onStartStubborn: { mode = "学习_听力_顽固单词" },
            onStartMixed: { showMixedWrongSelector() },
            onRemoveSlow: { wordID in
                vm.storeSnapshot.slowReactionWords?.removeAll { $0.wordID == wordID }
                vm.save()
            },
            onSpeak: { speakArbitraryWord($0) },
            onGoToDictation: { mode = "学习_听力" },
            onExportRecords: { exportWrongWordsRecordsTXT() },
            onStartTodayQueue: { startTodayWrongQueue() },
            onStartDueQueue: {
                startWrongWordDrill(model.allEntries.filter(\.isDue).map(\.wordID), sessionDeckKey: "__listening_due_queue__")
            },
            onStartAllWrongWords: { startAllWrongWordsDictation() },
            onStartMicroDrill: { ids in startWrongWordDrill(ids) }
        )
    }

    private func startTodayWrongQueue() {
        var seen = Set<String>()
        var words: [VocabularyWord] = []
        func append(_ word: VocabularyWord) {
            if seen.insert(word.id).inserted { words.append(word) }
        }
        for deck in visibleListeningDeckIDs {
            for word in wrongWordsForDeck(deck, dueOnly: true) { append(word) }
        }
        let stubbornIDs = Set(vm.storeSnapshot.stubbornWords.map(\.wordID))
        let slowIDs = Set((vm.storeSnapshot.slowReactionWords ?? []).map(\.wordID))
        for word in vm.fastAllWords where stubbornIDs.contains(word.id) || slowIDs.contains(word.id) {
            append(word)
        }
        guard !words.isEmpty else { return }
        startWrongWordDrill(words)
    }

    /// 1.9.4: one explicit entry that puts every wrong word (all decks) into a
    /// separate looping review session.
    private func startAllWrongWordsDictation() {
        var seen = Set<String>()
        var words: [VocabularyWord] = []
        for deck in visibleListeningDeckIDs {
            for w in wrongWordsForDeck(deck, dueOnly: false) where seen.insert(w.id).inserted {
                words.append(w)
            }
        }
        startWrongWordDrill(words)
    }

    private func startWrongWordDrill(_ ids: [String], sessionDeckKey: String? = nil) {
        let set = Set(ids)
        let words = vm.fastAllWords.filter { set.contains($0.id) }
        guard !words.isEmpty else { return }
        startWrongWordDrill(words, sessionDeckKey: sessionDeckKey)
    }

    private func startWrongWordDrill(_ words: [VocabularyWord], sessionDeckKey: String? = nil) {
        guard !words.isEmpty else { return }
        ttsEngine.stop(); audio.stop(); kokoro.stop()
        vm.save()
        vm.selectedDeck = words.first?.deckID ?? vm.selectedDeck
        vm.activeDictationDeckKey = sessionDeckKey ?? vm.selectedDeck
        vm.dictationMachine = DictationSessionStateMachine(
            mode: .wrongWordReview,
            dateString: Self.todayDateString(),
            initialWords: words,
            existingStubbornWordsForToday: vm.storeSnapshot.stubbornWords,
            previousLogs: vm.storeSnapshot.dictationLogs
        )
        vm.dictationInput = ""
        vm.showMeaning = false
        vm.revealedWordID = nil
        showFirstLetterHint = false
        mode = "学习_听力_错词复习"
        vm.save()
        speakCurrentWord()
    }

    private func exportWrongWordsRecordsTXT() {
        let logs = vm.storeSnapshot.dictationLogs
        guard !logs.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "LumaReader-PracticeRecords-\(Self.todayDateString()).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var text = "Luma Reader 练习记录\n导出时间：\(timeFormatter.string(from: Date()))\n\n"
        for log in logs.reversed() {
            let result = log.isCorrect ? "正确" : "错误"
            text += "\(log.dateString)\t\(log.word)\t输入：\(log.userTyped)\t\(result)\t反应：\(String(format: "%.1f", log.durationSeconds))s\t\(deckTitle(for: log.deckID))\n"
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private var slowReactionWordsDedicatedView: some View {
        let slowRecords = (vm.storeSnapshot.slowReactionWords ?? []).sorted { $0.lastReactionSeconds > $1.lastReactionSeconds }
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("慢反应词 · 提速巩固")
                        .lumaFont(size: 30, weight: .bold, design: .serif)
                        .foregroundStyle(appearance.ink)
                }
                Spacer()
                if !slowRecords.isEmpty {
                    Button("⚡ 1.25x 倍速巩固全部 (\(slowRecords.count))") {
                        vm.speechRateMultiplier = 1.25
                        startSlowReactionDictation(records: slowRecords)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 16, height: 34))

                    Button("🔥 1.5x 极限真题语速突击") {
                        vm.speechRateMultiplier = 1.5
                        startSlowReactionDictation(records: slowRecords)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
                }
            }

            if slowRecords.isEmpty {
                Text("暂无慢反应词记录。")
                    .lumaFont(size: 14)
                    .foregroundStyle(appearance.ink.opacity(0.6))
                    .padding(.top, 20)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(slowRecords) { rec in
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 10) {
                                        Text(rec.word)
                                            .lumaFont(size: 18, weight: .bold, design: .serif)
                                            .foregroundStyle(appearance.ink)
                                        Text(rec.definitionZH.isEmpty ? (BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: rec.word) ?? "") : rec.definitionZH)
                                            .lumaFont(size: 13.5)
                                            .foregroundStyle(appearance.accent)
                                    }
                                    Text("所属词库：\(rec.sourceDeckTitle) · 最近记录：\(rec.dateString) · 累计犹豫超时 \(rec.slowCount) 次")
                                        .lumaFont(size: 12)
                                        .foregroundStyle(appearance.ink.opacity(0.65))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "反应耗时 %.1f 秒", rec.lastReactionSeconds))
                                        .lumaFont(size: 13, weight: .bold, monospacedDigits: true)
                                        .foregroundStyle(appearance.accent)
                                    if let best = rec.bestReactionSeconds {
                                        Text(String(format: "历史最快 %.1f 秒", best))
                                            .lumaFont(size: 11, monospacedDigits: true)
                                            .foregroundStyle(best <= 3.5 ? appearance.accent : appearance.ink.opacity(0.55))
                                    }
                                }
                                Button("1.25x 巩固") {
                                    vm.speechRateMultiplier = 1.25
                                    startSlowReactionDictation(records: [rec])
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                                Button("已提速达标 · 移出") {
                                    vm.storeSnapshot.slowReactionWords?.removeAll { $0.wordID == rec.wordID }
                                    vm.save()
                                }
                                .font(.caption)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(appearance.surface))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(appearance.background)
    }

    private func startSlowReactionDictation(records: [SlowReactionWordRecord]) {
        let words: [VocabularyWord] = records.map { rec in
            if let existing = allWords.first(where: { $0.id == rec.wordID }) {
                return existing
            }
            return VocabularyWord(
                id: rec.wordID,
                word: rec.word,
                definitionZH: rec.definitionZH.isEmpty ? (BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: rec.word) ?? "慢反应提速词") : rec.definitionZH,
                deckID: rec.sourceDeckID,
                deckTitle: rec.sourceDeckTitle
            )
        }
        guard !words.isEmpty else { return }
        vm.dictationMachine = DictationSessionStateMachine(
            mode: .slowReactionReview,
            dateString: Self.todayDateString(),
            initialWords: words,
            existingStubbornWordsForToday: vm.storeSnapshot.stubbornWords,
            previousLogs: vm.storeSnapshot.dictationLogs
        )
        vm.showMeaning = false
        vm.revealedWordID = nil
        showFirstLetterHint = false
        vm.dictationInput = ""
        vm.save()
        mode = "学习_听力_今日计划"
        speakCurrentWord()
    }

    private var builtInDictionariesDedicatedView: some View {
        let matchedWords = BuiltInIELTSDictionaryEngine.search(query: dictSearchQuery, inBookID: selectedDictionaryBookID)
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("内置权威雅思词典中心")
                        .lumaFont(size: 30, weight: .bold, design: .serif)
                        .foregroundStyle(appearance.ink)
                    Text("集合《雅思学术核心 300 词与替换词典》《听力四大场景必考词典》《AWL 学术核心词典》《高分固定搭配词典》；上传词单时支持自动识别英文并匹配词典释义（默认优先使用文件自带中文翻译）。")
                        .lumaFont(size: 13)
                        .foregroundStyle(appearance.ink.opacity(0.7))
                }
                Spacer()
                TextField("在内置词典中查词（支持中英文与词形还原）", text: $dictSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(BuiltInIELTSDictionaryEngine.allDictionaries) { book in
                    let isSelectedBook = (selectedDictionaryBookID == book.id)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: book.iconName)
                                .font(.title2)
                                .foregroundStyle(appearance.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .lumaFont(size: 16, weight: .bold, design: .serif)
                                    .foregroundStyle(appearance.ink)
                                Text("\(book.words.count) 个核心词条 · \(book.categoryTag)")
                                    .font(.caption)
                                    .foregroundStyle(appearance.accent)
                            }
                            Spacer()
                            Button(isSelectedBook ? "显示全部词典" : "浏览本词典") {
                                selectedDictionaryBookID = isSelectedBook ? nil : book.id
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(selected: isSelectedBook, horizontalPadding: 12, height: 28))
                        }
                        Text(book.subtitle)
                            .lumaFont(size: 12.5)
                            .foregroundStyle(appearance.ink.opacity(0.72))
                            .lineLimit(2)
                        HStack(spacing: 10) {
                            Button("🎧 直接听写本词典") {
                                _ = saveImportedWords(book.words)
                                selectDeckAndStartDictation(deck: book.id, mode: .newTask, resume: true)
                                mode = "学习_听力_今日计划"
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 30))

                            Button("📥 加入我的听写词库") {
                                _ = saveImportedWords(book.words)
                                cloudSyncBannerText = "已将《\(book.title)》（共 \(book.words.count) 词）加入听写词库！"
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelectedBook ? appearance.selected : appearance.surface)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelectedBook ? appearance.accent : appearance.line, lineWidth: 1))
                    )
                }
            }

            if let cloudSyncBannerText {
                Text(cloudSyncBannerText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.accent)
            }

            Text("词典词条检索预览（共 \(matchedWords.count) 条匹配，点击发音可试听，点击「+ 生词本」可加入个人听写本）")
                .font(.caption.bold())
                .foregroundStyle(appearance.ink.opacity(0.75))

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(matchedWords.prefix(120)) { item in
                        HStack(spacing: 12) {
                            Text(item.word)
                                .lumaFont(size: 15, weight: .bold, design: .serif)
                                .foregroundStyle(appearance.ink)
                                .frame(minWidth: 160, alignment: .leading)
                            Text(item.definitionZH)
                                .lumaFont(size: 13.5)
                                .foregroundStyle(appearance.accent)
                            if !item.exampleSentence.isEmpty {
                                Text(item.exampleSentence)
                                    .font(.caption)
                                    .foregroundStyle(appearance.ink.opacity(0.62))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                speakArbitraryWord(item.word)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                            }
                            .buttonStyle(.borderless)
                            .help("朗读此词条")

                            Button("+ 生词本") {
                                let accumWord = VocabularyWord(
                                    id: "dict_pick_\(item.id)",
                                    word: item.word,
                                    definitionZH: item.definitionZH,
                                    exampleSentence: item.exampleSentence,
                                    deckID: "vocab_writing_accumulations",
                                    deckTitle: "写作错词与高分搭配本"
                                )
                                _ = saveImportedWords([accumWord])
                                cloudSyncBannerText = "已将「\(item.word)」加入《写作错词与高分搭配本》！"
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                    }
                }
            }
        }
        .padding(32)
        .background(appearance.background)
    }

    private func speakArbitraryWord(_ text: String) {
        if !kokoro.useAppleSystemSpeech && kokoro.isReady {
            ttsEngine.stop()
            audio.stop()
            _ = kokoro.play(text: text, speed: vm.speechRateMultiplier, repeats: 1, interval: 0.5)
            return
        }
        let service = vm.storeSnapshot.speechService ?? SpeechServiceSettings()
        if service.enabled && audio.isConnected && audio.models.contains(service.model) {
            ttsEngine.stop()
            kokoro.stop()
            audio.play(
                text: text,
                next: [],
                settings: service,
                speed: vm.speechRateMultiplier,
                repeats: 1,
                interval: 0.5,
                accent: vm.selectedAccent,
                preferredVoiceID: vm.storeSnapshot.selectedVoiceIdentifier
            )
            return
        }
        kokoro.stop()
        audio.stop()
        let voices = ttsEngine.availableVoices(for: vm.selectedAccent)
        let selected = voices.first { $0.id == vm.storeSnapshot.selectedVoiceIdentifier }
        let voice = selected ?? ttsEngine.selectBestFemaleVoice(preferredVoiceID: vm.storeSnapshot.selectedVoiceIdentifier, accent: vm.selectedAccent)
        ttsEngine.repeatCount = 1
        ttsEngine.speak(text: text, voice: voice, requestedRate: vm.speechRateMultiplier)
    }

    private var stubbornWordsDedicatedView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("顽固单词")
                .lumaFont(size: 30, weight: .bold, design: .serif)
                .foregroundStyle(appearance.ink)

            if vm.storeSnapshot.stubbornWords.isEmpty {
                Text("暂无顽固单词记录。")
                    .lumaFont(size: 14)
                    .foregroundStyle(appearance.ink.opacity(0.6))
                    .padding(.top, 20)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(vm.storeSnapshot.stubbornWords.sorted { $0.errorCount > $1.errorCount }) { rec in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    let wrongSamples = vm.storeSnapshot.dictationLogs.filter { $0.wordID == rec.wordID && !$0.isCorrect }.map(\.userTyped)
                                    Text(
                                        WordErrorLetterAnalyzer.highlightedAttributedWord(
                                            rec.word,
                                            typedAttempts: wrongSamples,
                                            baseFont: .system(size: 18, weight: .bold, design: .serif),
                                            normalColor: appearance.ink,
                                            errorColor: .red
                                        )
                                    )
                                    if let hint = WordErrorLetterAnalyzer.diagnoseSpellingPattern(targetWord: rec.word, typedAttempts: wrongSamples) {
                                        Text(hint)
                                            .lumaFont(size: 11.5, weight: .medium)
                                            .foregroundStyle(.red.opacity(0.85))
                                    }
                                    Text("所属原词库：\(rec.sourceDeckTitle) · 记录日期：\(rec.dateString)")
                                        .lumaFont(size: 12)
                                        .foregroundStyle(appearance.ink.opacity(0.65))
                                }
                                Spacer()
                                Button("复习此词库") {
                                    selectDeckAndStartDictation(deck: rec.sourceDeckID, mode: .stubbornWordReview, resume: true)
                                    mode = "学习_听力_今日计划"
                                }
                                Text("错误 \(rec.errorCount) 次")
                                    .lumaFont(size: 13, weight: .bold)
                                    .foregroundStyle(appearance.accent)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(appearance.background)
    }

    private var listeningRecordsDedicatedView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("听力学习记录（含听写反应时长）")
                .lumaFont(size: 30, weight: .bold, design: .serif)
                .foregroundStyle(appearance.ink)
            if vm.storeSnapshot.dictationLogs.isEmpty {
                Text("今日尚无听写记录，前往「听力 -> 今日计划」开始练习后将自动记录。")
                    .lumaFont(size: 14)
                    .foregroundStyle(appearance.ink.opacity(0.65))
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(vm.storeSnapshot.dictationLogs.reversed()) { log in
                            HStack(spacing: 12) {
                                Text(log.word)
                                    .lumaFont(size: 15, weight: .semibold, design: .serif)
                                    .foregroundStyle(appearance.ink)
                                Text("输入: \(log.userTyped)")
                                    .lumaFont(size: 12.5, design: .monospaced)
                                    .foregroundStyle(appearance.ink.opacity(0.75))
                                Text(String(format: "反应耗时 %.1fs", log.durationSeconds))
                                    .lumaFont(size: 11.5, weight: .medium, monospacedDigits: true)
                                    .foregroundStyle(log.isSlowReaction ? appearance.accent : appearance.ink.opacity(0.55))
                                if log.isSlowReaction {
                                    Text("慢反应词 (>5s)")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .studyGlassCapsule(cornerRadius: 9, selected: true)
                                        .foregroundStyle(appearance.accent)
                                }
                                Spacer()
                                Text(log.isCorrect ? "✓ 正确" : "✕ 错误 (第\(log.sessionErrorCountForWord)次)")
                                    .lumaFont(size: 12, weight: .bold)
                                    .foregroundStyle(log.isCorrect ? appearance.accent : appearance.ink.opacity(0.75))
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(appearance.surface))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(appearance.background)
    }

    // MARK: - 2. Task 2 Bank (200 Topics + 800 Collocations) & Writing History / AI Feedback Views

    private func launchTask2Topic(_ topic: LumaTask2TopicItem) {
        let fallbackT1 = vm.allTask1Questions.first ?? Self.builtInPracticeQuestions[0]
        let examItem = topic.asExamQuestionItem(fallbackTask1: fallbackT1)
        let singleTask = (vm.practiceSeconds != 3600)
        launchExam(for: examItem, singleTask: singleTask, initialPart: .part2)
    }

    private var visibleTask2Topics: [LumaTask2TopicItem] {
        let all = vm.allTask2Topics
        let catFiltered: [LumaTask2TopicItem]
        if selectedTask2Category == "全部" {
            catFiltered = all
        } else {
            catFiltered = all.filter { $0.category == selectedTask2Category || $0.subCategory == selectedTask2Category }
        }
        let q = task2SearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return catFiltered }
        return catFiltered.filter {
            $0.id.localizedCaseInsensitiveContains(q)
                || $0.shortTitle.localizedCaseInsensitiveContains(q)
                || $0.promptText.localizedCaseInsensitiveContains(q)
                || $0.category.localizedCaseInsensitiveContains(q)
                || $0.subCategory.localizedCaseInsensitiveContains(q)
                || $0.positivePoints.contains(where: { $0.localizedCaseInsensitiveContains(q) })
                || $0.negativePoints.contains(where: { $0.localizedCaseInsensitiveContains(q) })
        }
    }

    private var task2QuestionBankView: some View {
        let items = visibleTask2Topics
        return ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Task 2")
                            .lumaFont(size: 28, weight: .bold, design: .serif)
                            .foregroundStyle(appearance.ink)
                        Text("\(items.count) 题 · 双击开始写作")
                            .lumaFont(size: 12)
                            .foregroundStyle(appearance.ink.opacity(0.55))
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(appearance.ink.opacity(0.6))
                            TextField("搜索题目", text: $task2SearchQuery)
                                .textFieldStyle(.plain)
                                .lumaFont(size: 13)
                                .focused($task2SearchFocused)
                                .foregroundStyle(appearance.ink)
                            if !task2SearchQuery.isEmpty {
                                Button {
                                    task2SearchQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(appearance.ink.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 6)
                        .frame(width: 215, height: 38)

                        Rectangle()
                            .fill(appearance.ink.opacity(0.14))
                            .frame(width: 1, height: 18)
                            .padding(.horizontal, 2)

                        Menu {
                            Button {
                                editingTask2Item = nil
                                showTask2Editor = true
                            } label: {
                                Label("添加写作题目…", systemImage: "plus.circle")
                            }
                            Button {
                                showWritingBankManager = true
                            } label: {
                                Label("管理题库与分类…", systemImage: "slider.horizontal.3")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(appearance.ink.opacity(0.88))
                                .frame(width: 38, height: 38)
                                .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .help("添加写作题目、管理题库与分类")
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .studyGlassCapsule(cornerRadius: 22)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["全部"] + vm.availableTask2Categories, id: \.self) { cat in
                            let isSelected = (selectedTask2Category == cat)
                            Button {
                                selectedTask2Category = cat
                                if let first = visibleTask2Topics.first {
                                    selectedTask2QuestionID = first.id
                                }
                            } label: {
                                Text(cat)
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: isSelected, selected: isSelected, horizontalPadding: 14, height: 30))
                        }
                    }
                }

                if let writingVocabToastMessage {
                    Text(writingVocabToastMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(appearance.accent)
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(items) { item in
                            let existingDraft = vm.existingUnsubmittedDraft(for: item.id)
                            let isSelected = (selectedTask2QuestionID == item.id)
                            LumaTask2TopicCardView(
                                item: item,
                                isSelected: isSelected,
                                draftMinutesLeft: existingDraft.map { max(1, $0.remainingSeconds / 60) }
                            )
                            .id(item.id)
                            .overlay(alignment: .trailing) {
                                Menu {
                                    Button("开始练习") {
                                        selectedTask2QuestionID = item.id
                                        launchTask2Topic(item)
                                    }
                                    Button("一键导入本题搭配到听力生词本") {
                                        importCollocationsFromTopicToListening(item)
                                    }
                                    Button("编辑题目…") {
                                        editingTask2Item = item
                                        showTask2Editor = true
                                    }
                                    Menu("移动到主题分类") {
                                        ForEach(vm.availableTask2Categories, id: \.self) { cat in
                                            Button(cat) {
                                                var updated = item
                                                updated.category = cat
                                                vm.addOrUpdateTask2Topic(updated)
                                            }
                                        }
                                    }
                                    Divider()
                                    Button("删除题目", role: .destructive) {
                                        vm.deleteTask2Topic(id: item.id)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(appearance.ink.opacity(0.6))
                                        .padding(8)
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .padding(.trailing, 6)
                            }
                            .onTapGesture(count: 2) {
                                selectedTask2QuestionID = item.id
                                launchTask2Topic(item)
                            }
                            .onTapGesture(count: 1) {
                                task2SearchFocused = false
                                selectedTask2QuestionID = item.id
                            }
                        }
                    }
                }
            }
            .padding(28)
            .background(appearance.background)
            .background(
                StudyKeyboardEventMonitor { event in
                    guard !task2SearchFocused else { return false }
                    let list = visibleTask2Topics
                    guard !list.isEmpty else { return false }
                    switch event.keyCode {
                    case 125:
                        let idx = list.firstIndex(where: { $0.id == selectedTask2QuestionID }) ?? 0
                        let nextIdx = min(list.count - 1, idx + 1)
                        selectedTask2QuestionID = list[nextIdx].id
                        withAnimation(.easeOut(duration: 0.14)) {
                            proxy.scrollTo(selectedTask2QuestionID, anchor: .center)
                        }
                        return true
                    case 126:
                        let idx = list.firstIndex(where: { $0.id == selectedTask2QuestionID }) ?? 0
                        let prevIdx = max(0, idx - 1)
                        selectedTask2QuestionID = list[prevIdx].id
                        withAnimation(.easeOut(duration: 0.14)) {
                            proxy.scrollTo(selectedTask2QuestionID, anchor: .center)
                        }
                        return true
                    case 36, 76:
                        let chosen = list.first(where: { $0.id == selectedTask2QuestionID }) ?? list[0]
                        launchTask2Topic(chosen)
                        return true
                    default:
                        return false
                    }
                }
            )
        }
    }

    private func importSingleCollocationStringToListening(_ rawColloc: String, sourceTitle: String) {
        let trimmed = rawColloc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let scalars = Array(trimmed.unicodeScalars)
        let enPart: String
        let zhPart: String
        if let firstCJK = scalars.firstIndex(where: { ExamEnglishInputPolicy.isCJKScalar($0) }) {
            enPart = String(String.UnicodeScalarView(scalars[..<firstCJK])).trimmingCharacters(in: .whitespacesAndNewlines)
            zhPart = String(String.UnicodeScalarView(scalars[firstCJK...])).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            enPart = trimmed
            zhPart = BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: trimmed) ?? "写作高分搭配（\(sourceTitle)）"
        }
        guard !enPart.isEmpty else { return }
        let word = VocabularyWord(
            id: "colloc_import_\(abs(enPart.lowercased().hashValue) % 1_000_000)",
            word: enPart,
            definitionZH: "phr. \(zhPart)",
            exampleSentence: sourceTitle,
            deckID: "vocab_writing_accumulations",
            deckTitle: "写作错词与高分搭配本"
        )
        _ = saveImportedWords([word])
        writingVocabToastMessage = "✓ 已将固定搭配「\(enPart)」导入《写作错词与高分搭配本》，可在听力模块直接听写！"
    }

    private func importCollocationsFromTopicToListening(_ topic: LumaTask2TopicItem) {
        for pt in topic.positivePoints + topic.negativePoints {
            importSingleCollocationStringToListening(pt, sourceTitle: topic.shortTitle)
        }
        writingVocabToastMessage = "✓ 已将「\(topic.shortTitle)」全部 \(topic.positivePoints.count + topic.negativePoints.count) 组高分搭配导入《写作错词与高分搭配本》！"
    }

    private var writingHistoryAndFeedbackView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("历史作文与雅思官方标准评分反馈")
                        .lumaFont(size: 30, weight: .bold, design: .serif)
                        .foregroundStyle(appearance.ink)
                    Text("自动识别小作文 (Academic Task 1 · TA) 与大作文 (Task 2 · TR) · 支持将优美固定搭配或错误单词一键导入听力生词本进行听写。")
                        .lumaFont(size: 12.5)
                        .foregroundStyle(appearance.ink.opacity(0.72))
                }
                Spacer()
                Button("🎧 去听写我的写作错词与搭配本") {
                    selectDeckAndStartDictation(deck: "vocab_writing_accumulations", mode: .newTask, resume: true)
                    mode = "学习_听力_今日计划"
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))

                if !vm.storeSnapshot.writingSubmissions.isEmpty {
                    Button("导出作文复盘报告 (.md)") {
                        exportWritingReviewMarkdown()
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 32))
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.bubble")
                    .foregroundStyle(appearance.accent)
                TextField("输入或粘贴作文中的优美固定搭配 / 易错单词（自动匹配中文释义）", text: $customPhraseToImport)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: customPhraseToImport) { _, newValue in
                        if let dictZH = BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: newValue) {
                            customPhraseMeaningZH = dictZH
                        }
                    }
                TextField("中文释义（自动识别或手动修改）", text: $customPhraseMeaningZH)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                Button("加入听力生词本") {
                    let cleanEn = customPhraseToImport.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanEn.isEmpty else { return }
                    let finalZH = customPhraseMeaningZH.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? (BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: cleanEn) ?? "写作积累词条")
                        : customPhraseMeaningZH
                    let w = VocabularyWord(
                        id: "writing_manual_\(abs(cleanEn.lowercased().hashValue) % 1_000_000)",
                        word: cleanEn,
                        definitionZH: finalZH,
                        deckID: "vocab_writing_accumulations",
                        deckTitle: "写作错词与高分搭配本"
                    )
                    _ = saveImportedWords([w])
                    writingVocabToastMessage = "✓ 已将「\(cleanEn)（\(finalZH)）」导入《写作错词与高分搭配本》，可在听力部分听写！"
                    customPhraseToImport = ""
                    customPhraseMeaningZH = ""
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: true, horizontalPadding: 14, height: 30))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(appearance.surface))

            if let writingVocabToastMessage {
                Text(writingVocabToastMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.accent)
            }

            if vm.storeSnapshot.writingSubmissions.isEmpty {
                Text("暂无已提交的历史作文。双击 Task 1 或 Task 2 题卡完成练习并点击「交卷」后在此查看官方四维评分、红绿纠错，并一键将固定搭配与错词导入听力生词本。")
                    .lumaFont(size: 14)
                    .foregroundStyle(appearance.ink.opacity(0.65))
                    .padding(.top, 16)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(vm.storeSnapshot.writingSubmissions) { sub in
                            let matchedQuestion = resolveExamQuestion(for: sub.questionID, examTitle: sub.examTitle)
                            let audit = IELTSOfficialRubricEngine.audit(record: sub, question: matchedQuestion)
                            let effectiveEval = sub.aiEvaluation ?? audit.deterministicEstimate

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Button("删除作文", role: .destructive) { submissionToDelete = sub.id }
                                    Text(sub.examTitle)
                                        .lumaFont(size: 17, weight: .bold, design: .serif)
                                        .foregroundStyle(appearance.ink)
                                    Text(audit.detectedTaskMode.rawValue)
                                        .lumaFont(size: 11.5, weight: .semibold)
                                        .foregroundStyle(appearance.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(appearance.selected))
                                    Spacer()
                                    Button("📥 一键将本篇错词与优美搭配导入听力生词本") {
                                        let count = importSubmissionVocabularyToListening(sub: sub, audit: audit, evaluation: effectiveEval)
                                        writingVocabToastMessage = "✓ 已将《\(sub.examTitle)》中的 \(count) 个错词与高分固定搭配导入《写作错词与高分搭配本》！"
                                    }
                                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: true, horizontalPadding: 12, height: 28))

                                    if sub.aiEvaluation == nil { Text("待评分").font(.caption).foregroundStyle(.secondary) }
                                    Text(String(format: "总分: Band %.1f", effectiveEval.overallEstimatedBand))
                                        .lumaFont(size: 14, weight: .bold)
                                        .foregroundStyle(appearance.accent)
                                }

                                let autoPromptText = (audit.detectedTaskMode == .writingTask2)
                                    ? (matchedQuestion.companionTask2Prompt ?? matchedQuestion.promptText)
                                    : matchedQuestion.promptText
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(appearance.accent)
                                        Text("AI 已自动识别本题题目（无需手动提交题干）：")
                                            .lumaFont(size: 11.5, weight: .semibold)
                                            .foregroundStyle(appearance.accent)
                                    }
                                    Text(autoPromptText)
                                        .lumaFont(size: 12.5, design: .serif)
                                        .foregroundStyle(appearance.ink.opacity(0.82))
                                        .textSelection(.enabled)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 8).fill(appearance.paper.opacity(0.55)))

                                IELTSOfficialRubricDiagnosticCardView(audit: audit)

                                if !audit.spellingErrorWords.isEmpty {
                                    HStack(spacing: 8) {
                                        Text("检测到拼写错误词（点击一键加入听力生词本）：")
                                            .font(.caption.bold())
                                            .foregroundStyle(.red)
                                        ForEach(audit.spellingErrorWords, id: \.self) { errWord in
                                            Button("+ \(errWord)") {
                                                let corrected = Self.knownSpellingCorrectionTarget(for: errWord)
                                                let zh = BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: corrected) ?? "写作拼写纠错词（原误拼：\(errWord)）"
                                                let w = VocabularyWord(
                                                    id: "spell_fix_\(corrected.lowercased())",
                                                    word: corrected,
                                                    definitionZH: zh,
                                                    exampleSentence: "原作文误拼为：\(errWord)",
                                                    deckID: "vocab_writing_accumulations",
                                                    deckTitle: "写作错词与高分搭配本"
                                                )
                                                _ = saveImportedWords([w])
                                                writingVocabToastMessage = "✓ 已将正确拼写「\(corrected)（\(zh)）」加入《写作错词与高分搭配本》！"
                                            }
                                            .font(.caption)
                                            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 10, height: 24))
                                        }
                                        Spacer()
                                    }
                                }

                                HStack(spacing: 10) {
                                    Button("修改对照与重写 (含红绿差异)") {
                                        let saved = vm.storeSnapshot.writingRevisions?.filter { $0.submissionID == sub.id }.max { $0.updatedAt < $1.updatedAt }
                                        reviewSession = WritingReviewSession(original: sub, revision: saved ?? WritingRevision(original: sub))
                                    }
                                    Button("新建重写版本") { reviewSession = WritingReviewSession(original: sub, revision: WritingRevision(original: sub)) }
                                    Text("\((vm.storeSnapshot.writingRevisions ?? []).filter { $0.submissionID == sub.id }.count) 个重写版本").font(.caption)
                                    Spacer()
                                    Button("应用官方标准评分 (\(audit.detectedTaskMode.firstCriterionCode)/CC/LR/GRA)") {
                                        if let index = vm.storeSnapshot.writingSubmissions.firstIndex(where: { $0.id == sub.id }) {
                                            vm.storeSnapshot.writingSubmissions[index].aiEvaluation = audit.deterministicEstimate
                                            vm.save()
                                        }
                                    }
                                    if let evaluateWriting {
                                        Button(vm.evaluatingSubmission == sub.id ? "评估中..." : "发送此作文至已配置 AI 评估") {
                                            vm.evaluatingSubmission = sub.id
                                            Task {
                                                defer { vm.evaluatingSubmission = nil }
                                                do {
                                                    let rawAI = try await evaluateWriting(sub, matchedQuestion)
                                                    let calibrated = IELTSOfficialRubricEngine.calibrate(aiEstimate: rawAI, with: audit)
                                                    if let index = vm.storeSnapshot.writingSubmissions.firstIndex(where: { $0.id == sub.id }) {
                                                        vm.storeSnapshot.writingSubmissions[index].aiEvaluation = calibrated
                                                        vm.save()
                                                    }
                                                } catch {
                                                    if let index = vm.storeSnapshot.writingSubmissions.firstIndex(where: { $0.id == sub.id }) {
                                                        vm.storeSnapshot.writingSubmissions[index].aiEvaluation = audit.deterministicEstimate
                                                        vm.save()
                                                    }
                                                    vm.storageError = "外部 AI 未连接，已自动使用内嵌雅思官方 May 2023 标准引擎完成评分（\(error.localizedDescription)）"
                                                }
                                            }
                                        }
                                        .disabled(vm.evaluatingSubmission == sub.id)
                                    }
                                }

                                ForEach((vm.storeSnapshot.writingRevisions ?? []).filter { $0.submissionID == sub.id }.sorted { $0.updatedAt > $1.updatedAt }) { revision in
                                    Button("打开重写 · \(revision.updatedAt.formatted(date: .abbreviated, time: .shortened))") {
                                        reviewSession = WritingReviewSession(original: sub, revision: revision)
                                    }.font(.caption)
                                }

                                if !effectiveEval.sentenceCorrections.isEmpty {
                                    Divider()
                                    Text("逐句红绿对比批改与 Band 7.5+ 表达升级（可单条导入听力生词本）")
                                        .lumaFont(size: 13, weight: .bold)
                                        .foregroundStyle(appearance.ink)
                                    ForEach(Array(effectiveEval.sentenceCorrections.enumerated()), id: \.offset) { _, correction in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                if let kind = correction.kind, !kind.isEmpty {
                                                    Text(kind)
                                                        .font(.caption.weight(.semibold))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(appearance.accent.opacity(0.14), in: Capsule())
                                                }
                                                Spacer()
                                                Button("+ 将此高分搭配/修正词加入听力生词本") {
                                                    let extracted = WritingReviewPanel.extractVocabularyWords(from: [correction], examTitle: sub.examTitle)
                                                    _ = saveImportedWords(extracted)
                                                    writingVocabToastMessage = "✓ 已将「\(extracted.first?.word ?? correction.upgradedExpression)」导入《写作错词与高分搭配本》！"
                                                }
                                                .font(.caption)
                                                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 10, height: 24))
                                            }
                                            WritingInlineDiffView(
                                                originalText: correction.originalSentence,
                                                revisedText: correction.correctedSentence,
                                                fontSize: 13.5
                                            )
                                            Text(correction.explanationZH)
                                                .font(.callout)
                                                .foregroundStyle(appearance.ink.opacity(0.88))
                                            if !correction.upgradedExpression.isEmpty && correction.upgradedExpression != correction.correctedSentence {
                                                Text("高分升级示范：\(correction.upgradedExpression)")
                                                    .lumaFont(size: 12.5, design: .serif)
                                                    .foregroundStyle(appearance.accent)
                                            }
                                        }
                                        .textSelection(.enabled)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(appearance.paper.opacity(0.45)))
                                    }
                                }

                                Text("提交日期：\(sub.dateString) · Part 1 字数：\(sub.part1WordCount) · Part 2 字数：\(sub.part2WordCount) · 用时：\(sub.durationSeconds / 60) 分钟")
                                    .lumaFont(size: 12)
                                    .foregroundStyle(appearance.ink.opacity(0.7))
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 12).fill(appearance.surface))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(appearance.background)
    }

    private static func knownSpellingCorrectionTarget(for wrongWord: String) -> String {
        let map: [String: String] = [
            "teh": "the",
            "enviroment": "environment",
            "goverment": "government",
            "accomodation": "accommodation",
            "occured": "occurred",
            "seperate": "separate",
            "definately": "definitely",
            "neccessary": "necessary",
            "recieve": "receive",
            "untill": "until",
            "wierd": "weird",
            "fullfill": "fulfill",
            "collegue": "colleague",
            "priviledge": "privilege",
            "maintainance": "maintenance",
            "independant": "independent",
            "existance": "existence",
            "arguement": "argument",
            "concious": "conscious",
            "embarass": "embarrass"
        ]
        return map[wrongWord.lowercased()] ?? wrongWord
    }

    private func importSubmissionVocabularyToListening(
        sub: WritingSubmissionRecord,
        audit: IELTSRubricAuditReport,
        evaluation: IELTSFourCriteriaEstimate
    ) -> Int {
        var words = WritingReviewPanel.extractVocabularyWords(from: evaluation.sentenceCorrections, examTitle: sub.examTitle)
        for errWord in audit.spellingErrorWords {
            let corrected = Self.knownSpellingCorrectionTarget(for: errWord)
            let zh = BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: corrected) ?? "写作纠错词（原误拼：\(errWord)）"
            words.append(
                VocabularyWord(
                    id: "spell_fix_\(corrected.lowercased())",
                    word: corrected,
                    definitionZH: zh,
                    exampleSentence: "源自作文《\(sub.examTitle)》",
                    deckID: "vocab_writing_accumulations",
                    deckTitle: "写作错词与高分搭配本"
                )
            )
        }
        if words.isEmpty {
            for item in BuiltInIELTSDictionaryEngine.writingCollocationDictionary.words.prefix(5) {
                words.append(
                    VocabularyWord(
                        id: "accum_\(item.id)",
                        word: item.word,
                        definitionZH: item.definitionZH,
                        exampleSentence: sub.examTitle,
                        deckID: "vocab_writing_accumulations",
                        deckTitle: "写作错词与高分搭配本"
                    )
                )
            }
        }
        _ = saveImportedWords(words)
        return words.count
    }

    private func exportWritingReviewMarkdown() {
        var md = "# LumaReader 雅思写作官方标准批改与重写复盘报告\n\n"
        for sub in vm.storeSnapshot.writingSubmissions {
            let q = resolveExamQuestion(for: sub.questionID, examTitle: sub.examTitle)
            let audit = IELTSOfficialRubricEngine.audit(record: sub, question: q)
            let eval = sub.aiEvaluation ?? audit.deterministicEstimate
            md += "## \(sub.examTitle) (\(audit.detectedTaskMode.rawValue))\n"
            md += "- 提交日期：\(sub.dateString) | 有效词数：\(audit.effectiveWordCount) 词 | 预估总分：**Band \(String(format: "%.1f", eval.overallEstimatedBand))**_\n"
            md += "- 四维小分：\(audit.detectedTaskMode.firstCriterionCode) \(String(format: "%.1f", eval.taskAchievementOrResponse)) | CC \(String(format: "%.1f", eval.coherenceAndCohesion)) | LR \(String(format: "%.1f", eval.lexicalResource)) | GRA \(String(format: "%.1f", eval.grammaticalRangeAndAccuracy))\n\n"
            if !sub.part1EssayText.isEmpty {
                md += "### Part 1 原文\n\(sub.part1EssayText)\n\n"
            }
            if !sub.part2EssayText.isEmpty {
                md += "### Part 2 原文\n\(sub.part2EssayText)\n\n"
            }
            if !eval.sentenceCorrections.isEmpty {
                md += "### 逐句批改与高分升级\n"
                for c in eval.sentenceCorrections {
                    md += "- **原句**：\(c.originalSentence)\n"
                    md += "- **修正**：\(c.correctedSentence)\n"
                    md += "- **解析**：\(c.explanationZH)\n\n"
                }
            }
            md += "---\n\n"
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "IELTS_Writing_Review_\(Self.todayDateString()).md"
        if panel.runModal() == .OK, let url = panel.url {
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private var studyHome: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("学习").font(.largeTitle)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))], spacing: 20) {
                homeCard(
                    hasUnfinishedListeningSession ? "词汇听写（继续练习）" : "词汇听写",
                    symbol: "headphones",
                    destination: hasUnfinishedListeningSession ? (vm.dictationMachine.mode == .wrongWordReview ? "学习_听力_错词复习" : "学习_听力_今日计划") : "学习_听力"
                )
                homeCard("内置权威词典", symbol: "character.book.closed.fill", destination: "学习_听力_权威词典")
                homeCard("慢反应词提速", symbol: "bolt.badge.clock", destination: "学习_听力_慢反应词")
                homeCard("学习统计与热力图", symbol: "chart.bar", destination: "学习_统计")
                homeCard(
                    hasUnfinishedWritingDraft ? "雅思写作（继续草稿）" : "雅思写作",
                    symbol: "pencil",
                    destination: hasUnfinishedWritingDraft ? "学习_写作_模拟机考" : "学习_写作_Task1题库"
                )
            }
            Spacer()
        }.padding(32)
    }

    private func homeCard(_ title: String, symbol: String, destination: String) -> some View {
        Button { mode = destination } label: {
            VStack(spacing: 20) { Image(systemName: symbol).font(.largeTitle); Text(title).font(.headline) }
                .frame(maxWidth: .infinity, minHeight: 180).background(appearance.surface, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(StudyFluidPressStyle())
    }

    private var readingVocabularySection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                readingVocabularyTab("词库", destination: "学习_阅读词汇", selected: mode == "学习_阅读词汇" || mode == "学习_易混词")
                readingVocabularyTab("错词", destination: "学习_阅读错词", selected: mode == "学习_阅读错词")
                readingVocabularyTab("分类", destination: "学习_阅读分类", selected: mode == "学习_阅读分类" || mode == "学习_背词")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .studyGlassCapsule(cornerRadius: 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, VocabularyPageLayout.inset)
            .padding(.vertical, 10)

            switch mode {
            case "学习_阅读分类", "学习_背词":
                choiceLibraryPage
            case "学习_阅读错词":
                ReadingWrongWordsView(library: choiceLibrary) { words in
                    readingReviewWords = words
                    startReadingQuiz(LumaChoiceLibrary.reviewDeckID)
                }
            case "学习_易混词":
                LumaConfusableLibraryView(library: LumaConfusableLibrary.shared) { scope in
                    confusableScope = scope
                    mode = "学习_易混词_练习"
                }
            default:
                ReadingVocabularyView(library: choiceLibrary, onStart: startReadingQuiz, onConfusable: {
                    mode = "学习_易混词"
                }, position: $readingVocabularyPosition)
            }
        }
    }

    private func readingVocabularyTab(_ title: String, destination: String, selected: Bool) -> some View {
        Button(title) { mode = destination }
            .buttonStyle(StudyGlassCapsuleButtonStyle(selected: selected, horizontalPadding: 12, height: 32))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var listeningHome: some View {
        deckManagement(ScrollView {
            VStack(alignment: .leading, spacing: VocabularyPageLayout.spacing) {
                VocabularyPageHeading(title: "听力", placeholder: "搜索词库", search: $deckSearch) {
                    Menu {
                        Button {
                            importShown = true
                        } label: {
                            Label("导入词库 (TXT / CSV / JSON)…", systemImage: "plus.circle")
                        }
                        Button {
                            showMixedWrongSelector()
                        } label: {
                            Label("多词本错词合练…", systemImage: "square.stack")
                        }
                        Divider()
                        Button {
                            mode = "学习_听力_权威词典"
                        } label: {
                            Label("浏览内置权威词典", systemImage: "character.book.closed")
                        }
                        Button {
                            mode = "学习_听力_慢反应词"
                        } label: {
                            Label("慢反应词提速巩固", systemImage: "bolt.badge.clock")
                        }
                        Button {
                            mode = "学习_听力_顽固单词"
                        } label: {
                            Label("顽固单词本", systemImage: "exclamationmark.triangle")
                        }
                        Divider()
                        Button {
                            openSpeechSettings()
                        } label: {
                            Label("发音与神经语音设置…", systemImage: "waveform")
                        }
                    } label: {
                        VocabularyPageMenuLabel()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("导入词库、多词本合练与发音设置")
                    .accessibilityLabel("听力词库操作")
                }

                ListeningDailyGoalCard(timer: listeningDailyTimer, completed: DictationSessionStateMachine.todayDictatedWordCount(from: vm.storeSnapshot.dictationLogs, on: Self.todayDateString()))

                HStack(spacing: 10) {
                    Picker("复习词库", selection: $vm.selectedDeck) {
                        ForEach(visibleListeningDeckIDs, id: \.self) { deck in
                            Text(deckTitle(for: deck)).tag(deck)
                        }
                    }
                    .frame(maxWidth: 260)
                    Text("到期 \(dueReviewCount) 词")
                        .lumaFont(size: 12, monospacedDigits: true)
                        .foregroundStyle(appearance.ink.opacity(0.66))
                    Button("开始到期复习") {
                        selectDeckAndStartDictation(deck: vm.selectedDeck, mode: .wrongWordReview, resume: true, dueOnly: true)
                        mode = "学习_听力_错词复习"
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: dueReviewCount > 0, horizontalPadding: 14, height: 30))
                    .disabled(dueReviewCount == 0)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(appearance.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))

                if filteredListeningDeckIDs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.and.arrow.down").font(.system(size: 34, weight: .light)).foregroundStyle(appearance.accent)
                        Text(visibleListeningDeckIDs.isEmpty ? "还没有词库" : "当前分类「\(selectedListeningCategory)」下暂无匹配词库").font(.headline).foregroundStyle(appearance.ink)
                        HStack(spacing: 10) {
                            if selectedListeningCategory != "全部" {
                                Button("显示全部词库") { selectedListeningCategory = "全部"; selectedScenarioPreviewDeckID = nil }
                                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 32))
                            }
                            Button("导入词库", systemImage: "square.and.arrow.down") { importShown = true }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                }

                let gridWordsByDeck = vm.fastWordsByDeck
                LazyVGrid(columns: VocabularyPageLayout.columns, alignment: .leading, spacing: VocabularyPageLayout.spacing) {
                    ForEach(filteredListeningDeckIDs, id: \.self) { deck in
                        let words = gridWordsByDeck[deck] ?? []
                        let title = words.first?.deckTitle ?? BundledCoraVocabulary.defaultTitleByDeckID[deck] ?? deck
                        let deckCat = categoryForDeck(deck)
                        let isPreviewingThisDeck = (selectedScenarioPreviewDeckID == deck && showListeningCategoryWordBrowser)
                        let key = HostStateModel.sessionKey(mode: .newTask, date: Self.todayDateString(), deck: deck)
                        let savedSession = (vm.dictationMachine.mode == .newTask && (vm.dictationMachine.currentWord?.deckID ?? vm.selectedDeck) == deck) ? vm.dictationMachine : vm.storeSnapshot.dictationSessions?[key]
                        let resumable = savedSession.flatMap { session in
                            !session.isSessionFinished && (!session.completedWordIDs.isEmpty || !session.attemptLogs.isEmpty) ? session : nil
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Spacer(minLength: 16)
                            HStack(spacing: 10) {
                                Image(systemName: deck == "vocab_writing_accumulations" ? "pencil.and.list.clipboard" : "headphones")
                                    .font(.system(size: 23, weight: .light))
                                    .foregroundStyle(appearance.accent)
                                Spacer()
                            }
                            Text(title)
                                .lumaFont(size: 16, weight: .semibold)
                                .foregroundStyle(appearance.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            if let resumable {
                                Text("\(resumable.completedWordIDs.count) / \(resumable.completedWordIDs.count + resumable.pendingQueue.count)")
                                    .font(.caption)
                                    .foregroundStyle(appearance.accent)
                            } else {
                                Text("\(words.count) 词")
                                    .font(.caption)
                                    .foregroundStyle(appearance.ink.opacity(0.68))
                            }
                            if deck == "vocab_writing_accumulations" {
                                Text("作文好词搭配与纠错生词本")
                                    .font(.caption2)
                                    .foregroundStyle(appearance.accent)
                            }
                            Spacer(minLength: 4)
                            HStack(spacing: 8) {
                                Button {
                                    withAnimation(.easeOut(duration: 0.16)) {
                                        if selectedScenarioPreviewDeckID == deck && showListeningCategoryWordBrowser {
                                            selectedScenarioPreviewDeckID = nil
                                        } else {
                                            selectedScenarioPreviewDeckID = deck
                                            showListeningCategoryWordBrowser = true
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: isPreviewingThisDeck ? "book.fill" : "book")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(isPreviewingThisDeck ? "正在看词" : "查看单词")
                                            .lumaFont(size: 11.5, weight: .medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(StudyScrollCapsuleButtonStyle(theme: appearance, onAccent: dictOnAccent, selected: isPreviewingThisDeck, horizontalPadding: 8, height: 28))

                                Button {
                                    startDictationFromLibraryCard(deck)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10.5, weight: .semibold))
                                        Text(resumable == nil ? "开始听写" : "继续听写")
                                            .lumaFont(size: 11.5, weight: .semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(StudyScrollCapsuleButtonStyle(theme: appearance, onAccent: dictOnAccent, prominent: true, horizontalPadding: 8, height: 28))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: VocabularyPageLayout.cardHeight, alignment: .leading)
                        .background(appearance.secondaryGradient, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    dropTargetDeckID == deck ? appearance.accent : (isPreviewingThisDeck ? appearance.accent : (isDeckPinned(deck) ? appearance.accent.opacity(0.55) : appearance.line)),
                                    lineWidth: (dropTargetDeckID == deck || isPreviewingThisDeck) ? 2.0 : 1.0
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                        .onTapGesture(count: 2) {
                            startDictationFromLibraryCard(deck)
                        }
                        .onTapGesture(count: 1) {
                            withAnimation(.easeOut(duration: 0.16)) {
                                selectedScenarioPreviewDeckID = deck
                                showListeningCategoryWordBrowser = true
                            }
                        }
                        .contextMenu { deckActions(deck) }
                        .draggable("luma-deck:" + deck)
                        .dropDestination(for: String.self) { items, _ in
                            guard let first = items.first, first.hasPrefix("luma-deck:") else { return false }
                            let draggedDeck = String(first.dropFirst("luma-deck:".count))
                            reorderDeck(draggedDeck: draggedDeck, targetDeck: deck)
                            return true
                        } isTargeted: { targeted in
                            dropTargetDeckID = targeted ? deck : (dropTargetDeckID == deck ? nil : dropTargetDeckID)
                        }
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 6) {
                                if !deckCat.isEmpty {
                                    Text(deckCat)
                                        .lumaFont(size: 10.5, weight: .semibold)
                                        .foregroundStyle(appearance.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(appearance.selected))
                                }
                                if isDeckPinned(deck) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 9.5, weight: .semibold))
                                        Text("置顶")
                                            .lumaFont(size: 10, weight: .semibold)
                                    }
                                    .foregroundStyle(appearance.accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(appearance.selected))
                                }
                            }
                            .padding(10)
                            .allowsHitTesting(false)
                        }
                        .overlay(alignment: .topTrailing) {
                            Menu {
                                deckActions(deck)
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(appearance.ink.opacity(0.45))
                                    .frame(width: 32, height: 32)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .padding(6)
                            .help("词库操作（置顶 / 排序 / 编辑词条 / 重命名 / 删除）")
                        }
                        .scaleEffect(dropTargetDeckID == deck ? 1.02 : 1.0)
                        .id(deck)
                    }
                }
                .scrollTargetLayout()

            }
            .padding(.horizontal, VocabularyPageLayout.inset)
            .padding(.vertical, VocabularyPageLayout.topInset)
        }
        .scrollPosition(id: $listeningCardID)
        .scrollClipDisabled(false)
        .mask(Rectangle())
        .background(appearance.background))
        .sheet(isPresented: $showListeningCategoryWordBrowser) {
            // 点「查看单词」弹出紧凑词表小窗，而不是整页长表或词库编辑器。
            listeningWordQuickPanel
                .background(appearance.background)
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["LUMA_DEBUG_WORD_SHEET"] == "1",
               !showListeningCategoryWordBrowser {
                selectedScenarioPreviewDeckID = filteredListeningDeckIDs.first
                showListeningCategoryWordBrowser = true
            }
            #endif
        }
    }

    // MARK: - 专门的仿 macOS 访达 (Finder) 三级分类文件管理器界面（支持文件夹内再建子文件夹、拖拽归类、图标/分栏/列表三种视图）

    private struct FinderFolderItem: Identifiable, Equatable {
        var id: String { path.joined(separator: "/") }
        let name: String
        let displayBadgeName: String
        let path: [String]
        let totalWordCount: Int
        let isCustom: Bool
    }

    private var customFinderFolderPaths: [[String]] {
        finderCustomFoldersRaw
            .split(separator: "|")
            .map { $0.split(separator: "/").map(String.init).filter { !$0.isEmpty } }
            .filter { !$0.isEmpty }
    }

    private func addCustomFinderFolder(parentPath: [String], folderName: String) {
        let clean = folderName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "·").replacingOccurrences(of: "|", with: "·")
        guard !clean.isEmpty else { return }
        let newPath = parentPath + [clean]
        var current = customFinderFolderPaths
        if !current.contains(newPath) {
            current.append(newPath)
            finderCustomFoldersRaw = current.map { $0.joined(separator: "/") }.joined(separator: "|")
        }
    }

    private func deleteCustomFinderFolder(path: [String]) {
        guard !path.isEmpty else { return }
        let prefix = path.joined(separator: "/")
        let remaining = customFinderFolderPaths.filter {
            let p = $0.joined(separator: "/")
            return p != prefix && !p.hasPrefix(prefix + "/")
        }
        finderCustomFoldersRaw = remaining.map { $0.joined(separator: "/") }.joined(separator: "|")
        removeFinderFolderIcons(atOrUnder: path)
        if finderCurrentPath.starts(with: path) {
            finderNavigate(to: Array(path.dropLast()))
        }
    }

    // MARK: - 文件夹图标体系（学习主题 + 系统主题，创建时可选，也可随时更换）

    private struct FinderIconOption: Identifiable, Hashable {
        let id: String
        let symbol: String
        let title: String
        let group: String
        let colors: [Color]
    }

    private enum FinderIconCatalog {
        /// 学习主题图标：按雅思/日常学习场景命名，创建文件夹时可任选。
        static var learningOptions: [FinderIconOption] { [
            FinderIconOption(id: "listening", symbol: "headphones", title: "听力", group: "学习主题", colors: [Color(red: 0.98, green: 0.42, blue: 0.52), Color(red: 0.92, green: 0.24, blue: 0.42)]),
            FinderIconOption(id: "reading", symbol: "book.closed.fill", title: "阅读", group: "学习主题", colors: [Color(red: 0.96, green: 0.66, blue: 0.28), Color(red: 0.90, green: 0.46, blue: 0.16)]),
            FinderIconOption(id: "writing", symbol: "pencil.line", title: "写作", group: "学习主题", colors: [Color(red: 0.62, green: 0.40, blue: 0.96), Color(red: 0.44, green: 0.24, blue: 0.84)]),
            FinderIconOption(id: "speaking", symbol: "mic.fill", title: "口语", group: "学习主题", colors: [Color(red: 0.30, green: 0.62, blue: 0.98), Color(red: 0.16, green: 0.44, blue: 0.90)]),
            FinderIconOption(id: "vocab", symbol: "textformat.abc", title: "词汇", group: "学习主题", colors: [Color(red: 0.20, green: 0.76, blue: 0.70), Color(red: 0.10, green: 0.58, blue: 0.54)]),
            FinderIconOption(id: "grammar", symbol: "character.book.closed", title: "语法", group: "学习主题", colors: [Color(red: 0.36, green: 0.44, blue: 0.92), Color(red: 0.22, green: 0.30, blue: 0.80)]),
            FinderIconOption(id: "housing", symbol: "house.fill", title: "租房", group: "学习主题", colors: [Color(red: 0.98, green: 0.54, blue: 0.32), Color(red: 0.92, green: 0.36, blue: 0.18)]),
            FinderIconOption(id: "work", symbol: "briefcase.fill", title: "工作", group: "学习主题", colors: [Color(red: 0.38, green: 0.52, blue: 0.95), Color(red: 0.24, green: 0.36, blue: 0.84)]),
            FinderIconOption(id: "travel", symbol: "map.fill", title: "旅行", group: "学习主题", colors: [Color(red: 0.20, green: 0.74, blue: 0.62), Color(red: 0.10, green: 0.56, blue: 0.48)]),
            FinderIconOption(id: "research", symbol: "graduationcap.fill", title: "学术", group: "学习主题", colors: [Color(red: 0.30, green: 0.56, blue: 0.96), Color(red: 0.16, green: 0.40, blue: 0.86)]),
            FinderIconOption(id: "ecology", symbol: "leaf.fill", title: "生态", group: "学习主题", colors: [Color(red: 0.38, green: 0.76, blue: 0.34), Color(red: 0.22, green: 0.60, blue: 0.24)]),
            FinderIconOption(id: "business", symbol: "chart.pie.fill", title: "商业", group: "学习主题", colors: [Color(red: 0.95, green: 0.36, blue: 0.58), Color(red: 0.84, green: 0.22, blue: 0.46)]),
            FinderIconOption(id: "culture", symbol: "building.columns.fill", title: "文化", group: "学习主题", colors: [Color(red: 0.78, green: 0.60, blue: 0.38), Color(red: 0.64, green: 0.44, blue: 0.24)]),
            FinderIconOption(id: "science", symbol: "atom", title: "科学", group: "学习主题", colors: [Color(red: 0.18, green: 0.68, blue: 0.86), Color(red: 0.10, green: 0.50, blue: 0.72)]),
            FinderIconOption(id: "geography", symbol: "globe.asia.australia.fill", title: "地理", group: "学习主题", colors: [Color(red: 0.24, green: 0.58, blue: 0.82), Color(red: 0.14, green: 0.42, blue: 0.66)]),
            FinderIconOption(id: "food", symbol: "fork.knife", title: "饮食", group: "学习主题", colors: [Color(red: 0.96, green: 0.48, blue: 0.30), Color(red: 0.88, green: 0.30, blue: 0.20)]),
            FinderIconOption(id: "health", symbol: "heart.fill", title: "健康", group: "学习主题", colors: [Color(red: 0.96, green: 0.40, blue: 0.56), Color(red: 0.86, green: 0.22, blue: 0.40)]),
            FinderIconOption(id: "exam", symbol: "checkmark.seal.fill", title: "考试", group: "学习主题", colors: [Color(red: 0.92, green: 0.72, blue: 0.24), Color(red: 0.82, green: 0.56, blue: 0.10)]),
            FinderIconOption(id: "wrong", symbol: "xmark.circle.fill", title: "错词", group: "学习主题", colors: [Color(red: 0.94, green: 0.36, blue: 0.36), Color(red: 0.82, green: 0.20, blue: 0.24)]),
            FinderIconOption(id: "review", symbol: "arrow.triangle.2.circlepath", title: "复习", group: "学习主题", colors: [Color(red: 0.66, green: 0.42, blue: 0.94), Color(red: 0.50, green: 0.26, blue: 0.82)])
        ] }

        /// 系统主题图标：分别呼应 Monet 调色、Space 深空与 Manga 漫画三套视觉系统。
        static var systemOptions: [FinderIconOption] { [
            FinderIconOption(id: "manga", symbol: "scribble.variable", title: "漫画", group: "系统主题", colors: [Color(white: 0.16), Color(white: 0.36)]),
            FinderIconOption(id: "manga-panel", symbol: "rectangle.split.2x1.fill", title: "分镜", group: "系统主题", colors: [Color(white: 0.22), Color(white: 0.44)]),
            FinderIconOption(id: "manga-ink", symbol: "paintbrush.pointed.fill", title: "墨线", group: "系统主题", colors: [Color(white: 0.30), Color(white: 0.12)]),
            FinderIconOption(id: "space", symbol: "moon.stars.fill", title: "深空", group: "系统主题", colors: [Color(red: 0.24, green: 0.26, blue: 0.62), Color(red: 0.10, green: 0.12, blue: 0.34)]),
            FinderIconOption(id: "space-signal", symbol: "antenna.radiowaves.left.and.right", title: "信号", group: "系统主题", colors: [Color(red: 0.22, green: 0.72, blue: 0.86), Color(red: 0.10, green: 0.44, blue: 0.72)]),
            FinderIconOption(id: "space-orbit", symbol: "circle.hexagongrid.fill", title: "轨道", group: "系统主题", colors: [Color(red: 0.42, green: 0.36, blue: 0.86), Color(red: 0.18, green: 0.16, blue: 0.52)]),
            FinderIconOption(id: "monet", symbol: "paintpalette.fill", title: "调色", group: "系统主题", colors: [Color(red: 0.94, green: 0.56, blue: 0.36), Color(red: 0.76, green: 0.36, blue: 0.62)]),
            FinderIconOption(id: "monet-drop", symbol: "drop.fill", title: "颜料", group: "系统主题", colors: [Color(red: 0.40, green: 0.70, blue: 0.92), Color(red: 0.30, green: 0.44, blue: 0.82)]),
            FinderIconOption(id: "folder", symbol: "folder.fill", title: "文件夹", group: "系统主题", colors: [Color(red: 0.52, green: 0.62, blue: 0.86), Color(red: 0.36, green: 0.44, blue: 0.68)]),
            FinderIconOption(id: "grid", symbol: "square.grid.2x2.fill", title: "网格", group: "系统主题", colors: [Color(red: 0.56, green: 0.62, blue: 0.70), Color(red: 0.36, green: 0.42, blue: 0.50)])
        ] }

        static var all: [FinderIconOption] { learningOptions + systemOptions }

        static func option(withID id: String?) -> FinderIconOption? {
            guard let id, !id.isEmpty else { return nil }
            return all.first { $0.id == id }
        }
    }

    private var finderFolderIconMap: [String: String] {
        var map: [String: String] = [:]
        for line in finderFolderIconMapRaw.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty else { continue }
            map[String(parts[0])] = String(parts[1])
        }
        return map
    }

    private func finderIconID(for path: [String]) -> String? {
        guard !path.isEmpty else { return nil }
        return finderFolderIconMap[path.joined(separator: "/")]
    }

    private func setFinderFolderIcon(_ iconID: String?, for path: [String]) {
        guard !path.isEmpty else { return }
        var map = finderFolderIconMap
        let key = path.joined(separator: "/")
        if let iconID, !iconID.isEmpty {
            map[key] = iconID
        } else {
            map.removeValue(forKey: key)
        }
        finderFolderIconMapRaw = map
            .map { "\($0.key)\t\($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    /// 文件夹被移动/重命名后，图标记录跟随新路径。
    private func remapFinderFolderIcons(from source: [String], to destination: [String]) {
        guard !source.isEmpty, !destination.isEmpty else { return }
        let src = source.joined(separator: "/")
        let dst = destination.joined(separator: "/")
        guard src != dst else { return }
        var map = finderFolderIconMap
        var updated: [String: String] = [:]
        for (key, value) in Array(map) {
            if key == src {
                updated[dst] = value
                map.removeValue(forKey: key)
            } else if key.hasPrefix(src + "/") {
                let tail = String(key.dropFirst(src.count + 1))
                updated[dst + "/" + tail] = value
                map.removeValue(forKey: key)
            }
        }
        for (key, value) in updated { map[key] = value }
        finderFolderIconMapRaw = map
            .map { "\($0.key)\t\($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    private func removeFinderFolderIcons(atOrUnder path: [String]) {
        guard !path.isEmpty else { return }
        let prefix = path.joined(separator: "/")
        var map = finderFolderIconMap
        for key in map.keys where key == prefix || key.hasPrefix(prefix + "/") {
            map.removeValue(forKey: key)
        }
        finderFolderIconMapRaw = map
            .map { "\($0.key)\t\($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    /// 根据文件夹名称推荐一个学习主题图标；用户未手动选择时自动跟随名称变化。
    private func recommendedFinderIconID(for name: String) -> String? {
        let lower = name.lowercased()
        let rules: [(String, String)] = [
            ("漫画", "manga"), ("manga", "manga"), ("分镜", "manga-panel"),
            ("租房", "housing"), ("住宿", "housing"), ("housing", "housing"), ("rent", "housing"),
            ("写作", "writing"), ("作文", "writing"), ("writing", "writing"), ("essay", "writing"),
            ("听力", "listening"), ("listening", "listening"), ("audio", "listening"),
            ("阅读", "reading"), ("reading", "reading"), ("book", "reading"),
            ("口语", "speaking"), ("speaking", "speaking"), ("speak", "speaking"),
            ("词汇", "vocab"), ("单词", "vocab"), ("vocab", "vocab"), ("word", "vocab"),
            ("语法", "grammar"), ("grammar", "grammar"),
            ("旅行", "travel"), ("旅游", "travel"), ("travel", "travel"), ("trip", "travel"),
            ("工作", "work"), ("求职", "work"), ("work", "work"), ("job", "work"),
            ("研究", "research"), ("学术", "research"), ("research", "research"),
            ("生态", "ecology"), ("环境", "ecology"), ("ecology", "ecology"),
            ("商业", "business"), ("经济", "business"), ("business", "business"),
            ("文化", "culture"), ("文化", "culture"), ("culture", "culture"),
            ("科学", "science"), ("science", "science"),
            ("地理", "geography"), ("geography", "geography"),
            ("饮食", "food"), ("food", "food"),
            ("健康", "health"), ("health", "health"),
            ("考试", "exam"), ("exam", "exam"),
            ("错词", "wrong"), ("wrong", "wrong"),
            ("复习", "review"), ("review", "review"),
            ("深空", "space"), ("太空", "space"), ("space", "space"),
            ("剑", "listening"), ("part", "listening"), ("ielts", "listening")
        ]
        for (keyword, icon) in rules where lower.contains(keyword.lowercased()) {
            return icon
        }
        return nil
    }

    private func presentFinderNewFolderEditor(parent: [String]) {
        finderNewFolderParentPath = parent
        finderNewFolderName = ""
        finderIconEditingPath = nil
        finderIconDraft = recommendedFinderIconID(for: "") ?? "folder"
        finderIconUserPicked = false
        showFinderNewFolderSheet = true
    }

    private func presentFinderFolderIconEditor(path: [String], name: String) {
        finderNewFolderParentPath = Array(path.dropLast())
        finderNewFolderName = name
        finderIconEditingPath = path
        finderIconDraft = finderIconID(for: path) ?? recommendedFinderIconID(for: name) ?? "folder"
        finderIconUserPicked = true
        showFinderNewFolderSheet = true
    }

    private func dismissFinderFolderEditor() {
        showFinderNewFolderSheet = false
        finderIconEditingPath = nil
        finderNewFolderName = ""
        finderIconDraft = ""
        finderIconUserPicked = false
    }

    private func commitFinderFolderEditor() {
        if let path = finderIconEditingPath {
            setFinderFolderIcon(finderIconDraft.isEmpty ? nil : finderIconDraft, for: path)
            dismissFinderFolderEditor()
            return
        }
        let clean = finderNewFolderName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "·")
            .replacingOccurrences(of: "|", with: "·")
        guard !clean.isEmpty else { return }
        addCustomFinderFolder(parentPath: finderNewFolderParentPath, folderName: clean)
        let newPath = finderNewFolderParentPath + [clean]
        if !finderIconDraft.isEmpty {
            setFinderFolderIcon(finderIconDraft, for: newPath)
        }
        dismissFinderFolderEditor()
    }

    private func finderIconChoiceCell(_ option: FinderIconOption) -> some View {
        let theme = dictTheme
        let selected = (finderIconDraft == option.id)
        return Button {
            finderIconDraft = option.id
            finderIconUserPicked = true
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: finderIconDisplayColors(option),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        Image(systemName: option.symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? theme.accent : Color.clear, lineWidth: 2.5)
                    )
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.accent)
                            .background(Circle().fill(theme.paper))
                            .offset(x: 5, y: -5)
                    }
                }
                Text(option.title)
                    .font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? theme.accent : theme.ink.opacity(0.72))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? theme.selected : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(option.title)
    }

    private var finderFolderEditorView: some View {
        let theme = dictTheme
        let isIconOnly = (finderIconEditingPath != nil)
        let targetPath = finderIconEditingPath ?? finderNewFolderParentPath
        let chosen = FinderIconCatalog.option(withID: finderIconDraft) ?? FinderIconCatalog.all[0]
        let recommendedOption = FinderIconCatalog.option(withID: recommendedFinderIconID(for: finderNewFolderName))
        let locationText = targetPath.isEmpty ? "根目录" : targetPath.joined(separator: " › ")
        let canCommit = isIconOnly || !finderNewFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: finderIconDisplayColors(chosen),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: finderIconDisplayColors(chosen).first?.opacity(0.32) ?? Color.clear, radius: 8, x: 0, y: 3)
                    Image(systemName: chosen.symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isIconOnly ? "更换文件夹图标" : "新建文件夹")
                        .lumaFont(size: 20, weight: .bold, design: .serif)
                        .foregroundStyle(theme.ink)
                    Text(locationText)
                        .lumaFont(size: 11.5, weight: .medium)
                        .foregroundStyle(dictTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    dismissFinderFolderEditor()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.ink.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(theme.surface.opacity(0.8)))
                }
                .buttonStyle(.plain)
                .help("关闭")
            }

            if !isIconOnly {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    TextField("文件夹名称（如 03_高频易错词 / 剑18真题）", text: $finderNewFolderName)
                        .textFieldStyle(.plain)
                        .lumaFont(size: 13.5)
                        .foregroundStyle(theme.ink)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(theme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(theme.line, lineWidth: 1)
                )
                .onChange(of: finderNewFolderName) { _, newValue in
                    guard !finderIconUserPicked, let id = recommendedFinderIconID(for: newValue) else { return }
                    finderIconDraft = id
                }

                if let recommendedOption {
                    Button {
                        finderIconDraft = recommendedOption.id
                        finderIconUserPicked = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11, weight: .semibold))
                            Text("推荐：\(recommendedOption.title)")
                                .lumaFont(size: 11.5, weight: .medium)
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(theme.selected))
                    }
                    .buttonStyle(.plain)
                    .help("按文件夹名称自动匹配的图标")
                }
            }

            Divider().overlay(theme.line.opacity(0.5))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(["学习主题", "系统主题"], id: \.self) { group in
                        let options = (group == "学习主题") ? FinderIconCatalog.learningOptions : FinderIconCatalog.systemOptions
                        VStack(alignment: .leading, spacing: 9) {
                            Text(group)
                                .lumaFont(size: 12, weight: .semibold)
                                .foregroundStyle(theme.ink.opacity(0.66))
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                                spacing: 8
                            ) {
                                ForEach(options) { option in
                                    finderIconChoiceCell(option)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                if isIconOnly {
                    Button {
                        setFinderFolderIcon(nil, for: finderIconEditingPath ?? [])
                        dismissFinderFolderEditor()
                    } label: {
                        Text("恢复默认")
                            .lumaFont(size: 12, weight: .medium)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 32))
                }

                Spacer()

                Button {
                    dismissFinderFolderEditor()
                } label: {
                    Text("取消")
                        .lumaFont(size: 12.5, weight: .medium)
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 16, height: 32))

                Button {
                    commitFinderFolderEditor()
                } label: {
                    Text(isIconOnly ? "保存" : "创建")
                        .lumaFont(size: 12.5, weight: .semibold)
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 18, height: 32))
                .disabled(!canCommit)
                .opacity(canCommit ? 1 : 0.45)
            }
        }
        .padding(22)
        .frame(width: 640, height: 680)
        .background(theme.paper)
    }

    private var finderRedirectMap: [String: String] {
        var map: [String: String] = [:]
        for pair in finderFolderRedirectsRaw.split(separator: "|") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty {
                map[parts[0]] = parts[1]
            }
        }
        return map
    }

    private typealias FinderMoveRule = LumaFinderMoveRule

    /// 以“最长路径优先”的顺序排列移动规则，保证多级文件夹连续移动时不会错位。
    private var finderMoveRules: [FinderMoveRule] {
        LumaFinderPath.rules(from: finderRedirectMap)
    }

    /// 把原始三级路径按移动规则折叠到当前真实位置。反复迭代以支持“移动后的文件夹再次被移动”。
    private func resolveFinderPath(_ path: [String], rules: [FinderMoveRule]) -> [String] {
        LumaFinderPath.resolve(path, rules: rules)
    }

    private func moveFinderFolder(sourcePath: [String], intoTargetParent targetParentPath: [String]) {
        guard !sourcePath.isEmpty else { return }
        let rules = finderMoveRules
        let resolvedSource = resolveFinderPath(sourcePath, rules: rules)
        let resolvedTarget = resolveFinderPath(targetParentPath, rules: rules)
        // 与访达一致：不能把文件夹拖进它自己或它的子文件夹。
        guard resolvedSource != resolvedTarget,
              !resolvedTarget.starts(with: resolvedSource) else { return }
        guard let folderName = sourcePath.last else { return }
        let newPath = targetParentPath + [folderName]
        guard newPath != sourcePath else { return }

        let srcStr = sourcePath.joined(separator: "/")
        let dstStr = newPath.joined(separator: "/")

        // Update custom folders if applicable
        var custom = customFinderFolderPaths.map { p -> [String] in
            let pStr = p.joined(separator: "/")
            if pStr == srcStr { return newPath }
            if pStr.hasPrefix(srcStr + "/") {
                let tail = String(pStr.dropFirst(srcStr.count + 1)).split(separator: "/").map(String.init)
                return newPath + tail
            }
            return p
        }
        if !custom.contains(newPath) {
            custom.append(newPath)
        }
        finderCustomFoldersRaw = custom.map { $0.joined(separator: "/") }.joined(separator: "|")

        // Record redirect so built-in 3-level paths also move seamlessly
        var redirects = finderRedirectMap
        redirects[srcStr] = dstStr
        for (k, v) in redirects {
            if v == srcStr { redirects[k] = dstStr }
            else if v.hasPrefix(srcStr + "/") {
                redirects[k] = dstStr + String(v.dropFirst(srcStr.count))
            }
        }
        finderFolderRedirectsRaw = redirects.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "|")
        remapFinderFolderIcons(from: sourcePath, to: newPath)
    }

    private func renameFinderFolder(path: [String], to newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "·").replacingOccurrences(of: "|", with: "·")
        guard !clean.isEmpty, !path.isEmpty else { return }
        var newPath = Array(path.dropLast())
        newPath.append(clean)
        guard newPath != path else { return }

        let srcStr = path.joined(separator: "/")
        let dstStr = newPath.joined(separator: "/")

        let custom = customFinderFolderPaths.map { p -> [String] in
            let pStr = p.joined(separator: "/")
            if pStr == srcStr { return newPath }
            if pStr.hasPrefix(srcStr + "/") {
                let tail = String(pStr.dropFirst(srcStr.count + 1)).split(separator: "/").map(String.init)
                return newPath + tail
            }
            return p
        }
        finderCustomFoldersRaw = custom.map { $0.joined(separator: "/") }.joined(separator: "|")

        var redirects = finderRedirectMap
        redirects[srcStr] = dstStr
        for (k, v) in redirects {
            if v == srcStr { redirects[k] = dstStr }
            else if v.hasPrefix(srcStr + "/") {
                redirects[k] = dstStr + String(v.dropFirst(srcStr.count))
            }
        }
        finderFolderRedirectsRaw = redirects.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "|")
        remapFinderFolderIcons(from: path, to: newPath)

        if finderCurrentPath == path {
            finderCurrentPath = newPath
        }
    }

    /// 计算某个词在三级文件夹体系中的完整 3 级路径：[一级分类(Part 1), 二级场景(租房场景), 三级细分词本(01_租房场景词汇)]
    private func effectiveThreeLevelPath(for word: VocabularyWord, indexInDeck: Int,
                                         moveRules: [FinderMoveRule], categoryByDeck: [String: String]) -> [String] {
        let deckID = word.deckID
        if let custom = word.folderPath, custom.count >= 2 {
            return resolveFinderPath(custom, rules: moveRules)
        }
        let l1 = categoryByDeck[deckID] ?? categoryForDeck(deckID)
        let l2 = word.deckTitle.isEmpty ? (BundledCoraVocabulary.defaultTitleByDeckID[deckID] ?? deckID) : word.deckTitle
        let l3: String = {
            let ex = word.exampleSentence
            if !ex.isEmpty, ex.contains("_") {
                return ex
            }
            switch deckID {
            case "ielts.p1.renting": return indexInDeck < 144 ? "01_租房场景词汇" : "02_租房机经词汇"
            case "ielts.p1.work": return indexInDeck < 106 ? "01_工作场景词汇" : "02_工作机经词汇"
            case "ielts.p1.travel": return indexInDeck < 91 ? "01_旅游活动场景词汇" : "02_旅游活动机经词汇"
            case "ielts.p1.inquiry": return indexInDeck < 128 ? "01_咨询问询场景词汇" : "02_询问问询机经词汇"
            case "ielts.p2.map": return indexInDeck < 68 ? "01_地图题方位核心词" : "02_选择题重点词汇"
            case "ielts.p2.travel": return indexInDeck < 50 ? "01_旅游场景机经词汇" : "02_配对题旅游重点词汇"
            case "ielts.p2.work":
                if indexInDeck < 49 { return "01_工作场景机经词汇" }
                if indexInDeck < 185 { return "02_配对题工作及翻新重点词" }
                return "03_五选二重点词汇"
            case "ielts.p3.research": return indexInDeck < 71 ? "01_课题研究机经词汇" : "02_课题研究重点词汇"
            case "ielts.p3.assignment": return indexInDeck < 71 ? "01_作业讨论机经词汇" : "02_作业讨论重点词汇"
            case "ielts.p4.ecology": return indexInDeck < 80 ? "01_生态环境机经词汇" : "02_生态环境重点词汇"
            case "ielts.p4.business": return indexInDeck < 36 ? "01_商业场景机经词汇" : "02_商业环境重点词汇"
            case "ielts.p4.geography": return indexInDeck < 45 ? "01_地理环境机经词汇" : "02_地理环境重点词汇"
            case "ielts.p4.society": return indexInDeck < 54 ? "01_人文社会及其他机经词汇" : "02_人文社会重点词汇"
            default:
                return "01_\(l2)核心词"
            }
        }()

        return resolveFinderPath([l1, l2, l3], rules: moveRules)
    }

    /// 汇总当前所有文件夹路径及其对应的单词表
    private var finderHierarchyIndex: (allFolderPaths: [[String]], wordsByFolderPath: [String: [VocabularyWord]]) {
        let byDeck = vm.fastWordsByDeck
        let decks = visibleListeningDeckIDs
        let categories = orderedListeningCategories
        return vm.cachedFinderHierarchy(words:byDeck, decks:decks, categories:categories,
                                        categoryMap:deckCategoryMapRaw, folders:finderCustomFoldersRaw,
                                        redirects:finderFolderRedirectsRaw, wordFolders:finderWordFolderMapRaw) {
        let moveRules = finderMoveRules
        let categoryByDeck = Dictionary(uniqueKeysWithValues:decks.map { ($0, categoryForDeck($0)) })
        var folderSet: Set<String> = []
        var orderedPaths: [[String]] = []
        var wordsMap: [String: [VocabularyWord]] = [:]

        func registerPath(_ p: [String]) {
            guard !p.isEmpty else { return }
            for depth in 1...p.count {
                let prefix = Array(p.prefix(depth))
                let key = prefix.joined(separator: "/")
                if folderSet.insert(key).inserted {
                    orderedPaths.append(prefix)
                }
            }
        }

        // 1. Register built-in Level 1 categories in user's order (resolve moves so the old shell disappears)
        for cat in categories {
            registerPath(resolveFinderPath([cat], rules: moveRules))
        }

        // 2. Register all words & their 3-level paths
        for deck in decks {
            let dWords = byDeck[deck] ?? []
            for (idx, w) in dWords.enumerated() {
                let p = effectiveThreeLevelPath(for:w, indexInDeck:idx, moveRules:moveRules, categoryByDeck:categoryByDeck)
                registerPath(p)
                for depth in 1...p.count {
                    let key = Array(p.prefix(depth)).joined(separator: "/")
                    wordsMap[key, default: []].append(w)
                }
            }
        }

        // 3. Register user-created custom nested folders (even empty ones, at any level!)
        for customPath in customFinderFolderPaths {
            registerPath(customPath)
        }

        return (orderedPaths, wordsMap)
        }
    }

    private func finderChildFolders(under parentPath: [String], index: (allFolderPaths: [[String]], wordsByFolderPath: [String: [VocabularyWord]])) -> [FinderFolderItem] {
        let targetDepth = parentPath.count + 1
        let matching = index.allFolderPaths.filter {
            $0.count == targetDepth && Array($0.dropLast()) == parentPath
        }
        let customSet = Set(customFinderFolderPaths.map { $0.joined(separator: "/") })
        let q = finderSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        return matching.enumerated().compactMap { idx, p in
            let name = p.last ?? ""
            if !q.isEmpty && !parentPath.joined(separator: "/").localizedCaseInsensitiveContains(q) {
                let subMatch = index.allFolderPaths.contains {
                    $0.starts(with: p) && $0.joined(separator: "/").localizedCaseInsensitiveContains(q)
                }
                let wordMatch = (index.wordsByFolderPath[p.joined(separator: "/")] ?? []).contains {
                    $0.word.localizedCaseInsensitiveContains(q) || $0.definitionZH.localizedCaseInsensitiveContains(q)
                }
                if !name.localizedCaseInsensitiveContains(q) && !subMatch && !wordMatch {
                    return nil
                }
            }
            let key = p.joined(separator: "/")
            let wCount = index.wordsByFolderPath[key]?.count ?? 0
            let badgeName: String = {
                if name.contains("_") { return name }
                return String(format: "%02d_%@", idx + 1, name)
            }()
            return FinderFolderItem(
                name: name,
                displayBadgeName: badgeName,
                path: p,
                totalWordCount: wCount,
                isCustom: customSet.contains(key) && wCount == 0
            )
        }
    }

    private func finderNavigate(to newPath: [String]) {
        guard newPath != finderCurrentPath else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            finderCurrentPath = newPath
            if finderHistoryIndex < finderPathHistory.count - 1 {
                finderPathHistory = Array(finderPathHistory.prefix(finderHistoryIndex + 1))
            }
            finderPathHistory.append(newPath)
            finderHistoryIndex = finderPathHistory.count - 1
            if let first = newPath.first {
                finderCol1Selected = first
            }
            if newPath.count >= 2 {
                finderCol2Selected = newPath[1]
            }
            if newPath.count >= 3 {
                finderCol3Selected = newPath[2]
            } else {
                finderCol3Selected = nil
            }
        }
    }

    private func startDictationForFolder(path: [String], words: [VocabularyWord]) {
        guard let firstWord = words.first else { return }
        if path.count == 2, words.allSatisfy({ $0.deckID == firstWord.deckID }) {
            selectDeckAndStartDictation(deck: firstWord.deckID, mode: .newTask, resume: true)
            mode = "学习_听力_今日计划"
            answerFocused = true
            return
        }
        let folderTitle = path.isEmpty ? "全部听力分类" : path.joined(separator: " · ")
        vm.dictationMachine = DictationSessionStateMachine(
            mode: .newTask,
            dateString: Self.todayDateString(),
            initialWords: words,
            existingStubbornWordsForToday: vm.storeSnapshot.stubbornWords,
            previousLogs: vm.storeSnapshot.dictationLogs
        )
        vm.showMeaning = globalDefaultShowMeaning
        vm.revealedWordID = nil
        showFirstLetterHint = globalDefaultShowHint
        vm.dictationInput = ""
        vm.dictationFeedback = "正在听写文件夹《\(folderTitle)》（共 \(words.count) 词）"
        vm.scheduleSave(after: 0.4)
        mode = "学习_听力_今日计划"
        scheduleDictationPlayback()
        answerFocused = true
    }

    /// 莫奈动态取色 + 液态玻璃质感 3D 访达文件夹图标组件（随主题、书封莫奈取色与毛玻璃开关实时联动）
    private func macOSFinderFolderGraphic(isDropTargeted: Bool = false, isSubfolder: Bool = false) -> some View {
        let theme = dictTheme
        let dark = theme.isDark
        let useGlass = theme.glassEnabled
        let backTabTint = theme.accent.opacity(dark ? 0.58 : 0.48)
        let frontTopTint = theme.accent.opacity(dark ? 0.82 : 0.74)
        let frontBottomTint = theme.accent.opacity(dark ? 0.46 : 0.38)

        return ZStack(alignment: .bottom) {
            // 1. 文件夹后背板 + 左上角莫奈色标签页
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 8,
                        style: .continuous
                    )
                    .fill(
                        LinearGradient(
                            colors: [backTabTint, theme.surface.opacity(dark ? 0.85 : 0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 9)
                    Spacer()
                }
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [backTabTint, theme.surface.opacity(dark ? 0.78 : 0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 58)
            }
            .frame(width: 96, height: 67)

            // 2. 文件夹内部微露的莫奈纸张夹层
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(theme.paper.opacity(dark ? 0.78 : 0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(theme.accent.opacity(0.28), lineWidth: 0.7)
                )
                .frame(width: 82, height: 50)
                .offset(y: -7)

            // 3. 前置液态毛玻璃 + 莫奈渐变前袋
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(useGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [frontTopTint, frontBottomTint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .frame(width: 96, height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(dark ? 0.42 : 0.68),
                                    theme.accent.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isDropTargeted ? 1.8 : 1.0
                        )
                )
                .shadow(color: theme.accent.opacity(dark ? 0.28 : 0.18), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(isDropTargeted ? 1.08 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isDropTargeted)
    }

    /// 专门的「听力 · 三级分类」文件管理器界面（完全融合莫奈取色与液态玻璃，无左侧多余边栏按键）
        // === PROJECT RED LINE / 项目红线 BEGIN ===
    // 听力分类布局（三级文件夹、面包屑导航、视图切换与一键听写）与错词复习布局必须严格保护。
    // Preserve listening category hierarchy, view modes, and wrong words review layout without modification.
    // === PROJECT RED LINE / 项目红线 END ===
    private var listeningCategoriesDedicatedView: some View {
        let theme = dictTheme
        let index = finderHierarchyIndex
        let currentKey = finderCurrentPath.joined(separator: "/")
        let childFolders = finderChildFolders(under: finderCurrentPath, index: index)
        let currentFolderWords: [VocabularyWord] = {
            let base = finderCurrentPath.isEmpty
                ? visibleListeningDeckIDs.flatMap { vm.fastWordsByDeck[$0] ?? [] }
                : (index.wordsByFolderPath[currentKey] ?? [])
            let q = finderSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return base }
            return base.filter {
                $0.word.localizedCaseInsensitiveContains(q)
                    || $0.definitionZH.localizedCaseInsensitiveContains(q)
                    || $0.deckTitle.localizedCaseInsensitiveContains(q)
            }
        }()
        let currentTitle = finderCurrentPath.last ?? "听力分类"

        return deckManagement(
            VStack(alignment: .leading, spacing: 18) {
                // MARK: 1. 顶部标题与莫奈液态玻璃胶囊工具栏（与「词库」页完全统一，无左侧多余边栏）
                HStack(alignment: .center, spacing: 12) {
                    // 前进 / 后退 / 返回上级液态玻璃胶囊
                    HStack(spacing: 2) {
                        Button {
                            if finderHistoryIndex > 0 {
                                finderHistoryIndex -= 1
                                finderCurrentPath = finderPathHistory[finderHistoryIndex]
                            } else if !finderCurrentPath.isEmpty {
                                finderNavigate(to: Array(finderCurrentPath.dropLast()))
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.ink)
                                .frame(width: 32, height: 34)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(finderHistoryIndex <= 0 && finderCurrentPath.isEmpty)
                        .opacity((finderHistoryIndex > 0 || !finderCurrentPath.isEmpty) ? 0.92 : 0.35)
                        .help("后退 / 返回上一级文件夹")

                        Rectangle()
                            .fill(theme.line)
                            .frame(width: 1, height: 16)

                        Button {
                            guard finderHistoryIndex < finderPathHistory.count - 1 else { return }
                            finderHistoryIndex += 1
                            finderCurrentPath = finderPathHistory[finderHistoryIndex]
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.ink)
                                .frame(width: 32, height: 34)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(finderHistoryIndex >= finderPathHistory.count - 1)
                        .opacity(finderHistoryIndex < finderPathHistory.count - 1 ? 0.92 : 0.35)
                        .help("前进")
                    }
                    .padding(.horizontal, 4)
                    .studyGlassCapsule(cornerRadius: 19)

                    if !finderCurrentPath.isEmpty {
                        Button {
                            finderNavigate(to: Array(finderCurrentPath.dropLast()))
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.turn.left.up")
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text("上级")
                                    .lumaFont(size: 12.5, weight: .medium)
                            }
                        }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 34))
                        .help("返回上一级文件夹")
                    }

                    Text(currentTitle)
                        .lumaFont(size: 28, weight: .bold, design: .serif)
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength:8)

                    // 视图切换液态玻璃胶囊（图标 / 分栏 / 列表）
                    HStack(spacing: 2) {
                        ForEach([("icons", "square.grid.2x2", "图标网格"), ("columns", "rectangle.split.3x1", "三级分栏"), ("list", "list.bullet", "树形列表")], id: \.0) { modeID, iconName, label in
                            let isModeSel = (finderViewMode == modeID)
                            Button {
                                // 1.9.5: never cross-fade two huge folder views; the
                                // overlap looked like ghosted, unreadable rows.
                                var transaction = Transaction(); transaction.disablesAnimations = true
                                withTransaction(transaction) { finderViewMode = modeID }
                            } label: {
                                Image(systemName: iconName)
                                    .font(.system(size: 13, weight: isModeSel ? .semibold : .medium))
                                    .frame(width:32, height:30)
                                .foregroundStyle(isModeSel ? dictOnAccent : theme.ink.opacity(0.84))
                                .frame(height: 30)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isModeSel ? theme.accent : Color.clear)
                                )
                                .contentShape(Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .help(label)
                            .accessibilityLabel(label)
                            .accessibilityAddTraits(isModeSel ? .isSelected : [])
                        }
                    }
                    .fixedSize()
                    .padding(4)
                    .studyGlassCapsule(cornerRadius: 19)

                    // 一体化搜索 + 新建子文件夹 + 听写胶囊（对齐「词库」页右上角胶囊设计）
                    HStack(spacing: 4) {
                        HStack(spacing: 7) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(dictTextSecondary)
                            TextField("搜索文件夹或单词", text: $finderSearchQuery)
                                .textFieldStyle(.plain)
                                .lumaFont(size: 13)
                                .foregroundStyle(theme.ink)
                            if !finderSearchQuery.isEmpty {
                                Button {
                                    finderSearchQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(dictTextSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 6)
                        .frame(width: 175, height: 36)

                        Rectangle()
                            .fill(theme.line)
                            .frame(width: 1, height: 18)
                            .padding(.horizontal, 2)

                        Button {
                            presentFinderNewFolderEditor(parent: finderCurrentPath)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 13, weight: .semibold))

                            }
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .contentShape(Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("新建文件夹")
                        .accessibilityLabel("新建文件夹")

                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .studyGlassCapsule(cornerRadius: 22)
                }

                // MARK: 2. 莫奈液态玻璃路径面包屑导航条（支持点击任意层级跳转，也支持将文件夹拖到任意路径节点归类）
                HStack(spacing: 6) {
                    Button {
                        finderNavigate(to: [])
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 11.5))
                                .foregroundStyle(theme.accent)
                            Text("全部听力分类")
                                .font(.system(size: 12.5, weight: finderCurrentPath.isEmpty ? .semibold : .medium))
                                .foregroundStyle(finderCurrentPath.isEmpty ? theme.accent : theme.ink)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(finderCurrentPath.isEmpty ? theme.selected : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .dropDestination(for: String.self) { items, _ in
                        guard let first = items.first, first.hasPrefix("luma-finder-folder:") else { return false }
                        let src = String(first.dropFirst("luma-finder-folder:".count)).split(separator: "/").map(String.init)
                        moveFinderFolder(sourcePath: src, intoTargetParent: [])
                        return true
                    }

                    ForEach(Array(finderCurrentPath.enumerated()), id: \.offset) { depthIdx, seg in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(dictTextSecondary)
                        let targetSlice = Array(finderCurrentPath.prefix(depthIdx + 1))
                        let isLast = (depthIdx == finderCurrentPath.count - 1)
                        Button {
                            finderNavigate(to: targetSlice)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: categoryBadgeMeta(for: seg, path: targetSlice).symbol)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(theme.accent)
                                Text(seg)
                                    .font(.system(size: 12.5, weight: isLast ? .semibold : .medium))
                                    .foregroundStyle(isLast ? theme.accent : theme.ink)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isLast ? theme.selected : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .dropDestination(for: String.self) { items, _ in
                            guard let first = items.first, first.hasPrefix("luma-finder-folder:") else { return false }
                            let src = String(first.dropFirst("luma-finder-folder:".count)).split(separator: "/").map(String.init)
                            moveFinderFolder(sourcePath: src, intoTargetParent: targetSlice)
                            return true
                        }
                    }

                    Spacer()

                    if !currentFolderWords.isEmpty {
                        Button {
                            startDictationForFolder(path: finderCurrentPath, words: currentFolderWords)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "headphones")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("全部听写 (\(currentFolderWords.count))")
                                    .font(.system(size: 12.5, weight: .semibold))
                            }
                            .foregroundStyle(dictOnAccent)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Capsule(style: .continuous).fill(theme.accent))
                        }
                        .buttonStyle(.plain)
                        .help(finderCurrentPath.isEmpty ? "听写全部 \(currentFolderWords.count) 个单词" : "听写当前文件夹全部 \(currentFolderWords.count) 个单词")
                        .padding(.trailing, 2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .studyGlassCapsule(cornerRadius: 16)
                .background(theme.paper)
                .zIndex(1)

                // MARK: 3. 主文件管理器画布（完全融合莫奈取色与液态玻璃，无左侧多余边栏）
                Group {
                    if finderViewMode == "columns" {
                        finderThreeColumnBrowserView(index: index)
                    } else if finderViewMode == "list" {
                        finderExpandableListView(index: index)
                    } else {
                        finderIconGridView(childFolders: childFolders, currentFolderWords: currentFolderWords, index: index)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollClipDisabled(false)
                .clipped()
            }
            .padding(.horizontal, 32)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .background(theme.paper)
            .sheet(isPresented: $showFinderNewFolderSheet) {
                finderFolderEditorView
            }
            .alert("重命名文件夹", isPresented: $showFinderRenameAlert) {
                TextField("输入新名称", text: $finderRenameInput)
                Button("取消", role: .cancel) {
                    finderRenamingPath = nil
                }
                Button("保存") {
                    if let target = finderRenamingPath {
                        renameFinderFolder(path: target, to: finderRenameInput)
                    }
                    finderRenamingPath = nil
                }
            }
            .onAppear {
                #if DEBUG
                let env = ProcessInfo.processInfo.environment
                if let rawPath = env["LUMA_DEBUG_FINDER_PATH"], !rawPath.isEmpty, finderCurrentPath.isEmpty {
                    let parts = rawPath.split(separator: "/").map(String.init)
                    if !parts.isEmpty { finderNavigate(to: parts) }
                }
                if env["LUMA_DEBUG_FINDER_ICON_SHEET"] == "1" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        presentFinderNewFolderEditor(parent: finderCurrentPath)
                    }
                }
                #endif
            }
        )
    }

    // MARK: - 视图模式 1：莫奈液态玻璃大图标网格视图（模仿访达 01_Part 1 / 02_Part 2 立体文件夹矩阵）

    
    /// 图标底色跟随当前视觉系统与莫奈取色：粉色主题下所有文件夹徽标都是同族粉色，
    /// 而不是固定彩虹色。SF Symbol 仍保留各自的语义，便于区分。
    private func finderIconDisplayColors(_ option: FinderIconOption?) -> [Color] {
        let theme = dictTheme
        switch theme.visualThemeSystem {
        case "manga":
            return [theme.ink, theme.ink.opacity(0.55)]
        case "space":
            return [theme.accent, theme.surface]
        case "nier", "wasteland":
            // 战术/终端主题：徽标保持单色，与界面一致。
            return [theme.accent, theme.ink.opacity(0.45)]
        default:
            // Monet：由当前主色（或莫奈取色结果）推导渐变，保留一档明暗层次。
            return [theme.accent, theme.accent.opacity(0.52)]
        }
    }

    private func categoryBadgeMeta(for name: String, path: [String] = []) -> (symbol: String, colors: [Color], desc: String) {
        let original: (symbol: String, colors: [Color], desc: String)
        if let custom = FinderIconCatalog.option(withID: finderIconID(for: path)) {
            original = (custom.symbol, custom.colors, custom.title)
        } else {
            original = monetCategoryBadgeMeta(for: name)
        }
        return (original.symbol, finderIconDisplayColors(FinderIconCatalog.option(withID: finderIconID(for: path))), original.desc)
    }
    private func monetCategoryBadgeMeta(for name: String) -> (symbol: String, colors: [Color], desc: String) {
        if name.contains("Part 1") {
            return ("bubble.left.and.bubble.right.fill", [Color(red: 0.98, green: 0.42, blue: 0.52), Color(red: 0.95, green: 0.28, blue: 0.45)], "日常与社交生活核心场景")
        } else if name.contains("Part 2") {
            return ("building.columns.fill", [Color(red: 0.22, green: 0.75, blue: 0.55), Color(red: 0.14, green: 0.62, blue: 0.42)], "公共场所与文化导览场景")
        } else if name.contains("Part 3") {
            return ("graduationcap.fill", [Color(red: 0.28, green: 0.55, blue: 0.96), Color(red: 0.16, green: 0.42, blue: 0.88)], "学术研讨与课程论文讨论")
        } else if name.contains("Part 4") {
            return ("waveform.and.mic", [Color(red: 0.68, green: 0.36, blue: 0.95), Color(red: 0.52, green: 0.20, blue: 0.86)], "专业学科与学术独白讲座")
        } else if name.contains("租房") || name.contains("住宿") {
            return ("house.fill", [Color(red: 0.98, green: 0.52, blue: 0.35), Color(red: 0.92, green: 0.38, blue: 0.22)], "住宿类型与租约条款词汇")
        } else if name.contains("工作") || name.contains("求职") {
            return ("briefcase.fill", [Color(red: 0.38, green: 0.52, blue: 0.95), Color(red: 0.28, green: 0.38, blue: 0.85)], "求职应聘与职场交流词汇")
        } else if name.contains("旅游") || name.contains("地图") {
            return ("map.fill", [Color(red: 0.18, green: 0.72, blue: 0.65), Color(red: 0.12, green: 0.58, blue: 0.52)], "行程指引与地理方位词汇")
        } else if name.contains("生态") || name.contains("环境") {
            return ("leaf.fill", [Color(red: 0.35, green: 0.75, blue: 0.32), Color(red: 0.25, green: 0.62, blue: 0.22)], "自然动植物与环保科学")
        } else if name.contains("商业") || name.contains("经济") {
            return ("chart.pie.fill", [Color(red: 0.95, green: 0.35, blue: 0.58), Color(red: 0.85, green: 0.25, blue: 0.48)], "市场营销与企业商业分析")
        }
        return ("folder.fill", [dictTheme.accent.opacity(0.85), dictTheme.accent], "雅思核心高频词汇分类")
    }

    private func finderIconGridView(
        childFolders: [FinderFolderItem],
        currentFolderWords: [VocabularyWord],
        index: (allFolderPaths: [[String]], wordsByFolderPath: [String: [VocabularyWord]])
    ) -> some View {
        let theme = dictTheme
        let dark = theme.isDark
        return ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                if !childFolders.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 290), spacing: 20)], alignment: .leading, spacing: 20) {
                        ForEach(childFolders) { folder in
                            let isTargeted = (finderDropTargetPath == folder.id)
                            let meta = categoryBadgeMeta(for: folder.name, path: folder.path)
                            let fWords = index.wordsByFolderPath[folder.id] ?? []

                            VStack(alignment: .leading, spacing: 14) {
                                // 顶部：高雅微拟物渐变图标徽标 + 词数胶囊
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: meta.colors,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 44, height: 44)
                                            .shadow(color: meta.colors.first?.opacity(0.35) ?? Color.clear, radius: 8, x: 0, y: 3)
                                        Image(systemName: meta.symbol)
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                    }

                                    Spacer()

                                    // 词数胶囊
                                    HStack(spacing: 4) {
                                        Image(systemName: "text.book.closed")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text("\(folder.totalWordCount) 词")
                                            .lumaFont(size: 11.5, weight: .semibold, design: .rounded, monospacedDigits: true)
                                    }
                                    .foregroundStyle(theme.accent)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(theme.selected))
                                    .overlay(Capsule().strokeBorder(theme.accent.opacity(0.24), lineWidth: 0.8))
                                }

                                // 标题与层级说明
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 5) {
                                        Text(folder.displayBadgeName)
                                            .lumaFont(size: 16, weight: .bold, design: .rounded)
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        if folder.isCustom {
                                            Image(systemName: "pencil.circle")
                                                .font(.system(size: 11))
                                                .foregroundStyle(theme.accent.opacity(0.75))
                                        }
                                    }


                                }

                                Divider().overlay(theme.line.opacity(0.35))

                                // 底部快捷操作栏：直接一键听写 + 进入分类提示
                                HStack(alignment: .center, spacing: 8) {
                                    if !fWords.isEmpty {
                                        Button {
                                            startDictationForFolder(path: folder.path, words: fWords)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "headphones")
                                                    .font(.system(size: 10.5, weight: .bold))
                                                Text("一键听写")
                                                    .lumaFont(size: 11.5, weight: .semibold)
                                                    .lineLimit(1)
                                                    .fixedSize(horizontal:true, vertical:false)
                                            }
                                            .foregroundStyle(dictOnAccent)
                                            .padding(.horizontal, 11)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(theme.accent))
                                        }
                                        .buttonStyle(.plain)
                                        .help("直接开始本分类全部单词听写")
                                    }

                                    Spacer()

                                    HStack(spacing: 3) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9.5, weight: .semibold))
                                            .foregroundStyle(dictTextSecondary)
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .studyGlassCapsule(cornerRadius: 18, selected: isTargeted)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(isTargeted ? theme.accent : theme.line.opacity(dark ? 0.35 : 0.65), lineWidth: isTargeted ? 1.5 : 0.9)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onTapGesture {
                                finderNavigate(to: folder.path)
                            }
                            .draggable("luma-finder-folder:" + folder.id)
                            .dropDestination(for: String.self) { items, _ in
                                guard let first = items.first else { return false }
                                if first.hasPrefix("luma-finder-folder:") {
                                    let draggedID = String(first.dropFirst("luma-finder-folder:".count))
                                    let draggedPath = draggedID.split(separator: "/").map(String.init)
                                    moveFinderFolder(sourcePath: draggedPath, intoTargetParent: folder.path)
                                    return true
                                } else if first.hasPrefix("luma-deck:") {
                                    let draggedDeck = String(first.dropFirst("luma-deck:".count))
                                    if let rootCat = folder.path.first {
                                        assignDeck(draggedDeck, toCategory: rootCat)
                                    }
                                    return true
                                }
                                return false
                            } isTargeted: { targeted in
                                finderDropTargetPath = targeted ? folder.id : (finderDropTargetPath == folder.id ? nil : finderDropTargetPath)
                            }
                            .contextMenu {
                                Button("打开分类文件夹", systemImage: "folder") {
                                    finderNavigate(to: folder.path)
                                }
                                Button("在此分类内新建子文件夹…", systemImage: "folder.badge.plus") {
                                    presentFinderNewFolderEditor(parent: folder.path)
                                }
                                Button("更换图标…", systemImage: "square.grid.2x2") {
                                    presentFinderFolderIconEditor(path: folder.path, name: folder.name)
                                }
                                if !fWords.isEmpty {
                                    Button("🎧 听写此分类全部单词 (\(fWords.count) 词)", systemImage: "headphones") {
                                        startDictationForFolder(path: folder.path, words: fWords)
                                    }
                                }
                                Divider()
                                Button("重命名分类…", systemImage: "character.cursor.ibeam") {
                                    finderRenamingPath = folder.path
                                    finderRenameInput = folder.name
                                    showFinderRenameAlert = true
                                }
                                if folder.path.count >= 2 {
                                    Button("移出到上一级目录", systemImage: "arrow.up.backward.square") {
                                        let parentOfParent = Array(folder.path.dropLast(2))
                                        moveFinderFolder(sourcePath: folder.path, intoTargetParent: parentOfParent)
                                    }
                                }
                                if folder.isCustom || !BundledCoraVocabulary.defaultCategories.contains(folder.name) {
                                    Divider()
                                    Button("删除分类文件夹", systemImage: "trash", role: .destructive) {
                                        deleteCustomFinderFolder(path: folder.path)
                                    }
                                }
                            }
                        }
                    }
                }

                // 网格视图保持访达式简洁：只展示子文件夹，不再在下方铺开整页单词明细表。
                if !finderCurrentPath.isEmpty && childFolders.isEmpty && currentFolderWords.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "folder")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(dictTextSecondary.opacity(0.7))
                        Text("此文件夹为空")
                            .lumaFont(size: 13, weight: .medium)
                            .foregroundStyle(dictTextSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - 视图模式 2：莫奈液态玻璃三级分栏浏览器（一级分类 ▸ 二级场景 ▸ 三级子文件夹）

    private func finderThreeColumnBrowserView(
        index: (allFolderPaths: [[String]], wordsByFolderPath: [String: [VocabularyWord]])
    ) -> some View {
        let theme = dictTheme
        let col1Folders = finderChildFolders(under: [], index: index)
        let activeL1 = col1Folders.contains(where: { $0.name == finderCol1Selected }) ? finderCol1Selected : (col1Folders.first?.name ?? "Part 1")
        let col2Folders = finderChildFolders(under: [activeL1], index: index)
        let activeL2: String? = {
            if let sel = finderCol2Selected, col2Folders.contains(where: { $0.name == sel }) { return sel }
            return col2Folders.first?.name
        }()
        let col3Folders: [FinderFolderItem] = {
            guard let activeL2 else { return [] }
            return finderChildFolders(under: [activeL1, activeL2], index: index)
        }()
        let activeL3: String? = {
            if let sel = finderCol3Selected, col3Folders.contains(where: { $0.name == sel }) { return sel }
            return nil
        }()
        return HStack(spacing: 0) {
            // 第一栏：一级分类文件夹 (Part 1 ~ Part 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        finderNewFolderParentPath = []
                        finderNewFolderName = ""
                        showFinderNewFolderSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("新建文件夹")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                Divider().overlay(theme.line)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(col1Folders) { f1 in
                            let isSel = (activeL1 == f1.name)
                            Button {
                                finderCol1Selected = f1.name
                                finderCol2Selected = finderChildFolders(under: [f1.name], index: index).first?.name
                                finderCol3Selected = nil
                                finderCurrentPath = [f1.name]
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: categoryBadgeMeta(for: f1.name, path: [f1.name]).symbol)
                                        .foregroundStyle(theme.accent)
                                    Text(f1.name)
                                        .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                                        .foregroundStyle(theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundStyle(dictTextSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(isSel ? theme.selected : Color.clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(minWidth: 180, maxWidth: .infinity)

            Divider().overlay(theme.line)

            // 第二栏：二级场景文件夹 (租房场景 / 工作场景 / 旅游活动场景 / 问询咨询场景...)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        finderNewFolderParentPath = [activeL1]
                        finderNewFolderName = ""
                        showFinderNewFolderSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("在 \(activeL1) 下新建子文件夹")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                Divider().overlay(theme.line)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(col2Folders) { f2 in
                            let isSel = (activeL2 == f2.name)
                            Button {
                                finderCol2Selected = f2.name
                                finderCol3Selected = nil
                                finderCurrentPath = [activeL1, f2.name]
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: categoryBadgeMeta(for: f2.name, path: [activeL1, f2.name]).symbol)
                                        .foregroundStyle(theme.accent)
                                    Text(f2.name)
                                        .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                                        .foregroundStyle(theme.ink)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(f2.totalWordCount)词")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(dictTextSecondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundStyle(dictTextSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(isSel ? theme.selected : Color.clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(minWidth: 200, maxWidth: .infinity)

            Divider().overlay(theme.line)

            // 第三栏：三级子文件夹 (场景词汇 / 机经词汇 / 重点词汇 / 自定义三级子文件夹)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    if let activeL2 {
                        Button {
                            finderNewFolderParentPath = [activeL1, activeL2]
                            finderNewFolderName = ""
                            showFinderNewFolderSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption.bold())
                                .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                        .help("在 \(activeL2) 下新建子文件夹")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                Divider().overlay(theme.line)

                ScrollView {
                    VStack(spacing: 4) {
                        if let activeL2 {
                            let allL2Count = index.wordsByFolderPath["\(activeL1)/\(activeL2)"]?.count ?? 0
                            Button {
                                finderCol3Selected = nil
                                finderCurrentPath = [activeL1, activeL2]
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "tray.full.fill")
                                        .foregroundStyle(theme.accent)
                                    Text("全部《\(activeL2)》")
                                        .font(.system(size: 12.5, weight: activeL3 == nil ? .semibold : .regular))
                                        .foregroundStyle(theme.ink)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(allL2Count)词")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(dictTextSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(activeL3 == nil ? theme.selected : Color.clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(col3Folders) { f3 in
                            let isSel = (activeL3 == f3.name)
                            Button {
                                finderCol3Selected = f3.name
                                if let activeL2 {
                                    finderCurrentPath = [activeL1, activeL2, f3.name]
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: categoryBadgeMeta(for: f3.name, path: [activeL1, activeL2 ?? "", f3.name]).symbol)
                                        .foregroundStyle(theme.accent)
                                    Text(f3.name)
                                        .font(.system(size: 12.5, weight: isSel ? .semibold : .regular))
                                        .foregroundStyle(theme.ink)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(f3.totalWordCount)词")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(dictTextSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(isSel ? theme.selected : Color.clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(minWidth: 220, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .studyGlassCapsule(cornerRadius: 20)
    }

    private struct FinderTreeRowSurface: ViewModifier {
        let theme: StudyAppearance
        let radius: CGFloat
        var selected = false

        func body(content: Content) -> some View {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            content
                .background {
                    shape.fill(selected ? theme.selected : theme.surface)
                        .overlay(shape.fill(LinearGradient(
                            colors: [.white.opacity(theme.isDark ? 0.055 : 0.28), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )))
                }
                .overlay(shape.strokeBorder(theme.line, lineWidth: 1).allowsHitTesting(false))
        }
    }

    // MARK: - 视图模式 3：莫奈液态玻璃可展开三级树形列表视图

    private struct StudyScrollCapsuleButtonStyle: ButtonStyle {
        let theme: StudyAppearance
        let onAccent: Color
        var prominent = false
        var selected = false
        let horizontalPadding: CGFloat
        let height: CGFloat
        @State private var hovered = false

        func makeBody(configuration: Configuration) -> some View {
            let shape = Capsule()
            configuration.label
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .font(.system(size: 13, weight: prominent ? .semibold : .medium))
                .foregroundStyle(prominent ? onAccent : theme.ink)
                .padding(.horizontal, horizontalPadding)
                .frame(minHeight: height)
                .background(shape.fill(prominent ? theme.accent : theme.selected))
                .overlay(shape.strokeBorder(selected || hovered ? theme.accent : theme.line, lineWidth: 1).allowsHitTesting(false))
                .opacity(configuration.isPressed ? 0.8 : 1)
                .contentShape(shape)
                .onHover { hovered = $0 }
        }
    }

    private func finderExpandableListView(
        index: (allFolderPaths: [[String]], wordsByFolderPath: [String: [VocabularyWord]])
    ) -> some View {
        let theme = dictTheme
        let rootFolders = finderChildFolders(under: [], index: index)
        return ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(rootFolders) { l1 in
                    let l1Expanded = finderExpandedPaths.contains(l1.id)
                    HStack(spacing: 10) {
                        LumaDisclosureChevron(expanded: l1Expanded, size: 30, tint: theme.ink) {
                            if l1Expanded { finderExpandedPaths.remove(l1.id) }
                            else { finderExpandedPaths.insert(l1.id) }
                        }
                        .help(l1Expanded ? "折叠 \(l1.name)" : "展开 \(l1.name)")

                        Image(systemName: categoryBadgeMeta(for: l1.name, path: l1.path).symbol)
                            .foregroundStyle(theme.accent)
                        Text(l1.name)
                            .lumaFont(size: 14.5, weight: .semibold)
                            .foregroundStyle(theme.ink)
                        Spacer()
                        Text("\(l1.totalWordCount) 词")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(dictTextSecondary)
                        Button("打开") { finderNavigate(to: l1.path); finderViewMode = "icons" }
                            .buttonStyle(StudyScrollCapsuleButtonStyle(theme: theme, onAccent: dictOnAccent, horizontalPadding: 12, height: 28))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .modifier(FinderTreeRowSurface(theme: theme, radius: 14, selected: l1Expanded))

                    if l1Expanded {
                        let l2Folders = finderChildFolders(under: l1.path, index: index)
                        ForEach(l2Folders) { l2 in
                            let l2Expanded = finderExpandedPaths.contains(l2.id)
                            HStack(spacing: 10) {
                                LumaDisclosureChevron(expanded: l2Expanded, size: 26, tint: theme.ink) {
                                    if l2Expanded { finderExpandedPaths.remove(l2.id) }
                                    else { finderExpandedPaths.insert(l2.id) }
                                }
                                .help(l2Expanded ? "折叠 \(l2.name)" : "展开 \(l2.name)")

                                Image(systemName: categoryBadgeMeta(for: l2.name, path: l2.path).symbol)
                                    .foregroundStyle(theme.accent.opacity(0.88))
                                Text(l2.name)
                                    .lumaFont(size: 13.5, weight: .medium)
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                Text("\(l2.totalWordCount) 词")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(dictTextSecondary)
                                Button("进入") { finderNavigate(to: l2.path); finderViewMode = "icons" }
                                    .buttonStyle(StudyScrollCapsuleButtonStyle(theme: theme, onAccent: dictOnAccent, horizontalPadding: 10, height: 26))
                                if let wList = index.wordsByFolderPath[l2.id], !wList.isEmpty {
                                    Button("听写") { startDictationForFolder(path: l2.path, words: wList) }
                                        .buttonStyle(StudyScrollCapsuleButtonStyle(theme: theme, onAccent: dictOnAccent, prominent: true, horizontalPadding: 10, height: 26))
                                }
                            }
                            .padding(.leading, 32)
                            .padding(.trailing, 14)
                            .padding(.vertical, 8)
                            .modifier(FinderTreeRowSurface(theme: theme, radius: 12))

                            if l2Expanded {
                                let l3Folders = finderChildFolders(under: l2.path, index: index)
                                ForEach(l3Folders) { l3 in
                                    HStack(spacing: 10) {
                                        Image(systemName: categoryBadgeMeta(for: l3.name, path: l3.path).symbol)
                                            .font(.system(size: 12))
                                            .foregroundStyle(theme.accent.opacity(0.78))
                                        Text(l3.name)
                                            .lumaFont(size: 13)
                                            .foregroundStyle(theme.ink)
                                        Spacer()
                                        Text("\(l3.totalWordCount) 词")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(dictTextSecondary)
                                        Button("查看单词") { finderNavigate(to: l3.path); finderViewMode = "icons" }
                                            .buttonStyle(StudyScrollCapsuleButtonStyle(theme: theme, onAccent: dictOnAccent, horizontalPadding: 10, height: 24))
                                        if let w3List = index.wordsByFolderPath[l3.id], !w3List.isEmpty {
                                            Button("听写") { startDictationForFolder(path: l3.path, words: w3List) }
                                                .buttonStyle(StudyScrollCapsuleButtonStyle(theme: theme, onAccent: dictOnAccent, prominent: true, horizontalPadding: 10, height: 24))
                                        }
                                    }
                                    .padding(.leading, 58)
                                    .padding(.trailing, 14)
                                    .padding(.vertical, 7)
                                    .modifier(FinderTreeRowSurface(theme: theme, radius: 10))
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled(false)
        .mask(Rectangle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 当前文件夹内单词表组件（莫奈液态玻璃卡片）

    private func finderFolderWordsTableSection(words: [VocabularyWord], overridePath: [String]? = nil) -> some View {
        let theme = dictTheme
        let activePath = overridePath ?? finderCurrentPath
        let displayLimit = showAllCategoryWords ? words.count : min(words.count, categoryWordLimit)
        let slice = Array(words.prefix(displayLimit))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("当前文件夹单词明细（\(activePath.joined(separator: " › ")) · 共 \(words.count) 词）", systemImage: "list.bullet.rectangle.portrait")
                    .lumaFont(size: 15, weight: .bold)
                    .foregroundStyle(theme.ink)
                Spacer()
                if !words.isEmpty {
                    Button {
                        startDictationForFolder(path: activePath, words: words)
                    } label: {
                        Label("🎧 听写本文件夹全部 \(words.count) 词", systemImage: "play.fill")
                            .lumaFont(size: 12.5, weight: .semibold)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 30))
                }
            }

            if words.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(dictTextSecondary)
                    Text("此文件夹当前为空")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(dictTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(Array(slice.enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 12) {
                            Text("#\(idx + 1)")
                                .lumaFont(size: 11, weight: .medium, design: .monospaced)
                                .foregroundStyle(dictTextSecondary)
                                .frame(width: 40, alignment: .leading)

                            Text(item.word)
                                .lumaFont(size: 15.5, weight: .bold, design: .serif)
                                .foregroundStyle(theme.ink)
                                .frame(minWidth: 160, alignment: .leading)

                            Text(item.definitionZH)
                                .lumaFont(size: 13.5, weight: .medium)
                                .foregroundStyle(theme.accent)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                speakArbitraryWord(item.word)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 11.5))
                                    Text("发音")
                                        .lumaFont(size: 11, weight: .medium)
                                }
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(theme.selected))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.surface.opacity(0.65)))
                    }

                    if words.count > displayLimit {
                        HStack(spacing: 10) {
                            Button("继续加载 120 词（已显示 \(displayLimit) / \(words.count)）") {
                                categoryWordLimit += 120
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))

                            Button("展开全部 (\(words.count) 词)") {
                                showAllCategoryWords = true
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 32))
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
        .padding(18)
        .studyGlassCapsule(cornerRadius: 18)
    }

    /// 「查看单词」的紧凑弹窗：单词 + 释义 + 发音，可搜索并直接开始听写。
    private var listeningWordQuickPanel: some View {
        let allDeckIDs = selectedScenarioPreviewDeckID.map { [$0] } ?? filteredListeningDeckIDs
        let primaryDeck = selectedScenarioPreviewDeckID ?? filteredListeningDeckIDs.first
        let title: String = {
            guard let primaryDeck, allDeckIDs.count == 1 else {
                return selectedListeningCategory == "全部" ? "全部听力词库" : selectedListeningCategory
            }
            return deckTitle(for: primaryDeck)
        }()
        let allWords = allDeckIDs.flatMap { vm.fastWordsByDeck[$0] ?? [] }
        let q = categoryWordSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = q.isEmpty ? allWords : allWords.filter {
            $0.word.localizedCaseInsensitiveContains(q)
                || $0.definitionZH.localizedCaseInsensitiveContains(q)
        }
        let displayLimit = (showAllCategoryWords || !q.isEmpty) ? words.count : min(words.count, categoryWordLimit)
        let slice = Array(words.prefix(displayLimit))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(appearance.accent.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(appearance.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .lumaFont(size: 16, weight: .bold, design: .serif)
                        .foregroundStyle(appearance.ink)
                        .lineLimit(1)
                    Text("共 \(allWords.count) 词")
                        .lumaFont(size: 11.5)
                        .foregroundStyle(appearance.ink.opacity(0.55))
                }
                Spacer(minLength: 8)

                if let primaryDeck, allDeckIDs.count == 1, !allWords.isEmpty {
                    Button {
                        showListeningCategoryWordBrowser = false
                        selectDeckAndStartDictation(deck: primaryDeck, mode: .newTask, resume: true)
                        mode = "学习_听力_今日计划"
                        answerFocused = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "headphones")
                                .font(.system(size: 11, weight: .semibold))
                            Text("开始听写")
                                .lumaFont(size: 12, weight: .semibold)
                        }
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 12, height: 30))
                }

                Button {
                    showListeningCategoryWordBrowser = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(appearance.ink.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(appearance.surface.opacity(0.8)))
                }
                .buttonStyle(.plain)
                .help("关闭")
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(appearance.ink.opacity(0.5))
                TextField("搜索单词或中文释义", text: $categoryWordSearchQuery)
                    .textFieldStyle(.plain)
                    .lumaFont(size: 12.5)
                    .foregroundStyle(appearance.ink)
                if !categoryWordSearchQuery.isEmpty {
                    Button {
                        categoryWordSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11.5))
                            .foregroundStyle(appearance.ink.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(appearance.paper.opacity(0.65)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(appearance.line.opacity(0.7), lineWidth: 0.8))

            if words.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(appearance.ink.opacity(0.35))
                    Text(allWords.isEmpty ? "这个词库还没有单词" : "没有匹配「\(categoryWordSearchQuery)」的单词")
                        .lumaFont(size: 12.5)
                        .foregroundStyle(appearance.ink.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(slice.enumerated()), id: \.element.id) { idx, item in
                            HStack(spacing: 10) {
                                Text("\(idx + 1)")
                                    .lumaFont(size: 10.5, weight: .medium, design: .monospaced)
                                    .foregroundStyle(appearance.ink.opacity(0.35))
                                    .frame(width: 30, alignment: .trailing)

                                Text(item.word)
                                    .lumaFont(size: 14.5, weight: .semibold, design: .serif)
                                    .foregroundStyle(appearance.ink)
                                    .frame(minWidth: 130, alignment: .leading)
                                    .lineLimit(1)

                                Text(item.definitionZH.isEmpty ? "—" : item.definitionZH)
                                    .lumaFont(size: 12.5)
                                    .foregroundStyle(appearance.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)

                                Button {
                                    speakArbitraryWord(item.word)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(appearance.accent)
                                        .frame(width: 26, height: 26)
                                        .background(Circle().fill(appearance.selected))
                                }
                                .buttonStyle(.plain)
                                .help("朗读「\(item.word)」")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(idx.isMultiple(of: 2) ? appearance.paper.opacity(0.42) : Color.clear)
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                if words.count > displayLimit {
                    Button {
                        categoryWordLimit += 120
                    } label: {
                        Text("继续加载 120 词（已显示 \(displayLimit) / 共 \(words.count) 词）")
                            .lumaFont(size: 11.5, weight: .medium)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 28))
                }
            }
        }
        .padding(18)
        .frame(width: 720, height: 560)
        .background(appearance.background)
    }

    // MARK: - 听力分类与场景单词库全部单词一览（点击 Part 1 ~ Part 4 或场景卡片直接查看全部单词）

    private var listeningCategoryWordExplorerSection: some View {
        let categoryDecks = filteredListeningDeckIDs
        let activePreviewDeck: String? = {
            if let sel = selectedScenarioPreviewDeckID, categoryDecks.contains(sel) {
                return sel
            }
            return nil
        }()
        let explorerWordsByDeck = vm.fastWordsByDeck
        let orderedTargetDecks = activePreviewDeck != nil ? [activePreviewDeck!] : categoryDecks
        let rawWords: [VocabularyWord] = orderedTargetDecks.flatMap { explorerWordsByDeck[$0] ?? [] }
        let q = categoryWordSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingWords: [VocabularyWord] = q.isEmpty ? rawWords : rawWords.filter {
            $0.word.localizedCaseInsensitiveContains(q)
                || $0.definitionZH.localizedCaseInsensitiveContains(q)
                || $0.deckTitle.localizedCaseInsensitiveContains(q)
        }
        let wrongCountByWordID: [String: Int] = {
            var counts: [String: Int] = [:]
            for log in vm.storeSnapshot.dictationLogs where !log.isCorrect {
                counts[log.wordID, default: 0] += 1
            }
            return counts
        }()
        let correctWordIDs: Set<String> = Set(vm.storeSnapshot.dictationLogs.filter { $0.isCorrect }.map(\.wordID))
        let headerTitle: String = {
            if let activePreviewDeck {
                let dTitle = deckTitle(for: activePreviewDeck)
                let dCat = categoryForDeck(activePreviewDeck)
                return "\(dCat) · 《\(dTitle)》全部单词（共 \(rawWords.count) 词）"
            } else if selectedListeningCategory == "全部" {
                return "全部听力词库单词总览（\(categoryDecks.count) 个场景词本 · 共 \(rawWords.count) 词）"
            } else {
                return "\(selectedListeningCategory) · 全部场景单词库总览（\(categoryDecks.count) 个场景 · 共 \(rawWords.count) 词）"
            }
        }()
        let primaryActionDeck = activePreviewDeck ?? categoryDecks.first ?? vm.selectedDeck

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.book.closed.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(appearance.accent)
                        Text(headerTitle)
                            .lumaFont(size: 18, weight: .bold, design: .serif)
                            .foregroundStyle(appearance.ink)
                    }
                }

                Spacer()

                if isImportedDeck(primaryActionDeck) {
                    Button {
                        deckEditing = LumaDeckEditTarget(id: primaryActionDeck, title: deckTitle(for: primaryActionDeck))
                    } label: {
                        Label("编辑《\(deckTitle(for: primaryActionDeck))》词条", systemImage: "square.and.pencil")
                            .lumaFont(size: 12.5, weight: .medium)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 32))
                }

                Button {
                    selectDeckAndStartDictation(deck: primaryActionDeck, mode: .newTask, resume: true)
                    mode = "学习_听力_今日计划"
                    answerFocused = true
                } label: {
                    Label("听写《\(deckTitle(for: primaryActionDeck))》", systemImage: "headphones")
                        .lumaFont(size: 12.5, weight: .semibold)
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 16, height: 32))

                Button {
                    withAnimation(.easeOut(duration: 0.14)) {
                        showListeningCategoryWordBrowser = false
                    }
                } label: {
                    Label("收起", systemImage: "chevron.up")
                        .lumaFont(size: 12, weight: .medium)
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
            }

            // 二级场景词本快速切换栏 + 单词搜索框
            HStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let allCatCount = categoryDecks.reduce(0) { $0 + (explorerWordsByDeck[$1]?.count ?? 0) }
                        Button {
                            withAnimation(.easeOut(duration: 0.14)) {
                                selectedScenarioPreviewDeckID = nil
                                showAllCategoryWords = false
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(selectedListeningCategory == "全部" ? "全部场景词库" : "全部 \(selectedListeningCategory) 单词")
                                    .lumaFont(size: 12.5, weight: .semibold)
                                Text("(\(allCatCount))")
                                    .font(.caption2.monospacedDigit())
                                    .opacity(0.8)
                            }
                        }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: activePreviewDeck == nil, selected: activePreviewDeck == nil, horizontalPadding: 12, height: 30))

                        ForEach(categoryDecks, id: \.self) { deck in
                            let isDeckSel = (activePreviewDeck == deck)
                            let dWordsCount = explorerWordsByDeck[deck]?.count ?? 0
                            Button {
                                withAnimation(.easeOut(duration: 0.14)) {
                                    selectedScenarioPreviewDeckID = isDeckSel ? nil : deck
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(deckTitle(for: deck))
                                        .font(.system(size: 12.5, weight: isDeckSel ? .semibold : .medium))
                                    Text("(\(dWordsCount))")
                                        .font(.caption2.monospacedDigit())
                                        .opacity(0.8)
                                }
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: isDeckSel, selected: isDeckSel, horizontalPadding: 12, height: 30))
                        }
                    }
                    .padding(.vertical, 2)
                }

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(appearance.ink.opacity(0.55))
                    TextField("搜索本分类英文单词或中文释义…", text: $categoryWordSearchQuery)
                        .textFieldStyle(.plain)
                        .lumaFont(size: 12.5)
                        .foregroundStyle(appearance.ink)
                    if !categoryWordSearchQuery.isEmpty {
                        Button {
                            categoryWordSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(appearance.ink.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(width: 240, height: 32)
                .studyGlassCapsule(cornerRadius: 16)
            }

            if matchingWords.isEmpty {
                Text("未找到匹配「\(categoryWordSearchQuery)」的单词。")
                    .lumaFont(size: 13.5)
                    .foregroundStyle(appearance.ink.opacity(0.6))
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                let displayLimit = (showAllCategoryWords || !q.isEmpty) ? matchingWords.count : min(matchingWords.count, categoryWordLimit)
                let displayedWords = Array(matchingWords.prefix(displayLimit))
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(displayedWords.enumerated()), id: \.element.id) { idx, item in
                            let errCount = wrongCountByWordID[item.id] ?? 0
                            let isMastered = correctWordIDs.contains(item.id) && errCount == 0
                            let sTitle = item.deckTitle.isEmpty ? deckTitle(for: item.deckID) : item.deckTitle
                            HStack(spacing: 14) {
                                Text("#\(idx + 1)")
                                    .lumaFont(size: 11.5, weight: .medium, design: .monospaced)
                                    .foregroundStyle(appearance.ink.opacity(0.45))
                                    .frame(width: 42, alignment: .leading)

                                Text(item.word)
                                    .lumaFont(size: 16, weight: .bold, design: .serif)
                                    .foregroundStyle(appearance.ink)
                                    .frame(minWidth: 165, alignment: .leading)

                                Text(item.definitionZH.isEmpty ? "—" : item.definitionZH)
                                    .lumaFont(size: 14, weight: .medium)
                                    .foregroundStyle(appearance.accent)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    withAnimation(.easeOut(duration: 0.14)) {
                                        selectedScenarioPreviewDeckID = item.deckID
                                    }
                                } label: {
                                    Text("\(categoryForDeck(item.deckID)) · \(sTitle)")
                                        .lumaFont(size: 11, weight: .medium)
                                        .foregroundStyle(appearance.ink.opacity(0.75))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(appearance.paper.opacity(0.65)))
                                }
                                .buttonStyle(.plain)
                                .help("点击仅筛选《\(sTitle)》的单词")

                                if errCount > 0 {
                                    Text("错 \(errCount) 次")
                                        .lumaFont(size: 11, weight: .semibold, monospacedDigits: true)
                                        .foregroundStyle(Color.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.red.opacity(0.14)))
                                } else if isMastered {
                                    Text("✓ 已掌握")
                                        .lumaFont(size: 11, weight: .semibold)
                                        .foregroundStyle(appearance.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(appearance.selected))
                                }

                                Button {
                                    speakArbitraryWord(item.word)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 12))
                                        Text("发音")
                                            .lumaFont(size: 11.5, weight: .medium)
                                    }
                                    .foregroundStyle(appearance.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(appearance.selected))
                                }
                                .buttonStyle(.plain)
                                .help("立即朗读「\(item.word)」")

                                Button {
                                    selectDeckAndStartDictation(deck: item.deckID, mode: .newTask, resume: true)
                                    mode = "学习_听力_今日计划"
                                    answerFocused = true
                                } label: {
                                    Image(systemName: "headphones")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(appearance.ink.opacity(0.78))
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(appearance.paper.opacity(0.65)))
                                }
                                .buttonStyle(.plain)
                                .help("进入《\(sTitle)》开始听写")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(appearance.paper.opacity(0.55))
                            )
                        }
                        if matchingWords.count > displayLimit {
                            HStack(spacing: 12) {
                                Button {
                                    categoryWordLimit += 120
                                } label: {
                                    Text("继续加载 120 词（已显示 \(displayLimit) / 共 \(matchingWords.count) 词）")
                                        .lumaFont(size: 13, weight: .semibold)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 18, height: 34))

                                Button {
                                    showAllCategoryWords = true
                                } label: {
                                    Text("展开全部 (\(matchingWords.count) 词)")
                                        .lumaFont(size: 13, weight: .medium)
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 16, height: 34))
                            }
                            .padding(.top, 6)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 320, maxHeight: 520)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(appearance.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(appearance.accent.opacity(0.32), lineWidth: 1.0)
                )
        )
    }

    // MARK: - 词库管理（编辑词条 / 重命名 / 删除）

    private func isImportedDeck(_ deck: String) -> Bool {
        let imported: Bool = (vm.storeSnapshot.importedWords ?? []).contains { $0.deckID == deck }
        let builtIn: Bool = Self.builtInVocabularyWords.contains { $0.deckID == deck }
        return imported && !builtIn
    }

    private var pinnedDeckIDs: [String] {
        pinnedDecksRaw.split(separator: "|").map(String.init).filter { !$0.isEmpty }
    }

    private func isDeckPinned(_ deck: String) -> Bool {
        pinnedDeckIDs.contains(deck)
    }

    private func toggleDeckPin(_ deck: String) {
        var current = pinnedDeckIDs
        if let idx = current.firstIndex(of: deck) {
            current.remove(at: idx)
        } else {
            current.insert(deck, at: 0)
        }
        pinnedDecksRaw = current.joined(separator: "|")
    }

    private var customDeckOrderIDs: [String] {
        customDeckOrderRaw.split(separator: "|").map(String.init).filter { !$0.isEmpty }
    }

    private func reorderDeck(draggedDeck: String, targetDeck: String) {
        guard draggedDeck != targetDeck else { return }
        var current = visibleListeningDeckIDs
        guard let fromIdx = current.firstIndex(of: draggedDeck),
              let toIdx = current.firstIndex(of: targetDeck) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            let item = current.remove(at: fromIdx)
            current.insert(item, at: toIdx)
            customDeckOrderRaw = current.joined(separator: "|")
            if isDeckPinned(targetDeck) && !isDeckPinned(draggedDeck) {
                var pins = pinnedDeckIDs
                pins.insert(draggedDeck, at: min(toIdx, pins.count))
                pinnedDecksRaw = pins.joined(separator: "|")
            }
        }
    }

    private func moveDeckRelative(_ deck: String, offset: Int) {
        let current = visibleListeningDeckIDs
        guard let idx = current.firstIndex(of: deck) else { return }
        let targetIdx = min(max(0, idx + offset), max(0, current.count - 1))
        guard targetIdx != idx else { return }
        reorderDeck(draggedDeck: deck, targetDeck: current[targetIdx])
    }

    private var orderedListeningCategories: [String] {
        let saved = listeningCategoriesRaw.split(separator: "|").map(String.init).filter { !$0.isEmpty }
        var result = saved
        for defCat in BundledCoraVocabulary.defaultCategories where !result.contains(defCat) {
            result.append(defCat)
        }
        // 新语料（如「剑20语料库」）即使尚未写入偏好，也出现在分类导航中。
        for cat in Set(visibleListeningDeckIDs.map { categoryForDeck($0) }).sorted() where !result.contains(cat) {
            result.append(cat)
        }
        return result
    }

    private var deckCategoryDictionary: [String: String] {
        var map = BundledCoraVocabulary.defaultCategoryByDeckID
        for pair in deckCategoryMapRaw.split(separator: "|") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, !parts[0].isEmpty {
                map[parts[0]] = parts[1]
            }
        }
        return map
    }

    private func categoryForDeck(_ deck: String) -> String {
        if deckCategoryMapRaw.isEmpty, let defCat = BundledCoraVocabulary.defaultCategoryByDeckID[deck] {
            return defCat
        }
        if let mapped = deckCategoryDictionary[deck], !mapped.isEmpty {
            return mapped
        }
        let lower = deck.lowercased()
        if lower.hasPrefix("luma.c20.") { return "剑20语料库" }
        if lower.contains(".p1.") || lower.contains("part1") { return "Part 1" }
        if lower.contains(".p2.") || lower.contains("part2") { return "Part 2" }
        if lower.contains(".p3.") || lower.contains("part3") { return "Part 3" }
        if lower.contains(".p4.") || lower.contains("part4") { return "Part 4" }
        return "Part 1"
    }

    private func assignDeck(_ deck: String, toCategory category: String) {
        var map = deckCategoryDictionary
        map[deck] = category
        deckCategoryMapRaw = map.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "|")
    }

    private func reorderListeningCategory(dragged: String, target: String) {
        guard dragged != target else { return }
        var cats = orderedListeningCategories
        guard let fromIdx = cats.firstIndex(of: dragged),
              let toIdx = cats.firstIndex(of: target) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            let item = cats.remove(at: fromIdx)
            cats.insert(item, at: toIdx)
            listeningCategoriesRaw = cats.joined(separator: "|")
        }
    }

    private func moveListeningCategoryRelative(_ cat: String, offset: Int) {
        let cats = orderedListeningCategories
        guard let idx = cats.firstIndex(of: cat) else { return }
        let targetIdx = min(max(0, idx + offset), max(0, cats.count - 1))
        guard targetIdx != idx else { return }
        reorderListeningCategory(dragged: cat, target: cats[targetIdx])
    }

    private func saveListeningCategoryName() {
        let clean = listeningCategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var cats = orderedListeningCategories
        if let oldName = editingListeningCategoryOldName, let idx = cats.firstIndex(of: oldName) {
            cats[idx] = clean
            listeningCategoriesRaw = cats.joined(separator: "|")
            var map = deckCategoryDictionary
            for (k, v) in map where v == oldName {
                map[k] = clean
            }
            deckCategoryMapRaw = map.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "|")
            if selectedListeningCategory == oldName {
                selectedListeningCategory = clean
            }
        } else {
            if !cats.contains(clean) {
                cats.append(clean)
                listeningCategoriesRaw = cats.joined(separator: "|")
            }
            if let deck = pendingDeckForNewCategory {
                assignDeck(deck, toCategory: clean)
            }
            selectedListeningCategory = clean
        }
        editingListeningCategoryOldName = nil
        pendingDeckForNewCategory = nil
        listeningCategoryNameInput = ""
    }

    private func deleteListeningCategory(_ cat: String) {
        guard !BundledCoraVocabulary.defaultCategories.contains(cat) else { return }
        let cats = orderedListeningCategories.filter { $0 != cat }
        listeningCategoriesRaw = cats.joined(separator: "|")
        var map = deckCategoryDictionary
        for (k, v) in map where v == cat {
            map[k] = "Part 1"
        }
        deckCategoryMapRaw = map.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "|")
        if selectedListeningCategory == cat {
            selectedListeningCategory = "全部"
        }
    }

    private var filteredListeningDeckIDs: [String] {
        let q = deckSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return visibleListeningDeckIDs.filter { deck in
            let catMatch = (selectedListeningCategory == "全部") || (categoryForDeck(deck) == selectedListeningCategory)
            guard catMatch else { return false }
            guard !q.isEmpty else { return true }
            let title = deckTitle(for: deck)
            return title.localizedStandardContains(q) || categoryForDeck(deck).localizedStandardContains(q)
        }
    }

    @ViewBuilder
    private func deckActions(_ deck: String) -> some View {
        Button(isDeckPinned(deck) ? "取消置顶" : "置顶词库", systemImage: isDeckPinned(deck) ? "pin.slash" : "pin.fill") {
            toggleDeckPin(deck)
        }
        Button("前移位置", systemImage: "arrow.up.left") {
            moveDeckRelative(deck, offset: -1)
        }
        Button("后移位置", systemImage: "arrow.down.right") {
            moveDeckRelative(deck, offset: 1)
        }
        Menu("分类") {
            ForEach(orderedListeningCategories, id: \.self) { cat in
                Button {
                    assignDeck(deck, toCategory: cat)
                } label: {
                    Label(cat, systemImage: categoryForDeck(deck) == cat ? "checkmark" : "folder")
                }
            }
            Divider()
            Button("新建分类…") {
                editingListeningCategoryOldName = nil
                listeningCategoryNameInput = ""
                pendingDeckForNewCategory = deck
                showListeningCategoryEditor = true
            }
        }
        if isImportedDeck(deck) {
            Divider()
            Button("编辑词条…", systemImage: "square.and.pencil") {
                deckEditing = LumaDeckEditTarget(id: deck, title: deckTitle(for: deck))
            }
            Button("重命名…", systemImage: "character.cursor.ibeam") {
                deckRenameText = deckTitle(for: deck)
                deckToRename = deck
            }
            Divider()
            Button("删除词库…", systemImage: "trash", role: .destructive) {
                deckToDelete = deck
            }
        }
    }

    private func deckManagement<Content: View>(_ content: Content) -> some View {
        content
            .sheet(item: $deckEditing) { target in
                LumaVocabularyDeckEditorSheet(
                    deckID: target.id,
                    deckTitle: target.title,
                    originalWords: (vm.storeSnapshot.importedWords ?? []).filter { $0.deckID == target.id },
                    onSave: { words in saveEditedDeck(target.id, words: words) }
                )
            }
            .alert("重命名词库", isPresented: Binding(get: { deckToRename != nil }, set: { if !$0 { deckToRename = nil } })) {
                TextField("词库名称", text: $deckRenameText)
                Button("重命名") {
                    if let deck = deckToRename { renameDeck(deck, to: deckRenameText) }
                    deckToRename = nil
                }
                Button("取消", role: .cancel) { deckToRename = nil }
            }
            .alert("删除这个词库？", isPresented: Binding(get: { deckToDelete != nil }, set: { if !$0 { deckToDelete = nil } })) {
                Button("删除词库", role: .destructive) {
                    if let deck = deckToDelete { deleteDeck(deck) }
                    deckToDelete = nil
                }
                Button("取消", role: .cancel) { deckToDelete = nil }
            } message: {
                Text("词库中的单词会被移除，已有的听写记录和顽固单词记录会保留。")
            }
            .alert(editingListeningCategoryOldName == nil ? "新建听力分类" : "重命名听力分类", isPresented: $showListeningCategoryEditor) {
                TextField("分类名称（如 Part 1 / 高频场景）", text: $listeningCategoryNameInput)
                Button("取消", role: .cancel) {
                    editingListeningCategoryOldName = nil
                    pendingDeckForNewCategory = nil
                }
                Button("保存") {
                    saveListeningCategoryName()
                }
            }
    }

    private func renameDeck(_ deck: String, to newTitle: String) {
        let title: String = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let words: [VocabularyWord] = vm.storeSnapshot.importedWords ?? []
        vm.invalidateVocabCache(); vm.storeSnapshot.importedWords = words.map { w in
            guard w.deckID == deck else { return w }
            return VocabularyWord(id: w.id, word: w.word, phoneticUK: w.phoneticUK, phoneticUS: w.phoneticUS, partOfSpeech: w.partOfSpeech, definitionZH: w.definitionZH, exampleSentence: w.exampleSentence, deckID: w.deckID, deckTitle: title)
        }
        vm.save()
    }

    private func deleteDeck(_ deck: String) {
        let activeDeck: String = vm.dictationMachine.currentWord?.deckID ?? vm.selectedDeck
        vm.invalidateVocabCache(); vm.storeSnapshot.importedWords = (vm.storeSnapshot.importedWords ?? []).filter { $0.deckID != deck }
        if let sessions = vm.storeSnapshot.dictationSessions {
            vm.storeSnapshot.dictationSessions = sessions.filter { !$0.key.hasSuffix("|" + deck) }
        }
        if vm.selectedDeck == deck || activeDeck == deck {
            vm.selectedDeck = visibleListeningDeckIDs.first ?? "vocab_daily"
            if visibleListeningDeckIDs.isEmpty {
                ttsEngine.stop(); audio.stop(); kokoro.stop()
            } else {
                startDictation(mode: .newTask, resume: true)
            }
        }
        vm.save()
    }

    private func saveEditedDeck(_ deck: String, words: [VocabularyWord]) -> String? {
        let activeDeck: String = vm.dictationMachine.currentWord?.deckID ?? vm.selectedDeck
        var existing: [VocabularyWord] = (vm.storeSnapshot.importedWords ?? []).filter { $0.deckID != deck }
        existing.append(contentsOf: words)
        vm.invalidateVocabCache(); vm.storeSnapshot.importedWords = existing
        if activeDeck == deck {
            startDictation(mode: vm.dictationMachine.mode, resume: false)
        }
        return vm.save() ? nil : (vm.storageError ?? "保存失败，请重试。")
    }

    // MARK: - 本轮听写报告（支持再来一轮 / 复习错词 / 导出 TXT）

    private struct DictationSummaryRow: Identifiable {
        let id: String
        let word: String
        let meaning: String
        let errors: Int
        let status: String
    }

    private var dictationSummaryRows: [DictationSummaryRow] {
        let machine = vm.dictationMachine
        var order: [String] = []
        var wordText: [String: String] = [:]
        var errorsInLogs: [String: Int] = [:]
        for log in machine.attemptLogs {
            if wordText[log.wordID] == nil {
                order.append(log.wordID)
                wordText[log.wordID] = log.word
            }
            if !log.isCorrect { errorsInLogs[log.wordID, default: 0] += 1 }
        }
        let rows: [DictationSummaryRow] = order.map { id in
            let errors: Int = max(machine.sessionErrorCounts[id] ?? 0, errorsInLogs[id] ?? 0)
            let status: String
            if machine.stubbornWordsMap[id] != nil {
                status = "顽固单词"
            } else if machine.completedWordIDs.contains(id) {
                status = errors == 0 ? "一次拼对" : "已订正"
            } else {
                status = "未完成"
            }
            let meaning: String = allWords.first(where: { $0.id == id })?.definitionZH ?? ""
            return DictationSummaryRow(id: id, word: wordText[id] ?? id, meaning: meaning, errors: errors, status: status)
        }
        return rows.sorted { lhs, rhs in
            if lhs.errors != rhs.errors { return lhs.errors > rhs.errors }
            return lhs.word.localizedStandardCompare(rhs.word) == .orderedAscending
        }
    }

    private var dictationSummaryView: some View {
        let rows: [DictationSummaryRow] = dictationSummaryRows
        let firstTry: Int = vm.dictationMachine.attemptLogs.filter { $0.isFirstAttemptInSession && $0.isCorrect }.count
        let totalErrors: Int = rows.reduce(0) { $0 + $1.errors }
        let hasErrors: Bool = totalErrors > 0
        return VStack(alignment: .leading, spacing: StudyMetrics.sectionSpacing) {
            HStack(spacing: 16) {
                statCard(title: "一次拼对率", value: rows.isEmpty ? "—" : String(format: "%.0f%%", Double(firstTry) / Double(rows.count) * 100),
                         subtitle: "\(firstTry) / \(rows.count) 词")
                statCard(title: "错词", value: "\(rows.filter { $0.errors > 0 }.count) 词", subtitle: "共错 \(totalErrors) 次")
            }

            HStack(spacing: 10) {
                if hasErrors {
                    Button {
                        startWrongWordDrill(rows.filter { $0.errors > 0 }.map(\.id), sessionDeckKey: "__listening_round_review__")
                    } label: {
                        Label("复习错词", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 16, height: 36))
                }
                Button {
                    selectDeckAndStartDictation(deck: vm.selectedDeck, mode: .newTask, resume: false)
                    mode = "学习_听力_今日计划"
                } label: {
                    Label("再练一轮", systemImage: "arrow.clockwise")
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: !hasErrors, horizontalPadding: 16, height: 36))
                Spacer()
                Menu {
                    Button("导出 TXT", systemImage: "square.and.arrow.up") {
                        exportDictationReport(rows: rows, firstTry: firstTry, totalErrors: totalErrors)
                    }
                    .disabled(rows.isEmpty)
                } label: {
                    VocabularyPageMenuLabel()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .accessibilityLabel("结果操作")
            }

            if !rows.isEmpty {
                DisclosureGroup("练习明细") {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            dictationSummaryRowView(row)
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    private func dictationSummaryRowView(_ row: DictationSummaryRow) -> some View {
        let statusColor: Color
        switch row.status {
        case "顽固单词": statusColor = appearance.accent
        case "未完成": statusColor = appearance.ink.opacity(0.55)
        case "已订正": statusColor = appearance.accent.opacity(0.85)
        default: statusColor = appearance.accent
        }
        return HStack(spacing: 14) {
            Text(row.word)
                .lumaFont(size: 15, weight: .medium)
                .foregroundStyle(appearance.ink)
                .frame(minWidth: 140, alignment: .leading)
            Text(row.meaning)
                .lumaFont(size: 13)
                .foregroundStyle(appearance.ink.opacity(0.6))
                .lineLimit(1)
            Spacer()
            if row.errors > 0 {
                Text("错 \(row.errors) 次")
                    .lumaFont(size: 12)
                    .monospacedDigit()
                    .foregroundStyle(appearance.ink.opacity(0.55))
            }
            Text(row.status)
                .lumaFont(size: 12, weight: .medium)
                .foregroundStyle(statusColor)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 11)
    }

    private func exportDictationReport(rows: [DictationSummaryRow], firstTry: Int, totalErrors: Int) {
        let deckName: String = deckTitle(for: vm.selectedDeck)
        let dateText: String = vm.dictationMachine.dateString
        var lines: [String] = [
            "Luma Reader 听写报告",
            "日期：" + dateText + "    词库：" + deckName + "    模式：" + dictationModeTitle,
            "单词：\(rows.count)    一次拼对：\(firstTry)    错误次数：\(totalErrors)",
            "",
            "单词\t释义\t错误次数\t状态"
        ]
        for row in rows {
            lines.append(row.word + "\t" + row.meaning + "\t\(row.errors)\t" + row.status)
        }
        let text: String = lines.joined(separator: "\n") + "\n"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "听写报告-" + deckName + "-" + dateText + ".txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            vm.dictationFeedback = "已导出 " + url.lastPathComponent
        } catch {
            vm.storageError = "导出失败：\(error.localizedDescription)"
        }
    }

    /// 听力首页只显示用户自己的词库：隐藏内置示例词库和内置词典（内置词典仍在后台用于导入时自动翻译）。
    private var visibleListeningDeckIDs: [String] {
        let base = vm.fastVisibleBaseDecks
        let pins = pinnedDeckIDs
        let pinRank = Dictionary(uniqueKeysWithValues: pins.enumerated().map { ($0.element, $0.offset) })
        let customOrder = customDeckOrderIDs
        let customRank = Dictionary(uniqueKeysWithValues: customOrder.enumerated().map { ($0.element, $0.offset) })
        let defaultOrder = BundledCoraVocabulary.defaultDeckOrder
        let defaultRank = Dictionary(uniqueKeysWithValues: defaultOrder.enumerated().map { ($0.element, $0.offset) })
        return base.sorted { a, b in
            let aPin = pinRank[a]
            let bPin = pinRank[b]
            if let ap = aPin, let bp = bPin, ap != bp {
                if let ac = customRank[a], let bc = customRank[b] {
                    return ac < bc
                }
                return ap < bp
            }
            if aPin != nil { return true }
            if bPin != nil { return false }
            if let ac = customRank[a], let bc = customRank[b], ac != bc {
                return ac < bc
            }
            if customRank[a] != nil { return true }
            if customRank[b] != nil { return false }
            if let ad = defaultRank[a], let bd = defaultRank[b], ad != bd {
                return ad < bd
            }
            if defaultRank[a] != nil { return false }
            if defaultRank[b] != nil { return true }
            return a < b
        }
    }

    private var dueReviewCount: Int {
        guard let deckWords = vm.fastWordsByDeck[vm.selectedDeck], !deckWords.isEmpty else { return 0 }
        let wrong = Set(vm.storeSnapshot.dictationLogs.filter { !$0.isCorrect && $0.deckID == vm.selectedDeck }.map(\.wordID))
        guard !wrong.isEmpty else { return 0 }
        let quarantined = Set(vm.storeSnapshot.stubbornWords.filter { $0.dateString == Self.todayDateString() }.map(\.wordID))
        let now = Date()
        return deckWords.filter { wrong.contains($0.id) && !quarantined.contains($0.id) && (vm.storeSnapshot.reviewSchedule?[$0.id]?.dueAt ?? .distantPast) <= now }.count
    }

    // MARK: 1.11.1 背词（独立词库，与听力完全分开）

    private func speakReadingQuizWord(_ text: String) {
        guard NSApp.isActive, !kokoro.isDisplaySuspended, mode == "学习_背词_练习" else { return }
        readingQuizSpeechIssue = nil
        guard !kokoro.useAppleSystemSpeech else {
            speakArbitraryWord(text)
            return
        }

        ttsEngine.stop()
        audio.stop()
        // A long background stay can release the worker. The neural bridge starts
        // it on demand, so temporary unreadiness should never pick another voice.
        let accepted = kokoro.play(text: text, speed: vm.speechRateMultiplier, onFailure: {
            guard NSApp.isActive, mode == "学习_背词_练习", !kokoro.useAppleSystemSpeech else { return }
            readingQuizSpeechIssue = (text, "神经语音暂不可用，点击喇叭重试")
        })
        if !accepted {
            readingQuizSpeechIssue = (text, "神经语音暂不可用，点击喇叭重试")
        }
    }

    private func startReadingQuiz(_ deck: String) {
        let words = deck == LumaChoiceLibrary.reviewDeckID ? readingReviewWords : choiceLibrary.readingWords(in: deck)
        guard !words.isEmpty else { return }
        readingQuizSpeechIssue = nil
        readingQuizReturn = mode
        choiceQuizDeckID = deck
        ttsEngine.stop(); audio.stop(); kokoro.stop()
        mode = "学习_背词_练习"
    }

    private var choiceLibraryPage: some View {
        LumaChoiceLibraryView(library: choiceLibrary, onStart: { deck in
            readingFolderCardID = deck
            startReadingQuiz(deck)
        }, path: $readingFolderPath, search: $readingFolderSearch, cardID: $readingFolderCardID)
    }

    private var choiceQuizPage: some View {
        let library = choiceLibrary
        var decks = library.readingDecks.filter { !library.readingWords(in: $0.id).isEmpty }
        if !readingReviewWords.isEmpty && readingQuizReturn == "学习_阅读错词" {
            decks.insert(LumaChoiceQuizDeck(id: LumaChoiceLibrary.reviewDeckID, title: "阅读错词"), at: 0)
        }
        let ids = Set(decks.map(\.id))
        return LumaChoiceQuizView(
            deckID: $choiceQuizDeckID,
            decks: decks,
            wordsForDeck: { $0 == LumaChoiceLibrary.reviewDeckID ? readingReviewWords : library.readingWords(in: $0) },
            globalPool: library.allReadingWords,
            speak: { speakReadingQuizWord($0) },
            speechIssue: readingQuizSpeechIssue,
            preparingSpeech: !kokoro.useAppleSystemSpeech && kokoro.isPreparingAudio,
            stopSpeech: { ttsEngine.stop(); audio.stop(); kokoro.stop() },
            onExit: { mode = readingQuizReturn },
            onMiss: { library.recordReadingMiss($0.id) },
            onReviewCorrect: { library.deferReadingReview($0.id) }
        )
        .onAppear {
            if !ids.contains(choiceQuizDeckID), let first = decks.first { choiceQuizDeckID = first.id }
        }
    }

    /// Give the new page its first frames before preparing speech. A new session,
    /// explicit playback or leaving practice cancels the pending start.
    private func scheduleDictationPlayback() {
        pendingDictationPlayback?.cancel()
        pendingDictationPlayback = nil
        guard let wordID = vm.dictationMachine.currentWord?.id else { return }
        let sessionID = vm.dictationMachine.sessionID
        pendingDictationPlayback = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(48)) } catch { return }
            guard !Task.isCancelled else { return }
            pendingDictationPlayback = nil
            guard mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习",
                  vm.dictationMachine.sessionID == sessionID,
                  vm.dictationMachine.currentWord?.id == wordID else { return }
            speakCurrentWord()
        }
    }

    private func startDictationFromLibraryCard(_ deck: String) {
        listeningCardID = deck
        selectDeckAndStartDictation(deck: deck, mode: .newTask, resume: true)
        // Enable the field in the same update that mounts the practice view.
        listeningDailyTimer.start()
        mode = "学习_听力_今日计划"
    }

    private func selectDeckAndStartDictation(deck: String, mode: DictationSessionMode, resume: Bool = true, dueOnly: Bool = false) {
        if deck.hasPrefix("__mixed_wrong__") && mode == .newTask {
            vm.scheduleSave(after: 0.4)
            vm.selectedDeck = deck
            startDictation(mode: .wrongWordReview, resume: resume)
            return
        }
        vm.scheduleSave(after: 0.4)
        let activeDeck = vm.dictationMachine.currentWord?.deckID ?? vm.dictationMachine.attemptLogs.last?.deckID ?? vm.selectedDeck
        if resume && !vm.selectedDeck.hasPrefix("__mixed_wrong__") && activeDeck == deck && vm.dictationMachine.mode == mode && vm.dictationMachine.dateString == Self.todayDateString() && !vm.dictationMachine.isSessionFinished {
            vm.selectedDeck = deck
            vm.scheduleSave(after: 0.4)
            scheduleDictationPlayback()
            return
        }
        vm.selectedDeck = deck
        startDictation(mode: mode, resume: resume, dueOnly: dueOnly)
    }

    private func startDictation(mode: DictationSessionMode, resume: Bool = false, dueOnly: Bool = false) {
        if mode == .wrongWordReview && vm.selectedDeck.hasPrefix("__mixed_wrong__") {
            let decks = String(vm.selectedDeck.dropFirst("__mixed_wrong__".count)).components(separatedBy: "\u{1F}")
            startMixedWrongReview(decks: decks, resume: resume)
            return
        }
        guard vm.fastVisibleBaseDecks.contains(vm.selectedDeck) || mode == .slowReactionReview else {
            pendingDictationPlayback?.cancel()
            pendingDictationPlayback = nil
            ttsEngine.stop(); audio.stop(); kokoro.stop()
            return
        }
        let key = HostStateModel.sessionKey(mode: mode, date: Self.todayDateString(), deck: vm.selectedDeck)
        vm.activeDictationDeckKey = vm.selectedDeck
        if resume, let saved = vm.storeSnapshot.dictationSessions?[key], !saved.isSessionFinished {
            vm.dictationMachine = saved
            let state = vm.storeSnapshot.workspace
            if let currentWordID = saved.currentWord?.id {
                if state?.deckInputWordIDs?[key] == currentWordID {
                    vm.dictationInput = state?.deckInputs?[key] ?? ""
                    vm.showMeaning = state?.deckShowMeaning?[key] ?? false
                    vm.revealedWordID = state?.deckRevealedWordIDs?[key]
                } else if state?.inputWordID == currentWordID {
                    vm.dictationInput = state?.dictationInput ?? ""
                    vm.showMeaning = state?.showMeaning ?? false
                    vm.revealedWordID = state?.revealedWordID
                } else {
                    vm.dictationInput = ""
                    vm.showMeaning = false
                    vm.revealedWordID = nil
                }
            } else {
                vm.dictationInput = ""
                vm.showMeaning = false
                vm.revealedWordID = nil
            }
            vm.scheduleSave(after: 0.4)
            scheduleDictationPlayback()
            return
        }
        let snapshot = vm.storeSnapshot
        let deck = vm.selectedDeck
        let reviewIDs: Set<String>?
        switch mode {
        case .newTask:
            reviewIDs = nil
        case .stubbornWordReview:
            reviewIDs = Set(snapshot.stubbornWords.map(\.wordID))
        case .wrongWordReview:
            reviewIDs = Set(snapshot.dictationLogs.lazy.filter { !$0.isCorrect && $0.deckID == deck }.map(\.wordID))
        case .slowReactionReview:
            reviewIDs = Set((snapshot.slowReactionWords ?? []).map(\.wordID))
        }
        let deckWords = vm.fastWordsByDeck[deck] ?? []
        let now = Date()
        var words = if reviewIDs == nil && !dueOnly {
            deckWords
        } else {
            deckWords.filter {
                (reviewIDs?.contains($0.id) ?? true) &&
                (!dueOnly || (snapshot.reviewSchedule?[$0.id]?.dueAt ?? .distantPast) <= now)
            }
        }
        if mode == .wrongWordReview {
            words.sort { a, b in
                let ra = snapshot.reviewSchedule?[a.id]?.ebbinghausRetrievability(at: now) ?? 0.0
                let rb = snapshot.reviewSchedule?[b.id]?.ebbinghausRetrievability(at: now) ?? 0.0
                if abs(ra - rb) > 0.001 { return ra < rb }
                return a.id < b.id
            }
        }
        if mode == .slowReactionReview, words.isEmpty, let reviewIDs {
            let visibleDecks = Set(vm.fastVisibleBaseDecks)
            words = allWords.filter { reviewIDs.contains($0.id) && visibleDecks.contains($0.deckID) }
        }
        vm.dictationMachine = DictationSessionStateMachine(
            mode: mode,
            dateString: Self.todayDateString(),
            initialWords: words,
            existingStubbornWordsForToday: vm.storeSnapshot.stubbornWords,
            previousLogs: vm.storeSnapshot.dictationLogs
        )
        vm.showMeaning = false
        vm.revealedWordID = nil
        showFirstLetterHint = false
        vm.dictationInput = ""
        vm.scheduleSave(after: 0.4)
        scheduleDictationPlayback()
    }

    private func enableLocalSpeechServiceSettings() {
        if var service = vm.storeSnapshot.speechService,
           service.enabled,
           service.baseURL == "http://127.0.0.1:8000/v1",
           (service.model == "kokoro-v1.0" || service.model.isEmpty) {
            service.enabled = false
            vm.storeSnapshot.speechService = service
            vm.save()
        }
    }

    private func replayCurrentWord(overrideRate: Float? = nil) {
        guard vm.dictationMachine.currentWord != nil, !kokoro.isSwitching else { return }
        if !listeningDailyTimer.running {
            resumePlaybackRate = overrideRate
            listeningDailyTimer.start()
        } else { speakCurrentWord(overrideRate: overrideRate) }
    }
    private func revisitPreviousWord() {
        guard let previousDictationWord, !vm.dictationMachine.requiresCorrection else { return }
        ttsEngine.stop(); audio.stop(); kokoro.stop()
        vm.dictationMachine.revisitCompletedWord(previousDictationWord)
        vm.dictationInput = ""; vm.showMeaning = false; vm.revealedWordID = nil; showFirstLetterHint = false
        vm.save(); replayCurrentWord(); answerFocused = true
    }

    private func speakCurrentWord(overrideRate: Float? = nil) {
        guard listeningDailyTimer.running else { return }
        pendingDictationPlayback?.cancel()
        pendingDictationPlayback = nil
        guard let word = vm.dictationMachine.currentWord else { return }
        guard vm.fastVisibleBaseDecks.contains(word.deckID) || vm.dictationMachine.mode == .slowReactionReview else { return }
        let activeRate = overrideRate ?? vm.speechRateMultiplier
        let repeats = overrideRate != nil ? 1 : (vm.storeSnapshot.speechRepeatCount ?? 1)
        let interval = vm.storeSnapshot.speechInterval ?? 0.5
        vm.markAudioPlaybackStarted(for: word.word, rate: activeRate, repeats: repeats, interval: interval)

        if !kokoro.useAppleSystemSpeech {
            ttsEngine.stop()
            audio.stop()
            let upcoming = vm.dictationMachine.pendingQueue.dropFirst().prefix(3).map(\.word)
            if kokoro.play(text: word.word, speed: activeRate, repeats: repeats, interval: interval, prefetch: upcoming, onFailure: {
                guard listeningDailyTimer.running, vm.dictationMachine.currentWord?.id == word.id else { return }
                playFallbackWord(word.word, rate: activeRate, repeats: repeats, interval: interval)
            }) {
                return
            }
        }
        playFallbackWord(word.word, rate: activeRate, repeats: repeats, interval: interval)
    }

    private func playFallbackWord(_ text: String, rate activeRate: Float, repeats: Int, interval: Double) {
        let service = vm.storeSnapshot.speechService ?? SpeechServiceSettings()
        if service.enabled && audio.isConnected && audio.models.contains(service.model) {
            ttsEngine.stop()
            kokoro.stop()
            let next = vm.dictationMachine.pendingQueue.dropFirst().prefix(1).map(\.word)
            audio.play(
                text: text,
                next: Array(next),
                settings: service,
                speed: activeRate,
                repeats: repeats,
                interval: interval,
                accent: vm.selectedAccent,
                preferredVoiceID: vm.storeSnapshot.selectedVoiceIdentifier
            )
            return
        }

        kokoro.stop()
        audio.stop()
        let voices = ttsEngine.availableVoices(for: vm.selectedAccent)
        let selected = voices.first { $0.id == vm.storeSnapshot.selectedVoiceIdentifier }
        let voice = selected ?? ttsEngine.selectBestFemaleVoice(
            preferredVoiceID: vm.storeSnapshot.selectedVoiceIdentifier,
            accent: vm.selectedAccent
        )
        ttsEngine.repeatCount = repeats
        ttsEngine.repeatInterval = interval
        ttsEngine.speak(text: text, voice: voice, requestedRate: activeRate)
    }

    private func triggerDictationErrorAnimation() {
        dictationErrorFeedbackTask?.cancel()
        let system = dictTheme.visualThemeSystem
        dictationErrorPulse &+= 1
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        if reduceMotion {
            dictationErrorFlash = true
        } else {
            let duration = system == "space" ? 0.34 : (system == "manga" ? 0.24 : 0.46)
            withAnimation(.easeInOut(duration:duration)) {
                dictationErrorShake += 1
                dictationErrorFlash = true
            }
        }
        dictationErrorFeedbackTask = Task { @MainActor in
            let hold = system == "space" ? 720 : (system == "manga" ? 460 : 680)
            do { try await Task.sleep(for:.milliseconds(hold)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration:system == "manga" ? 0.10:0.25)) {
                dictationErrorFlash = false
            }
        }
    }

    private func submitCurrentDictation(editorText: String? = nil) {
        guard listeningDailyTimer.running, !kokoro.isSwitching else { return }
        guard let word = vm.dictationMachine.currentWord, let outcome = vm.submitDictationInput(editorText, newWordStrategy: newWordStrategy) else { return }
        let reactionSecs = vm.lastSubmittedReactionSeconds ?? 2.0

        if let log = vm.dictationMachine.attemptLogs.last {
            vm.storeSnapshot.dictationLogs.append(log)
            if !log.isCorrect || vm.dictationMachine.completedWordIDs.contains(word.id) {
                var progress = vm.storeSnapshot.reviewSchedule?[word.id] ?? WordReviewProgress(dueAt: Date())
                progress.record(cleanRecall: log.isCorrect, reactionSeconds: reactionSecs, at: Date())
                if vm.storeSnapshot.reviewSchedule == nil { vm.storeSnapshot.reviewSchedule = [:] }
                vm.storeSnapshot.reviewSchedule?[word.id] = progress
            }
            if log.isCorrect {
                var slowList = vm.storeSnapshot.slowReactionWords ?? []
                if reactionSecs > SlowReactionWordRecord.slowThresholdSeconds {
                    if let idx = slowList.firstIndex(where: { $0.wordID == word.id }) {
                        slowList[idx].lastReactionSeconds = reactionSecs
                        slowList[idx].maxReactionSeconds = max(slowList[idx].maxReactionSeconds, reactionSecs)
                        slowList[idx].slowCount += 1
                        slowList[idx].dateString = Self.todayDateString()
                        slowList[idx].updatedAt = Date()
                    } else {
                        slowList.append(
                            SlowReactionWordRecord(
                                wordID: word.id,
                                word: word.word,
                                definitionZH: word.definitionZH.isEmpty ? (BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: word.word) ?? "") : word.definitionZH,
                                sourceDeckID: word.deckID,
                                sourceDeckTitle: word.deckTitle,
                                lastReactionSeconds: reactionSecs,
                                maxReactionSeconds: reactionSecs,
                                slowCount: 1,
                                dateString: Self.todayDateString(),
                                updatedAt: Date()
                            )
                        )
                    }
                    vm.storeSnapshot.slowReactionWords = slowList
                } else if let idx = slowList.firstIndex(where: { $0.wordID == word.id }) {
                    slowList[idx].bestReactionSeconds = min(slowList[idx].bestReactionSeconds ?? reactionSecs, reactionSecs)
                    vm.storeSnapshot.slowReactionWords = slowList
                }
            }
        }
        for record in vm.dictationMachine.sortedStubbornWords {
            vm.storeSnapshot.stubbornWords.removeAll { $0.wordID == record.wordID && $0.dateString == record.dateString }
            vm.storeSnapshot.stubbornWords.append(record)
        }
        vm.revealedWordID = vm.dictationMachine.requiresCorrection ? word.id : nil
        if vm.dictationMachine.requiresCorrection { vm.showMeaning = true }
        vm.dictationInput = ""
        vm.save()
        answerFocused = true
        switch outcome {
        case .skippedIncorrect:
            dictationErrorFlash = false
            vm.dictationFeedback = "已记入错词，继续下一词"
            speakCurrentWord()
        case .needsCorrection(let count):
            vm.dictationFeedback = "拼写有误（今日第 \(count) 次），请订正"
            triggerDictationErrorAnimation()
            speakCurrentWord()
        case .correct(let exited):
            dictationErrorFlash = false
            if reactionSecs > SlowReactionWordRecord.slowThresholdSeconds {
                vm.dictationFeedback = String(format: "✓ 拼写正确，但从语音播完到敲下回车耗时 %.1f 秒（> 5.0 秒阈值），已自动标记为「慢反应词」加入提速巩固！", reactionSecs)
            } else {
                vm.dictationFeedback = String(format: "✓ %@（反应耗时 %.1f 秒，达标 ≤5.0s）", exited ? "本轮复习完成。" : "拼写正确。", reactionSecs)
            }
            speakCurrentWord()
        case .requeuedForRetry(_, let offset):
            dictationErrorFlash = false
            let cycle = vm.dictationMachine.wrongRetryCycleByWordID[word.id, default: 1]
            vm.dictationFeedback = "✓ 艾宾浩斯错词循环（第 \(cycle)/4 轮）：将在第 \(offset) 个单词后再次复现检测"
            speakCurrentWord()
        case .promotedToStubbornWords:
            vm.dictationFeedback = "已进入顽固单词，拼对后继续"
            triggerDictationErrorAnimation()
            speakCurrentWord()
        }
    }

    @discardableResult
    private func saveImportedWords(_ words: [VocabularyWord]) -> String? {
        guard !words.isEmpty else { return "没有可导入的词条，原词库保持不变。" }
        var existing = vm.storeSnapshot.importedWords ?? []
        for w in words {
            // 同词不同释义的词条（ID 里带「~」）作为独立词条追加；其余沿用原规则：同词更新、新词追加。
            let isSeparateMeaning = w.id.contains("~")
            let matchIndex: Int?
            if let sameID = existing.firstIndex(where: { $0.id == w.id }) {
                matchIndex = sameID
            } else if isSeparateMeaning {
                matchIndex = nil
            } else {
                matchIndex = existing.firstIndex(where: { $0.deckID == w.deckID && $0.word.lowercased() == w.word.lowercased() })
            }
            if matchIndex == nil {
                existing.append(w)
            } else if let idx = matchIndex {
                let preservedID = existing[idx].id
                existing[idx] = VocabularyWord(
                    id: preservedID,
                    word: w.word,
                    phoneticUK: w.phoneticUK,
                    phoneticUS: w.phoneticUS,
                    partOfSpeech: w.partOfSpeech,
                    definitionZH: w.definitionZH,
                    exampleSentence: w.exampleSentence,
                    deckID: w.deckID,
                    deckTitle: w.deckTitle
                )
            }
        }
        vm.invalidateVocabCache(); vm.storeSnapshot.importedWords = existing
        if let firstDeck = words.first?.deckID, mode.contains("听力") {
            vm.selectedDeck = firstDeck
            startDictation(mode: .newTask, resume: false)
        }
        return vm.save() ? nil : (vm.storageError ?? "保存失败，请重试。")
    }

    private func saveWritingRevision(_ revision: WritingRevision) -> String? {
        var revisions = vm.storeSnapshot.writingRevisions ?? []
        revisions.removeAll { $0.id == revision.id }; revisions.append(revision)
        vm.storeSnapshot.writingRevisions = revisions
        return vm.save() ? nil : (vm.storageError ?? "重写稿保存失败，请重试。")
    }

    // MARK: - 3. Study Statistics View (Native Swift Charts: Annual GitHub Heatmap + Task 1 / Task 2 4D Line Charts & Bottleneck Diagnosis)

    private var effectiveReadingSecondsMap: [String: Int] {
        var combined = vm.storeSnapshot.dailyReadingSeconds ?? [:]
        if let ud = UserDefaults.standard.dictionary(forKey: "luma.study.dailyReadingSeconds") as? [String: Int] {
            for (k, v) in ud {
                combined[k] = max(combined[k, default: 0], v)
            }
        }
        return combined
    }

    private var studyStatisticsView: some View {
        let allowedDates: Set<String>? = {
            let count: Int
            switch vm.statsTimeWindow { case .allTime: return nil; case .today: count = 1; case .last7Days: count = 7; case .last30Days: count = 30 }
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
            return Set((0..<count).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }.map { formatter.string(from: $0) })
        }()
        let readingMap = effectiveReadingSecondsMap
        let overview = StudyStatisticsCalculator.computeOverview(
            dictationLogs: vm.storeSnapshot.dictationLogs,
            writingSubmissions: vm.storeSnapshot.writingSubmissions,
            readingSecondsByDate: readingMap,
            allowedDates: allowedDates
        )
        let listeningStats = StudyStatisticsCalculator.computeListening(
            dictationLogs: vm.storeSnapshot.dictationLogs,
            stubbornWords: vm.storeSnapshot.stubbornWords.sorted { $0.errorCount > $1.errorCount },
            allowedDates: allowedDates
        )
        let writingStats = StudyStatisticsCalculator.computeWriting(
            submissions: vm.storeSnapshot.writingSubmissions,
            allowedDates: allowedDates
        )
        let annualHeatmap = StudyStatisticsCalculator.computeAnnualHeatmap(
            readingByDate: readingMap,
            dictationLogs: vm.storeSnapshot.dictationLogs,
            writingSubmissions: vm.storeSnapshot.writingSubmissions
        )
        let competency = StudyStatisticsCalculator.computeWritingCompetencyDiagnostics(
            submissions: vm.storeSnapshot.writingSubmissions,
            questions: vm.allTask1Questions
        )

        return ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("学习统计与能力诊断（原生 Swift Charts）")
                            .lumaFont(size: 30, weight: .bold, design: .serif)
                            .foregroundStyle(appearance.ink)
                        Text("涵盖 GitHub 风格年度阅读/听写/写作热力图打卡墙、小作文 (TA/CC/LR/GRA) 与大作文 (TR/CC/LR/GRA) 四维能力走势及近期卡分点诊断。")
                            .lumaFont(size: 13)
                            .foregroundStyle(appearance.ink.opacity(0.68))
                    }
                    Spacer()
                    Picker("模块", selection: $vm.statsScope) {
                        ForEach(StudyStatisticsScope.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)

                    Picker("时间范围", selection: $vm.statsTimeWindow) {
                        ForEach(StudyStatsTimeWindow.allCases, id: \.self) { w in
                            Text(w.rawValue).tag(w)
                        }
                    }
                    .frame(width: 150)
                }

                if vm.statsScope == .all {
                    HStack(spacing: 16) {
                        statCard(
                            title: "真实总学习时长",
                            value: "\(overview.totalStudySeconds / 60) 分钟",
                            subtitle: "阅读 \(annualHeatmap.totalReadingSeconds / 60) 分钟 + 听写 \(overview.listeningStudySeconds / 60) 分钟 + 写作 \(overview.writingStudySeconds / 60) 分钟"
                        )
                        statCard(
                            title: "当前连续打卡",
                            value: "\(annualHeatmap.currentStreakDays) 天",
                            subtitle: "最长连续打卡：\(annualHeatmap.longestStreakDays) 天 · 年度累计打卡：\(annualHeatmap.activeDaysCount) 天"
                        )
                        statCard(
                            title: "慢反应词 & 顽固词",
                            value: "\((vm.storeSnapshot.slowReactionWords ?? []).count) / \(vm.storeSnapshot.stubbornWords.count)",
                            subtitle: "犹豫 >5s 慢反应词 \((vm.storeSnapshot.slowReactionWords ?? []).count) 个 · 顽固单词 \(vm.storeSnapshot.stubbornWords.count) 个"
                        )
                    }
                } else if vm.statsScope == .listening {
                    HStack(spacing: 16) {
                        statCard(title: "听写完成单词数", value: "\(listeningStats.completedUniqueWordsCount) 词", subtitle: "总错误次数：\(listeningStats.totalErrorCount)")
                        statCard(title: "首次正确率", value: String(format: "%.1f%%", listeningStats.firstAttemptAccuracyPercent), subtitle: "顽固单词数：\(listeningStats.stubbornWordsCount) · 慢反应词：\((vm.storeSnapshot.slowReactionWords ?? []).count)")
                    }
                } else {
                    HStack(spacing: 16) {
                        statCard(title: "完成作文篇数", value: "\(writingStats.totalSubmissionsCount) 篇", subtitle: "Task 1: \(writingStats.task1Count) 篇 · Task 2: \(writingStats.task2Count) 篇")
                        statCard(title: "平均字数与官方标准均分", value: "\(writingStats.averageWordCount) 词", subtitle: "官方标准预估均分：\(writingStats.averageEstimatedBand.map { String(format: "Band %.1f", $0) } ?? "暂无数据")")
                    }
                }

                annualHeatmapCardView(heatmap: annualHeatmap)
                writingFourDimensionsChartsSection(task1Diag: competency.task1, task2Diag: competency.task2)
            }
            .padding(32)
        }
        .background(appearance.background)
    }

    private func annualHeatmapCardView(heatmap: AnnualStudyHeatmapSummary) -> some View {
        let inspected = selectedHeatmapCell ?? heatmap.cells.last
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(appearance.accent)
                        Text("年度学习热力图（阅读 · 听写 · 写作 每日总投入打卡墙）")
                            .lumaFont(size: 18, weight: .bold, design: .serif)
                            .foregroundStyle(appearance.ink)
                    }
                    Text("过去 52 周每天在阅读、词汇听写与雅思写作上的总投入时长与连续打卡记录（点击任一方格可查看当日明细）。")
                        .font(.caption)
                        .foregroundStyle(appearance.ink.opacity(0.68))
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("少").font(.caption2).foregroundStyle(.secondary)
                    ForEach(0..<5, id: \.self) { lvl in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(heatmapColor(for: lvl))
                            .frame(width: 11, height: 11)
                    }
                    Text("多").font(.caption2).foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("周一").lumaFont(size: 9).foregroundStyle(.secondary).frame(height: 11)
                        Text("").frame(height: 11)
                        Text("周三").lumaFont(size: 9).foregroundStyle(.secondary).frame(height: 11)
                        Text("").frame(height: 11)
                        Text("周五").lumaFont(size: 9).foregroundStyle(.secondary).frame(height: 11)
                        Text("").frame(height: 11)
                        Text("周日").lumaFont(size: 9).foregroundStyle(.secondary).frame(height: 11)
                    }
                    .padding(.trailing, 4)

                    HStack(alignment: .top, spacing: 3) {
                        ForEach(0..<heatmap.weekCount, id: \.self) { wIdx in
                            let weekCells = heatmap.cells.filter { $0.weekIndex == wIdx }.sorted { $0.weekdayIndex < $1.weekdayIndex }
                            VStack(spacing: 3) {
                                ForEach(weekCells) { cell in
                                    let isSelected = (inspected?.dateString == cell.dateString)
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .fill(heatmapColor(for: cell.intensityLevel))
                                        .frame(width: 11, height: 11)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2.5)
                                                .stroke(isSelected ? appearance.ink : Color.clear, lineWidth: 1.2)
                                        )
                                        .help("\(cell.dateString)：总计 \(cell.totalMinutes) 分钟（阅读 \(cell.readingMinutes)m · 听写 \(cell.listeningMinutes)m · 写作 \(cell.writingMinutes)m）")
                                        .onTapGesture {
                                            selectedHeatmapCell = cell
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if let day = inspected {
                HStack(spacing: 16) {
                    Text("📅 \(day.dateString)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(appearance.ink)
                    Text("当日总投入：\(day.totalMinutes) 分钟")
                        .font(.caption.bold())
                        .foregroundStyle(appearance.accent)
                    Text("📖 阅读：\(day.readingMinutes) 分钟")
                        .font(.caption)
                    Text("🎧 听写：\(day.listeningMinutes) 分钟")
                        .font(.caption)
                    Text("✍️ 写作：\(day.writingMinutes) 分钟")
                        .font(.caption)
                    Spacer()
                    Text("连续打卡 \(heatmap.currentStreakDays) 天 · 年度活跃 \(heatmap.activeDaysCount) 天")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(appearance.ink.opacity(0.72))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(appearance.paper.opacity(0.55)))
            }

            let recentActive = Array(heatmap.cells.suffix(14))
            if !recentActive.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("近 14 天每日三科投入时长分布（分钟 · 原生 Swift Charts）")
                        .font(.caption.bold())
                        .foregroundStyle(appearance.ink.opacity(0.78))
                    Chart {
                        ForEach(recentActive) { c in
                            let shortDate = String(c.dateString.suffix(5))
                            BarMark(
                                x: .value("日期", shortDate),
                                y: .value("分钟", Double(c.readingSeconds) / 60.0)
                            )
                            .foregroundStyle(by: .value("模块", "阅读"))

                            BarMark(
                                x: .value("日期", shortDate),
                                y: .value("分钟", Double(c.listeningSeconds) / 60.0)
                            )
                            .foregroundStyle(by: .value("模块", "听写"))

                            BarMark(
                                x: .value("日期", shortDate),
                                y: .value("分钟", Double(c.writingSeconds) / 60.0)
                            )
                            .foregroundStyle(by: .value("模块", "写作"))
                        }
                    }
                    .frame(height: 150)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 14).fill(appearance.surface))
    }

    private func heatmapColor(for level: Int) -> Color {
        switch level {
        case 0: return appearance.ink.opacity(appearance.isDark ? 0.10 : 0.08)
        case 1: return appearance.accent.opacity(0.32)
        case 2: return appearance.accent.opacity(0.54)
        case 3: return appearance.accent.opacity(0.78)
        default: return appearance.accent
        }
    }

    private func writingFourDimensionsChartsSection(
        task1Diag: WritingTaskCompetencyDiagnostic,
        task2Diag: WritingTaskCompetencyDiagnostic
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(appearance.accent)
                Text("写作四维能力折线图与近期卡分点诊断（基于原生 Swift Charts）")
                    .lumaFont(size: 18, weight: .bold, design: .serif)
                    .foregroundStyle(appearance.ink)
                Spacer()
            }

            HStack(alignment: .top, spacing: 16) {
                singleTaskCompetencyChartCard(
                    title: "小作文 (Academic Task 1) 四维走势 · TA / CC / LR / GRA",
                    diag: task1Diag
                )
                singleTaskCompetencyChartCard(
                    title: "大作文 (Writing Task 2) 四维走势 · TR / CC / LR / GRA",
                    diag: task2Diag
                )
            }
        }
    }

    private func singleTaskCompetencyChartCard(
        title: String,
        diag: WritingTaskCompetencyDiagnostic
    ) -> some View {
        let firstLabel = diag.isTask1 ? "TA" : "TR"
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .lumaFont(size: 15, weight: .bold, design: .serif)
                    .foregroundStyle(appearance.ink)
                Spacer()
                if diag.submissionCount > 0 {
                    Text(String(format: "近期总均分 Band %.1f (%d 篇)", diag.averageOverall, diag.submissionCount))
                        .font(.caption.bold())
                        .foregroundStyle(appearance.accent)
                }
            }

            if diag.points.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(diag.bottleneckDiagnosisZH)
                        .lumaFont(size: 13)
                        .foregroundStyle(appearance.ink.opacity(0.7))
                    Text(diag.actionableAdviceZH)
                        .font(.caption)
                        .foregroundStyle(appearance.accent)
                }
                .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            } else {
                Chart {
                    ForEach(diag.points) { pt in
                        LineMark(
                            x: .value("交卷次序", pt.shortAttemptLabel),
                            y: .value("Band 小分", pt.score)
                        )
                        .foregroundStyle(by: .value("评分维度", pt.criterionDisplayName))
                        .symbol(by: .value("评分维度", pt.criterionDisplayName))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("交卷次序", pt.shortAttemptLabel),
                            y: .value("Band 小分", pt.score)
                        )
                        .foregroundStyle(by: .value("评分维度", pt.criterionDisplayName))
                    }
                }
                .chartYScale(domain: 4.0...9.0)
                .frame(height: 210)

                HStack(spacing: 8) {
                    criterionAveragePill(code: firstLabel, score: diag.averageFirstCriterion, isBottleneck: diag.bottleneckCriterionCode == firstLabel)
                    criterionAveragePill(code: "CC", score: diag.averageCC, isBottleneck: diag.bottleneckCriterionCode == "CC")
                    criterionAveragePill(code: "LR", score: diag.averageLR, isBottleneck: diag.bottleneckCriterionCode == "LR")
                    criterionAveragePill(code: "GRA", score: diag.averageGRA, isBottleneck: diag.bottleneckCriterionCode == "GRA")
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(appearance.accent)
                        Text("近期卡分点：\(diag.bottleneckCriterionTitle)（均分 Band \(String(format: "%.1f", diag.bottleneckAverageScore))）")
                            .lumaFont(size: 13, weight: .bold)
                            .foregroundStyle(appearance.accent)
                    }
                    Text(diag.bottleneckDiagnosisZH)
                        .lumaFont(size: 12.5)
                        .foregroundStyle(appearance.ink.opacity(0.88))
                    Text(diag.actionableAdviceZH)
                        .lumaFont(size: 12, weight: .medium)
                        .foregroundStyle(appearance.accent)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(appearance.paper.opacity(0.55)))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(appearance.surface))
    }

    private func criterionAveragePill(code: String, score: Double, isBottleneck: Bool) -> some View {
        HStack(spacing: 4) {
            Text(code)
                .font(.caption.bold())
            Text(String(format: "%.1f", score))
                .font(.caption.bold().monospacedDigit())
            if isBottleneck {
                Text("卡分点")
                    .lumaFont(size: 9.5, weight: .bold)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(appearance.selected))
            }
        }
        .foregroundStyle(isBottleneck ? appearance.accent : appearance.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isBottleneck ? appearance.selected : appearance.paper.opacity(0.5))
        )
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .lumaFont(size: 13)
                .foregroundStyle(appearance.ink.opacity(0.7))
            Text(value)
                .lumaFont(size: 24, weight: .bold)
                .foregroundStyle(appearance.ink)
            Text(subtitle)
                .lumaFont(size: 12)
                .foregroundStyle(appearance.ink.opacity(0.65))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(appearance.surface))
    }

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Built-in Data

    public static let hiddenBuiltInDeckIDs: Set<String> = ["vocab_daily"]

    public static let builtInVocabularyWords: [VocabularyWord] = [
        VocabularyWord(id: "vw-001", word: "abandon", definitionZH: "v. 放弃，遗弃", deckID: "vocab_daily", deckTitle: "每日必备核心词"),
        VocabularyWord(id: "vw-002", word: "capacity", definitionZH: "n. 容量；能力", deckID: "vocab_daily", deckTitle: "每日必备核心词"),
        VocabularyWord(id: "vw-003", word: "fluctuate", definitionZH: "v. 波动，起伏", deckID: "vocab_daily", deckTitle: "每日必备核心词"),
        VocabularyWord(id: "vw-004", word: "sustainable", definitionZH: "adj. 可持续的", deckID: "vocab_daily", deckTitle: "每日必备核心词"),
        VocabularyWord(id: "vw-005", word: "inevitable", definitionZH: "adj. 不可避免的", deckID: "vocab_daily", deckTitle: "每日必备核心词")
    ]

    public static let builtInPracticeQuestions: [Task1QuestionItem] = [
        Task1QuestionItem(
            id: "ORIG-001",
            shortTitle: "城市用电量",
            category: .lineGraph,
            difficultyBand: "Band 6.5-7.5",
            promptText: "The line graph below shows electricity consumption (in gigawatt-hours) in four different cities from 2010 to 2024. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["2010", "2015", "2020", "2024"],
                series: [
                    ChartSeries(name: "Metropolis A", unit: "GWh", values: [450, 520, 610, 680]),
                    ChartSeries(name: "Coastal City B", unit: "GWh", values: [300, 310, 330, 360]),
                    ChartSeries(name: "Industrial Hub C", unit: "GWh", values: [600, 580, 540, 510]),
                    ChartSeries(name: "Town D", unit: "GWh", values: [120, 150, 210, 290])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-001",
            companionTask2Prompt: "Some people believe that governments should heavily tax high-energy-consuming industries to reduce overall consumption. To what extent do you agree or disagree?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-002",
            shortTitle: "家庭预算支出分布",
            category: .pieChart,
            difficultyBand: "Band 6.0-7.0",
            promptText: "The pie chart illustrates the average proportion of monthly expenditure spent by households in Country X in 2023. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: [
                    "Housing & Utilities": 32,
                    "Food & Groceries": 22,
                    "Transport": 15,
                    "Leisure & Entertainment": 12,
                    "Savings & Investments": 11,
                    "Other": 8
                ],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-002",
            companionTask2Prompt: "In many countries, people are spending a larger share of their income on housing. What are the causes of this trend, and what effects does it have on society?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-003",
            shortTitle: "岛屿改造对比",
            category: .map,
            difficultyBand: "Band 6.5-7.5",
            promptText: "The maps show a small island before and after the construction of tourist facilities. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: MapComparisonPayload(
                    beforeYearLabel: "Before Development (2010)",
                    afterYearLabel: "After Development (2024)",
                    beforeFeatures: [
                        MapStageFeature(label: "Natural palm trees & beach", region: "West Coast", status: "retained"),
                        MapStageFeature(label: "Empty central grassland", region: "Center", status: "modified"),
                        MapStageFeature(label: "Small fishing pier", region: "South Coast", status: "removed")
                    ],
                    afterFeatures: [
                        MapStageFeature(label: "Reception building & restaurant", region: "Center", status: "added"),
                        MapStageFeature(label: "Western accommodation huts with footpaths", region: "West Coast", status: "added"),
                        MapStageFeature(label: "Eastern luxury villas with vehicle track", region: "East Coast", status: "added"),
                        MapStageFeature(label: "Expanded marina & boat slipway", region: "South Coast", status: "added"),
                        MapStageFeature(label: "Swimming zone & water sports center", region: "North Coast", status: "added")
                    ]
                ),
                processSteps: nil
            ),
            companionTask2ID: "T2-003",
            companionTask2Prompt: "Tourism brings economic benefits to remote island communities, but it can also harm local environments. Do the advantages of island tourism outweigh its disadvantages?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-004",
            shortTitle: "咖啡豆加工全流程",
            category: .processDiagram,
            difficultyBand: "Band 6.0-7.0",
            promptText: "The diagram below illustrates the stages involved in the production of commercial roasted coffee from raw cherries. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Hand Harvesting", detail: "Ripe red coffee cherries are hand-picked in high-altitude orchards.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Pulping & Fermentation", detail: "Outer skin removed; beans fermented in water tanks for 24 hours.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Sun Drying", detail: "Beans spread on raised beds and dried in sunlight for 7-10 days.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Hulling & Sorting", detail: "Parchment layer removed; green beans sorted by size and color.", nextStepNumber: 5),
                    ProcessStepPayload(stepNumber: 5, title: "Industrial Roasting", detail: "Beans roasted at 220°C until dark brown, then rapidly cooled.", nextStepNumber: 6),
                    ProcessStepPayload(stepNumber: 6, title: "Vacuum Packaging", detail: "Roasted whole beans packaged in sealed bags for international export.", nextStepNumber: nil)
                ]
            ),
            companionTask2ID: "T2-004",
            companionTask2Prompt: "Fair-trade initiatives advocate paying higher prices to agricultural producers in developing nations. Is this an effective approach to tackling global inequality?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-005",
            shortTitle: "4国图书馆资源对比",
            category: .table,
            difficultyBand: "Band 6.5-7.5",
            promptText: "The table below compares public library resources and annual visits per capita across four different countries in 2022. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Print Books (per 1k)", "Digital Titles (per 1k)", "Annual Visits per Capita", "PC Workstations (per branch)"],
                series: [
                    ChartSeries(name: "Country Alpha", unit: "count", values: [3200, 1800, 6.2, 24]),
                    ChartSeries(name: "Country Beta", unit: "count", values: [2100, 2900, 7.8, 40]),
                    ChartSeries(name: "Country Gamma", unit: "count", values: [4500, 800, 3.9, 12]),
                    ChartSeries(name: "Country Delta", unit: "count", values: [1900, 3400, 8.4, 48])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-005",
            companionTask2Prompt: "With the widespread availability of digital media, some people argue that traditional public libraries are a waste of taxpayer money. Do you agree or disagree?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-006",
            shortTitle: "全流程复合图 · 水循环与供水系统",
            category: .mixedChart,
            difficultyBand: "Band 7.0-8.0",
            promptText: "The line chart shows annual rainfall (mm) in a region over five years, while the process diagram shows the water purification and distribution system. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["2019", "2020", "2021", "2022", "2023"],
                series: [
                    ChartSeries(name: "Annual Rainfall", unit: "mm", values: [820, 640, 910, 750, 580])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Reservoir Collection", detail: "Surface runoff captured in primary mountain reservoir.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Flocculation & Sand Filtration", detail: "Chemical coagulants added; water passed through multi-layer sand beds.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Chlorination & Storage", detail: "Disinfected with chlorine gas and pumped to elevated municipal storage towers.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Mains Supply", detail: "Distributed via gravity-fed underground pipe network to residential and industrial users.", nextStepNumber: nil)
                ]
            ),
            companionTask2ID: "T2-006",
            companionTask2Prompt: "Water scarcity is becoming a global issue. Should water consumption be strictly rationed by law, or should market pricing be used to manage demand?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-007",
            shortTitle: "风力发电与化石能源占比",
            category: .lineGraph,
            difficultyBand: "Band 6.5-7.5",
            promptText: "The line graph shows the percentage of electricity generated from wind power compared to fossil fuels in Country Y between 2005 and 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["2005", "2010", "2015", "2020", "2025"],
                series: [
                    ChartSeries(name: "Wind Power", unit: "%", values: [3, 9, 21, 38, 54]),
                    ChartSeries(name: "Fossil Fuels", unit: "%", values: [82, 74, 59, 42, 28])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-007",
            companionTask2Prompt: "Some argue that renewable energy generation is unreliable and governments should continue investing in nuclear power. Discuss both views and give your opinion.",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-008",
            shortTitle: "大学毕业生就业分布",
            category: .pieChart,
            difficultyBand: "Band 6.0-7.0",
            promptText: "The pie charts illustrate the career outcomes of university graduates from University Z in 2015 and 2023. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: [
                    "Full-time Employment": 58,
                    "Further Study / Research": 18,
                    "Part-time Employment": 10,
                    "Self-employed / Freelance": 9,
                    "Unemployed / Seeking Work": 5
                ],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-008",
            companionTask2Prompt: "Many university graduates are unable to find jobs related to their degree fields. Why is this happening, and what measures can universities take to address this problem?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-009",
            shortTitle: "城市海滨公园规划变迁",
            category: .map,
            difficultyBand: "Band 7.0-8.0",
            promptText: "The maps show the layout of a coastal city park in 1980 and the proposed redevelopment plan for 2026. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: MapComparisonPayload(
                    beforeYearLabel: "Existing Park Layout (1980)",
                    afterYearLabel: "Proposed Redevelopment (2026)",
                    beforeFeatures: [
                        MapStageFeature(label: "Surface car park", region: "North-West", status: "removed"),
                        MapStageFeature(label: "Open lawn & rose garden", region: "Center", status: "retained"),
                        MapStageFeature(label: "Disused Bandstand", region: "East", status: "removed")
                    ],
                    afterFeatures: [
                        MapStageFeature(label: "Underground parking & EV chargers", region: "North-West", status: "added"),
                        MapStageFeature(label: "Open-air amphitheatre", region: "East", status: "added"),
                        MapStageFeature(label: "Expanded wetlands pond & boardwalk", region: "South", status: "expanded"),
                        MapStageFeature(label: "Playground & fitness zone", region: "East", status: "added"),
                        MapStageFeature(label: "Community cafe & cycle racks", region: "North", status: "added")
                    ]
                ),
                processSteps: nil
            ),
            companionTask2ID: "T2-010",
            companionTask2Prompt: "Public parks and green spaces are essential for urban residents' physical and mental wellbeing. How can city planners balance green spaces with the need for commercial and residential buildings?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-011",
            shortTitle: "Solar panel recycling",
            category: .processDiagram,
            difficultyBand: "Band 7.0-8.0",
            promptText: "The diagram below illustrates the closed-loop industrial process for recycling end-of-life photovoltaic solar panels into purified raw materials. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://howtodoielts.com/ielts-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1", "2", "3", "4", "5"],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Frame Dismantling", detail: "Aluminum frames and junction boxes are detached.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Thermal Delamination", detail: "500°C furnace evaporates encapsulating polymer.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Optical Glass Separation", detail: "95% glass cullet separated on vibrating conveyors.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Chemical Metal Leaching", detail: "Acid leaching extracts silver and copper.", nextStepNumber: 5),
                    ProcessStepPayload(stepNumber: 5, title: "Wafer Ingot Recasting", detail: "Purified silicon melted into new solar ingots.", nextStepNumber: nil)
                ]
            ),
            companionTask2ID: "T2-011",
            companionTask2Prompt: "While renewable energy technologies reduce carbon emissions, their manufacturing and disposal also create environmental challenges. To what extent should manufacturers be legally responsible for recycling their products?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-012",
            shortTitle: "Renewable energy & storage",
            category: .mixedChart,
            difficultyBand: "Band 7.5-8.5",
            promptText: "The line graph below shows renewable electricity generation (in TWh) from wind, solar, and hydro in a Nordic country from 2010 to 2025, while the pie chart shows the share of grid battery storage capacity by sector in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["2010", "2015", "2020", "2025"],
                series: [
                    ChartSeries(name: "Hydropower", unit: "TWh", values: [62, 65, 68, 70]),
                    ChartSeries(name: "Wind Power", unit: "TWh", values: [6, 16, 29, 44]),
                    ChartSeries(name: "Solar PV", unit: "TWh", values: [0.5, 2.0, 6.5, 15.0])
                ],
                pieSlicePercentages: ["Utility Grid": 52, "Industrial": 28, "Residential": 20],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-012",
            companionTask2Prompt: "Some people argue that transitioning completely to renewable energy is too expensive for developing economies. Discuss both views and give your own opinion.",
            notes: nil
        )
    ]

    public static let builtInTask2Topics: [LumaTask2TopicItem] = [
        LumaTask2TopicItem(id: "教01", shortTitle: "育儿培训的必要性", category: "教育", subCategory: "教育", promptText: "Caring for children is probably the most important thing of the society. It is suggested that all mothers and fathers should be required to take childcare training courses. To what extent do you agree or disagree with the statement?", positivePoints: ["attend parenting courses — 参加育儿培训课程", "prepare first-time parents for common childcare challenges — 帮助初为父母者应对常见育儿难题"], negativePoints: ["treat parenting as an instinctive skill — 将育儿视为无需学习的本能技能", "impose mandatory training on all parents regardless of need — 不论个人需求强制所有家长受训"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教02", shortTitle: "家长溺爱孩子的后果", category: "教育", subCategory: "教育", promptText: "Some parents give their children everything that their children ask for or allow them to do whatever they want to do. Is this good for children? What could be consequences for these children when they grow up?", positivePoints: ["develop a child's self-discipline — 培养孩子的自律能力", "set consistent boundaries for children's behaviour — 为儿童行为设定一致的界限"], negativePoints: ["give in to every demand — 对孩子的每个要求都让步", "encourage a sense of entitlement in adulthood — 使孩子成年后形成理所应得的心态"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教03", shortTitle: "儿童犯错的自由与管控", category: "教育", subCategory: "教育", promptText: "Some people think children have the freedom to make mistakes, while other people believe that adults should prevent children from making mistakes. Discuss both sides and give your opinion.", positivePoints: ["learn from their own mistakes — 从自己的错误中学习", "allow children to experience manageable setbacks — 让儿童经历可承受的挫折"], negativePoints: ["shield children from every failure — 让孩子完全不经历失败", "prevent children from developing sound judgement — 阻碍孩子形成良好判断力"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教04", shortTitle: "成人扫盲教育的重要性", category: "教育", subCategory: "教育", promptText: "Education of young people is highly prioritized in many countries. However, educating adults who cannot write or read is even more important and governments should spend more money on this. To what extent do you agree or disagree?", positivePoints: ["provide adult literacy programmes — 提供成人识字课程", "help adults complete everyday forms independently — 帮助成人独立填写日常表格"], negativePoints: ["leave adults with limited literacy skills — 使成人缺乏基本读写技能", "leave illiterate adults vulnerable to exploitation — 使不识字成人容易遭受剥削"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教05", shortTitle: "家庭教育替代学校教育", category: "教育", subCategory: "教育", promptText: "In some countries, there has been an increase in the number of parents who educate their children themselves at home instead of sending them to school. Do you think the advantages of this outweigh the disadvantages?", positivePoints: ["adapt lessons to a child's pace — 根据孩子的进度调整课程", "tailor home-based lessons to individual interests — 根据个体兴趣设计家庭授课"], negativePoints: ["miss out on peer interaction — 错失同伴互动机会", "lack regular opportunities to practise teamwork — 缺乏定期练习团队协作的机会"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教06", shortTitle: "家庭背景与成长适应", category: "教育", subCategory: "教育", promptText: "Children who are brought up in families that do not have large amounts of money are better prepared to deal with the problems of adult life than children brought up by wealthy parents. To what extent do you agree or disagree with this opinion?", positivePoints: ["build resilience through hardship — 通过困境培养韧性", "teach children to manage limited household budgets — 教孩子管理有限的家庭预算"], negativePoints: ["lack exposure to financial challenges — 缺乏应对经济困难的经历", "associate material wealth with personal worth — 将物质财富等同个人价值"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教07", shortTitle: "实习的利弊影响", category: "教育", subCategory: "教育", promptText: "A number of tertiary courses require students to undertake a period of unpaid work at companies or organisation as part of their programme. What are the advantages and disadvantages of this type of course requirement?", positivePoints: ["apply classroom knowledge in the workplace — 在职场应用课堂知识", "build professional contacts during work placements — 在实习期间建立职业人脉"], negativePoints: ["work without financial compensation — 无报酬地工作", "exclude students who cannot afford unpaid placements — 让无法负担无薪实习的学生失去机会"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教08", shortTitle: "学校教学内容的价值", category: "教育", subCategory: "教育", promptText: "Some people claim many things that children are taught at school are a waste of time. Other people argue that everything taught at school is useful at some time. Discuss both views and give your own opinion.", positivePoints: ["teach transferable life skills — 教授可迁移的生活技能", "include financial literacy in secondary-school lessons — 将理财知识纳入中学课程"], negativePoints: ["devote excessive time to irrelevant content — 在无关内容上花费过多时间", "crowd out useful practical subjects with outdated material — 以过时内容挤占实用学科时间"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教09", shortTitle: "儿童手写技能的必要性", category: "教育", subCategory: "教育", promptText: "In the modern age, some people think it is unnecessary to teach children the skill of handwriting. To what extent do you agree or disagree?", positivePoints: ["maintain legible handwriting — 保持清晰易读的手写能力", "support note-taking without electronic devices — 支持在没有电子设备时记笔记"], negativePoints: ["lose confidence in writing by hand — 失去手写信心", "allocate scarce class time to handwriting drills — 将有限课时用于重复手写训练"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教10", shortTitle: "社交技能与学术资格", category: "教育", subCategory: "教育", promptText: "Some people think that social skills are as important as academic qualifications. To what extent do you agree or disagree?", positivePoints: ["combine academic knowledge with interpersonal skills — 兼顾学术知识与人际技能", "improve students' ability to resolve interpersonal conflicts — 提高学生解决人际冲突的能力"], negativePoints: ["lack the social skills required at work — 缺乏职场所需社交能力", "assume academic certificates guarantee workplace competence — 误以为学历证书能够保证职场胜任力"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教11", shortTitle: "语言培训班型大小", category: "教育", subCategory: "教育", promptText: "Some people think that language should be taught in small classes, while other people think the number of students in a language class does not matter. Discuss both views and give your opinion.", positivePoints: ["give learners more speaking time — 给学习者更多开口机会", "provide targeted pronunciation feedback in smaller groups — 在小班中提供有针对性的发音反馈"], negativePoints: ["limit individual feedback in large classes — 大班教学限制个别反馈", "reduce opportunities for individual speaking practice — 减少每位学生的个人口语练习机会"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教12", shortTitle: "在线教育的利弊分析", category: "教育", subCategory: "教育", promptText: "Universities and colleges are now offering qualifications through distance learning from the Internet rather than teachers in the classroom. Do you think the advantages of this development outweigh the disadvantages?", positivePoints: ["study at one's own pace — 按个人节奏学习", "remove geographical barriers to university study — 消除大学学习的地域限制"], negativePoints: ["struggle to stay motivated online — 在线学习时难以保持动力", "struggle to assess students' practical abilities remotely — 难以远程评估学生的实际操作能力"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教13", shortTitle: "高中毕业后间隔年的影响", category: "教育", subCategory: "教育", promptText: "In some countries many young people choose to work or travel for a year between finishing high school and starting university studies. Discuss the advantages and disadvantages.", positivePoints: ["gain independence during a gap year — 通过间隔年增强独立性", "explore possible career paths before enrolling at university — 入大学前探索可能的职业方向"], negativePoints: ["delay entry into higher education — 推迟进入高等教育", "lose study habits during an extended break — 在长期休学期间失去学习习惯"], examDate: "20240803", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教14", shortTitle: "孩子成长的内外影响因素", category: "教育", subCategory: "教育", promptText: "Some people believe that parents have great influence on children’s growth but others think that influence from the outside plays a more important role. Discuss both these views and give your own opinion.", positivePoints: ["provide consistent parental guidance — 提供持续的家长指导", "model constructive behaviour within the family — 家庭成员以建设性行为作榜样"], negativePoints: ["be exposed to negative peer influence — 受到同伴不良影响", "underestimate the influence of online peer groups — 低估网络同伴群体的影响"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教15", shortTitle: "青少年选课的侧重方向", category: "教育", subCategory: "教育", promptText: "Some people believe that teenagers should concentrate on all school subjects. Others believe that teenagers should focus on the subject that they are best at or that they find the most interesting. Discuss both these views and give your own opinion.", positivePoints: ["pursue subjects that match personal strengths — 学习与个人优势匹配的科目", "allow teenagers to develop strengths in chosen subjects — 允许青少年深化擅长的学科"], negativePoints: ["miss out on a broad education — 错失广泛的基础教育", "leave teenagers with gaps in essential knowledge — 使青少年欠缺必要的基础知识"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教16", shortTitle: "教师在现代教育的角色", category: "教育", subCategory: "教育", promptText: "In the past, teachers were the main source of information, but today students have a wide source of information, so teachers are no longer important in the modern education. Do you agree or disagree?", positivePoints: ["receive guidance from experienced teachers — 获得资深教师的指导", "explain complex concepts beyond what websites can provide — 解释网站难以充分说明的复杂概念"], negativePoints: ["rely solely on online sources — 完全依赖网络资料", "reduce teachers to mere providers of information — 将教师的作用缩减为提供信息"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教17", shortTitle: "高中艺术课程的强制性", category: "教育", subCategory: "教育", promptText: "Some people say that art subjects such as painting or drawing should not be made compulsory for high school students. To what extent do you agree or disagree?", positivePoints: ["use arts education to foster creativity — 通过艺术教育培养创造力", "help students express ideas through drawing and painting — 帮助学生通过绘画表达想法"], negativePoints: ["make arts subjects compulsory for everyone — 强制所有人学习艺术科目", "increase pressure on students with little interest in art — 增加对艺术兴趣不高学生的压力"], examDate: "20241214", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教18", shortTitle: "院校男女选课差异分析", category: "教育", subCategory: "教育", promptText: "In schools and universities, girls tend to choose art subjects, while boys choose science subjects. What is the reason? Should the trend be changed?", positivePoints: ["challenge gender-based subject choices — 挑战基于性别的选课偏见", "encourage girls to consider engineering and boys to consider the arts — 鼓励女生选择工程及男生选择艺术"], negativePoints: ["reinforce stereotypes about boys and girls — 强化男女生的刻板印象", "base course choices on gender expectations — 按性别期待决定课程选择"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "教19", shortTitle: "中学教育的内容范围", category: "教育", subCategory: "教育", promptText: "In some countries, secondary schools aim to provide a general education across a range of subjects. In others, children focus on a narrow range of subjects related to a particular career. Which do you think is appropriate in today’s world?", positivePoints: ["combine broad knowledge with vocational skills — 兼顾广泛知识与职业技能", "combine academic subjects with career-related modules — 将学术学科与职业相关模块结合"], negativePoints: ["specialise in one field too early — 过早专攻某一领域", "narrow students' future options through early specialisation — 因过早专业化而缩窄未来选择"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科01", shortTitle: "科技对老年人的帮助", category: "科技", subCategory: "科技", promptText: "Mobile phones and the internet bring a lot of benefits to people nowadays. However, older people use them the least. In what aspects do mobile phones and the internet benefit older people? How can we encourage them to use these technologies?", positivePoints: ["help older adults use digital services — 帮助老年人使用数字服务", "teach seniors to use online appointment systems safely — 教老年人安全使用线上预约系统"], negativePoints: ["exclude seniors unfamiliar with smartphones — 排除不熟悉智能手机的老年人", "make essential services inaccessible without an app — 使无应用程序者无法获得基本服务"], examDate: "20240518", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科02", shortTitle: "机器人替代家务工作影响", category: "科技", subCategory: "科技", promptText: "Today, there are many tasks at home or work that are done by robots. Is this a positive or negative development?", positivePoints: ["reduce the burden of household chores — 减轻家务劳动负担", "free parents from repetitive cleaning tasks — 将家长从重复清洁工作中解放出来"], negativePoints: ["become overly dependent on domestic robots — 过度依赖家用机器人", "make repairs to domestic robots costly and inconvenient — 使家用机器人维修昂贵且不便"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科03", shortTitle: "无人驾驶汽车的社会影响", category: "科技", subCategory: "科技", promptText: "It will be better to have wide use of driverless cars for individuals and society. To what extent do you agree or disagree with the statement?", positivePoints: ["reduce accidents caused by human error — 减少人为失误造成的事故", "support independent travel for people unable to drive — 帮助无法驾驶的人独立出行"], negativePoints: ["raise concerns about system failures — 引发系统故障方面的担忧", "leave passengers unable to respond to unexpected road conditions — 令乘客难以应对意外道路状况"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科04", shortTitle: "科技对读写能力的影响", category: "科技", subCategory: "科技", promptText: "Some people think that the increasing use of computers and mobile phones for communication has a negative effect on young people’s reading and writing skills. Do you agree or disagree?", positivePoints: ["provide tools for reading and writing practice — 提供读写练习工具", "use spelling software to support reluctant writers — 用拼写软件帮助不愿写作的学生"], negativePoints: ["weaken spelling and handwriting skills — 削弱拼写和书写能力", "replace sustained reading with short digital messages — 用简短电子信息取代持续阅读"], examDate: "20240720", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科05", shortTitle: "电脑作为重要发明的定位", category: "科技", subCategory: "科技", promptText: "Computers are often argued to be the most important invention of the last hundred years. To what extent do you agree or disagree with this statement?", positivePoints: ["transform the way people process information — 改变人们处理信息的方式", "make large-scale data analysis possible — 实现大规模数据分析"], negativePoints: ["contribute to excessive screen exposure — 造成过度屏幕接触", "create dependence on computers for basic calculations — 造成基本计算对电脑的依赖"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科06", shortTitle: "在线商务培训的利弊分析", category: "科技", subCategory: "科技", promptText: "Research says more and more business training and business meeting are taking place online. Do the advantages outweigh the disadvantages?", positivePoints: ["make workplace training available remotely — 让员工能远程参加职场培训", "reduce travel costs for staff attending corporate training — 降低员工参加企业培训的差旅成本"], negativePoints: ["reduce opportunities for informal networking — 减少非正式社交机会", "make confidential business discussions vulnerable to leaks — 使机密商务讨论面临信息泄漏"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科07", shortTitle: "技术引发及解决环境问题", category: "科技", subCategory: "科技", promptText: "Developments in science and technology have caused environmental problems. Some people think that a simpler way of life will protect the environment, while others believe that science and technology can solve environmental problems. Discuss both views and give your own opinion.", positivePoints: ["develop cleaner industrial technologies — 研发更清洁的工业技术", "use cleaner manufacturing processes to reduce industrial pollution — 通过更清洁的生产工艺减少工业污染"], negativePoints: ["create electronic waste and resource demand — 产生电子垃圾和资源需求", "increase demand for energy-intensive electronic devices — 增加高能耗电子设备的需求"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科08", shortTitle: "科技与艺术的价值对比", category: "科技", subCategory: "科技", promptText: "Today, advanced science and technology have made great changes to people’s life, but artists such as musicians, painters and writers are still highly valued. What can arts tell us about life that science and technology cannot?", positivePoints: ["capture human emotions through art — 通过艺术传达人类情感", "preserve experiences that cannot be expressed through scientific measurements — 保留科学测量难以表达的人类体验"], negativePoints: ["overemphasise measurable scientific outcomes — 过分强调可量化的科研成果", "dismiss artistic work as economically unproductive — 将艺术创作视为没有经济产出"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科09", shortTitle: "网购取代实体店购物趋势", category: "科技", subCategory: "科技", promptText: "Online shopping is now replacing shopping in the store. Do you think it is a positive or negative development?", positivePoints: ["compare prices across online retailers — 比较线上零售商价格", "help consumers find specialist goods unavailable locally — 帮助消费者购买当地无法找到的专门商品"], negativePoints: ["drive small high-street shops out of business — 使街边小商店难以生存", "increase packaging waste from home deliveries — 增加送货包装垃圾"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科10", shortTitle: "机器替代人力工作的影响", category: "科技", subCategory: "科技", promptText: "Nowadays, more and more jobs and tasks which involve hard physical work are done by machines. Do the positive effects of this trend outweigh the negative effects?", positivePoints: ["replace hazardous manual tasks with machines — 用机器代替危险体力劳动", "protect factory workers from exposure to dangerous machinery — 保护工厂工人免于接触危险机械"], negativePoints: ["eliminate routine low-skilled jobs — 减少常规低技能岗位", "make manual skills less valuable in automated industries — 使人工操作技能在自动化产业中贬值"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科11", shortTitle: "手机电脑削弱当面沟通", category: "科技", subCategory: "科技", promptText: "Some people think that with the increasing use of mobile phones and computers, people lose the ability to communicate face to face. To what extent do you agree or disagree?", positivePoints: ["stay connected across long distances — 跨越距离保持联系", "maintain family relationships through regular video calls — 通过定期视频通话维系家庭关系"], negativePoints: ["replace face-to-face conversations with messages — 用信息沟通取代当面交谈", "erode the quality of in-person conversations — 削弱面对面交谈的质量"], examDate: "20241116、20250222", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "科12", shortTitle: "跨国生活工作的利弊", category: "科技", subCategory: "科技", promptText: "Nowadays, people in some countries can choose to live and work anywhere they want because of the improvement of the transportation and communication technologies. Discuss the benefits and the drawbacks of the phenomenon.", positivePoints: ["work remotely across national borders — 跨越国界远程工作", "create employment options beyond major cities — 在大城市之外创造就业选择"], negativePoints: ["blur the boundary between work and private life — 模糊工作与私人生活的界限", "complicate the enforcement of labour rules across borders — 增加跨境劳动法规执行难度"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社01", shortTitle: "国家间差异缩小的影响", category: "社会", subCategory: "社会", promptText: "There are fewer and fewer differences between countries. People around the world may watch the same kinds of TV series, buy goods of same brands, and follow the same trends. Discuss the advantages and disadvantages of this phenomenon.", positivePoints: ["encourage understanding between nations — 促进国家间理解", "encourage appreciation of products from other cultures — 鼓励欣赏来自不同文化的商品"], negativePoints: ["make consumer cultures increasingly uniform — 使消费文化日益趋同", "erode distinctive national cultural traditions — 侵蚀独特的民族文化传统"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社02", shortTitle: "西式服装取代传统服装", category: "社会", subCategory: "社会", promptText: "Nowadays, people tend to wear western style clothes rather than traditional clothes. What are the reasons? Do you think it is a positive or negative development?", positivePoints: ["allow people to express individual style — 让人表达个人穿衣风格", "make everyday clothing more practical and affordable — 让日常服饰更实用且经济"], negativePoints: ["replace locally distinctive traditional dress — 取代富有地方特色的传统服装", "reduce demand for traditional textile crafts — 降低传统纺织手工艺需求"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社03", shortTitle: "食品浪费的成因与解决", category: "社会", subCategory: "社会", promptText: "In some countries, people waste a lot of food which is bought in shops and restaurants. What do you think are the reasons? What can be done to solve this problem？", positivePoints: ["redistribute surplus edible food — 重新分配可食用的剩余食品", "introduce portion-control measures in restaurants — 在餐馆推行控制份量措施"], negativePoints: ["discard food that is still safe to eat — 丢弃仍可安全食用的食物", "waste scarce water and farmland through discarded food — 因丢弃食物浪费稀缺的水和农田资源"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社04", shortTitle: "人类对时尚的模仿倾向", category: "社会", subCategory: "社会", promptText: "The tendency of human beings to copy one another is shown in the popularity of fashion in clothes and consumer goods. To what extent do you agree and disagree?", positivePoints: ["express personal identity through fashion — 通过时尚表达个人身份", "help local designers reach wider markets — 帮助本地设计师接触更广阔的市场"], negativePoints: ["follow trends without independent judgement — 不经独立判断地追随潮流", "promote unnecessary purchases to keep up with fashion — 推动人们为追赶潮流而不必要地购物"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社05", shortTitle: "产假的利弊影响", category: "社会", subCategory: "社会", promptText: "In many countries, women are allowed to take maternity leave from their jobs during the first months after the birth of their baby. Do the advantages outweigh the disadvantages?", positivePoints: ["provide paid maternity leave — 提供带薪产假", "allow new mothers adequate time to recover physically — 给予新妈妈充足的身体恢复时间"], negativePoints: ["interrupt women's career progression — 中断女性职业发展", "place short-term staffing pressure on small businesses — 给小企业带来短期人员安排压力"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社06", shortTitle: "男性全职带娃的影响", category: "社会", subCategory: "社会", promptText: "In many countries, more and more men are staying at home to look after their children when women work full-time. What are the reasons? Is it a positive or negative development?", positivePoints: ["encourage fathers to take on childcare duties — 鼓励父亲承担育儿责任", "allow mothers to return to full-time employment — 让母亲能够重返全职工作"], negativePoints: ["face stigma as a stay-at-home father — 全职父亲遭受社会偏见", "assume fathers are less capable of caring for infants — 误以为父亲更不擅长照顾婴儿"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社07", shortTitle: "男女分担家务的平等性", category: "社会", subCategory: "社会", promptText: "Today, in many countries, both women and men work full-time. Logically, women and men should share household tasks equally. To what extent do you agree or disagree？", positivePoints: ["share household duties fairly — 公平分担家务", "reduce conflict over unpaid domestic labour — 减少无偿家务劳动引发的争执"], negativePoints: ["place the domestic workload on women — 将家务负担集中于女性", "reinforce the belief that housework is women's responsibility — 强化家务是女性责任的观念"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社08", shortTitle: "财富差距与社会幸福感", category: "社会", subCategory: "社会", promptText: "Some people believe that the best way to produce a happier society is to ensure that there are only small differences between its richest and poorest members. To what extent do you agree or disagree?", positivePoints: ["narrow the gap between rich and poor — 缩小贫富差距", "make public opportunities less dependent on family wealth — 降低公共机会对家庭财富的依赖"], negativePoints: ["concentrate wealth among a small elite — 使财富集中于少数精英", "fuel resentment between different income groups — 加剧不同收入群体间的不满"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社09", shortTitle: "提高法定驾驶年龄的影响", category: "社会", subCategory: "社会", promptText: "Some people think that the best way to improve road safety is to increase the minimum legal age for driving cars and motorcycles. To what extent do you agree or disagree?", positivePoints: ["assess young drivers' readiness — 评估年轻司机的驾驶准备程度", "allow older teenagers to practise driving under supervision — 让年长青少年在监督下练习驾驶"], negativePoints: ["restrict mobility for responsible young adults — 限制守法年轻人的出行", "delay access to essential transport in rural areas — 推迟农村地区青年获得必要交通方式"], examDate: "20251227", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社10", shortTitle: "道路安全的处罚管控方式", category: "社会", subCategory: "社会", promptText: "Some people think that the only way to improve the safety of our roads is to give much stricter punishments for driving offenses. To what extent do you agree or disagree?", positivePoints: ["impose proportionate penalties for traffic offences — 对交通违法施加相称处罚", "combine penalties with road-safety education — 将处罚与道路安全教育结合"], negativePoints: ["rely on punishment without driver education — 只依靠处罚而缺少驾驶教育", "penalise minor offences without addressing dangerous habits — 惩罚轻微违法却未纠正危险驾驶习惯"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社11", shortTitle: "医药研究的资金来源主体", category: "社会", subCategory: "社会", promptText: "Research into new types of medicines and treatments are essential for improving health and dealing with diseases. Who do you think should fund these researches: private companies, individuals or governments?", positivePoints: ["fund independent medical research — 资助独立的医学研究", "ensure new treatments address neglected diseases — 确保新疗法关注被忽视的疾病"], negativePoints: ["let commercial interests shape research priorities — 让商业利益左右研究重点", "favour profitable medicines over treatments for rare diseases — 偏重盈利药物而忽略罕见病治疗"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社12", shortTitle: "职场努力工作的驱动因素", category: "社会", subCategory: "社会", promptText: "In education and employment, some people work harder than others. Why do some people work harder? Is it always a good thing to work hard?", positivePoints: ["recognise effort and personal achievement — 认可努力与个人成就", "motivate employees through recognition rather than pay alone — 以认可而非仅靠薪资激励员工"], negativePoints: ["promote a culture of constant overwork — 助长持续过劳文化", "reward long hours regardless of the quality of work — 无论工作质量都奖励长工时"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社13", shortTitle: "道路交通安全的改善措施", category: "社会", subCategory: "社会", promptText: "Some people think that the best way to improve road transport safety is to let the driver test each year. To what extent do you agree or disagree?", positivePoints: ["require periodic driving assessments — 要求定期驾驶能力评估", "identify drivers whose eyesight or reactions have declined — 识别视力或反应能力下降的驾驶者"], negativePoints: ["add unnecessary costs for experienced drivers — 为经验丰富司机增加不必要费用", "require frequent tests without evidence of improved safety — 在缺乏安全改善证据时频繁要求测试"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社14", shortTitle: "城市小户型居住的影响", category: "社会", subCategory: "社会", promptText: "With growing population in cities, more and more people live in a home with small or no outdoor areas. Is it a positive or negative development?", positivePoints: ["make efficient use of limited urban space — 高效利用有限城市空间", "provide compact homes near workplaces and services — 在工作地点与公共服务附近提供紧凑住房"], negativePoints: ["live in cramped accommodation — 居住在狭小拥挤的住所", "deprive residents of private outdoor areas — 剥夺居民私人户外空间"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社15", shortTitle: "财富增长与国民幸福感", category: "社会", subCategory: "社会", promptText: "Some experts suppose that when a country is already rich, any additional increase in economic wealth does not make its citizens happier. To what extent do you agree or disagree?", positivePoints: ["invest additional wealth in public well-being — 将新增财富投入公共福祉", "use national wealth to expand access to health care — 利用国家财富扩大医疗服务覆盖"], negativePoints: ["assume higher income always brings happiness — 误以为收入增加必然带来幸福", "measure national well-being only through economic output — 仅用经济产出来衡量国民幸福"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社16", shortTitle: "年轻人离开家乡的发展影响", category: "社会", subCategory: "社会", promptText: "Young people are leaving their homes from rural areas to study or work in the cities.What are the reasons? Do advantages of this development outweigh its disadvantages?", positivePoints: ["access better jobs in large cities — 在大城市获得更好工作", "send earnings back to support families in rural communities — 向农村家庭汇回工资收入"], negativePoints: ["accelerate population decline in rural areas — 加快农村人口减少", "drain rural communities of young skilled workers — 使农村地区流失有技能的年轻劳动力"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社17", shortTitle: "独人们居家时间减少的影响", category: "社会", subCategory: "社会", promptText: "Today many people spend less and less time in their homes. What are the reasons and what are the effects of this trend on individuals and society?", positivePoints: ["spend more meaningful time with family — 增加与家人相处的高质量时间", "make better use of time through remote working — 通过远程工作更有效利用时间"], negativePoints: ["reduce time spent together at home — 减少在家共同相处的时间", "leave family members with fewer shared routines — 使家庭成员减少共同的日常活动"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社18", shortTitle: "老年人居住方式的选择影响", category: "社会", subCategory: "社会", promptText: "Nowadays some older people choose to live in retirement communities with other people instead of living with their adult children. Is it a positive or negative development?", positivePoints: ["access care in retirement communities — 在退休社区获得照护", "create peer-support communities for older residents — 为老年居民建立同伴互助社区"], negativePoints: ["lose regular contact with adult children — 减少与成年子女的日常接触", "separate elderly residents from familiar neighbourhoods — 让老年人远离熟悉的街区"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社19", shortTitle: "私家车普及的个体与环境影响", category: "社会", subCategory: "社会", promptText: "As countries develop, more and more people buy and use their own cars. Do you think the advantages of this trend for individuals outweigh the disadvantages for the environment?", positivePoints: ["enjoy the convenience of private cars — 享受私家车便利", "make shopping and medical visits easier by car — 通过汽车便利购物和就医"], negativePoints: ["increase dependence on car travel — 加深对汽车出行的依赖", "increase congestion around schools and shopping areas — 加剧学校与购物区周边拥堵"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社20", shortTitle: "经济增长与环境的关系", category: "社会", subCategory: "社会", promptText: "Some people say economic growth is the only way to end world poverty and hunger, while others say economic growth is damaging the environment and must stop. Discuss both views and give your own opinion.", positivePoints: ["pursue growth without degrading ecosystems — 追求不破坏生态的经济增长", "lift households out of poverty through productive employment — 通过有生产力的就业帮助家庭脱贫"], negativePoints: ["treat environmental damage as an acceptable cost — 将环境破坏视为可接受代价", "deplete natural resources in pursuit of short-term growth — 追求短期增长而耗竭自然资源"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社21", shortTitle: "通勤方式优化的可行性", category: "社会", subCategory: "社会", promptText: "Some people think that the best way to reduce the time spent in travelling to work is to replace parks and gardens close to the city center with apartment buildings for commuters. To what extent do you agree or disagree with the statement?", positivePoints: ["build housing near employment centres — 在就业中心附近建住房", "shorten daily commutes through mixed-use development — 通过混合用途开发缩短每日通勤"], negativePoints: ["remove urban parks to shorten commutes — 为缩短通勤而拆除城市公园", "remove green spaces that improve urban well-being — 移除改善城市福祉的绿地"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社22", shortTitle: "女性任职军警岗位的适配性", category: "社会", subCategory: "社会", promptText: "Some people believe that women should play an equal role as men in a country's police force or military force, while others think women are not suitable for these kinds of jobs. Discuss both views and give your opinion.", positivePoints: ["recruit people based on competence — 按能力而非性别招聘", "ensure women can pursue military and police careers on merit — 确保女性凭能力进入军警职业"], negativePoints: ["exclude qualified women from security roles — 将合格女性排除在安全岗位外", "judge applicants by stereotypes rather than job requirements — 凭刻板印象而非岗位要求评价申请者"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社23", shortTitle: "体育成功的影响因素", category: "社会", subCategory: "社会", promptText: "Some people argue that the fittest and strongest individuals and teams can achieve the greatest success in sports. But other people think success is much related to the mental attitude. Discuss both views and give your opinion.", positivePoints: ["combine physical training with mental preparation — 结合体能训练与心理准备", "train athletes to stay focused under competitive pressure — 训练运动员在比赛压力下保持专注"], negativePoints: ["overlook the psychological demands of sport — 忽视运动的心理要求", "overtrain athletes while ignoring recovery needs — 让运动员过度训练却忽视恢复"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社24", shortTitle: "人生成功的影响因素", category: "社会", subCategory: "社会", promptText: "Some people think that success in life comes from hard work and determination, while others think that there are more important factors such as money and appearance. Discuss both views and give your opinion.", positivePoints: ["reward determination and sustained effort — 奖励决心和持续努力", "make opportunities accessible regardless of family background — 让不同家庭背景的人都能获得机会"], negativePoints: ["judge success by wealth or appearance alone — 仅以财富或外表衡量成功", "allow inherited wealth to outweigh individual effort — 让继承的财富盖过个人努力"], examDate: "20240309", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社25", shortTitle: "航空旅行的受益群体", category: "社会", subCategory: "社会", promptText: "Air travel can only benefit the richest people in the world. Ordinary people have little to gain from the development of air travel. To what extent do you agree or disagree?", positivePoints: ["make air travel accessible to ordinary travellers — 让普通旅客负担得起航空旅行", "help low-income families travel to visit relatives abroad — 帮助低收入家庭乘飞机探望海外亲属"], negativePoints: ["reserve the benefits of aviation for wealthy people — 让航空发展红利主要由富人享有", "subsidise air routes used mainly by affluent travellers — 补贴主要由富裕乘客使用的航线"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社26", shortTitle: "社会运行的规则依托", category: "社会", subCategory: "社会", promptText: "Some people believe that the society should be based on rules and laws. To what extent do you agree or disagree?", positivePoints: ["uphold the rule of law — 维护法治", "establish predictable rules for resolving disputes — 建立可预测的争议解决规则"], negativePoints: ["restrict freedom through excessive regulation — 因过度监管限制自由", "use vague laws to restrict legitimate personal choices — 利用模糊法律限制合理的个人选择"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社27", shortTitle: "晚育的原因及发展影响", category: "社会", subCategory: "社会", promptText: "In some countries men and women are having babies late in life. What are the reasons? Is it a positive or negative development?", positivePoints: ["plan childbirth around financial stability — 根据经济稳定性安排生育", "allow prospective parents to establish stable careers first — 让准父母先建立稳定事业"], negativePoints: ["face increased age-related fertility risks — 面临随年龄增加的生育风险", "reduce the years available for parents to raise children — 减少父母陪伴孩子成长的年限"], examDate: "20240810", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社28", shortTitle: "多元文化群体的发展", category: "社会", subCategory: "社会", promptText: "Many countries now have people from different cultures and ethnic groups. What is the reason for this? Is it a positive or negative development?", positivePoints: ["celebrate multicultural communities — 认可多元文化社区", "improve intercultural understanding through everyday contact — 通过日常接触增进跨文化理解"], negativePoints: ["encounter barriers to social integration — 面临融入社会的障碍", "encounter language barriers in multicultural neighbourhoods — 在多元文化社区遭遇语言障碍"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社29", shortTitle: "现代社会的依存独立性", category: "社会", subCategory: "社会", promptText: "Some people think that in this modern world people are getting dependent on each other, while others think the modern world makes people more independent of each other. Discuss both views and give your own opinion.", positivePoints: ["build mutual support networks — 建立相互支持网络", "share childcare and financial responsibilities within extended families — 在大家庭内分担育儿及经济责任"], negativePoints: ["become excessively reliant on others — 过度依赖他人", "lose confidence in handling problems without help — 独自处理问题时缺乏信心"], examDate: "20230706", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社30", shortTitle: "人口城乡流动的问题", category: "社会", subCategory: "社会", promptText: "The movement of people from agricultural areas to cities to work can cause serious problems in both places. What are the serious problems? What measures can be used to solve these problems?", positivePoints: ["create jobs outside major cities — 在大城市以外创造就业", "relieve pressure on crowded urban labour markets — 缓解拥挤城市劳动力市场的压力"], negativePoints: ["drain skilled workers from rural communities — 使农村社区流失技术人才", "leave rural farms without a younger generation of workers — 使农村农场缺少年轻劳动力"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社31", shortTitle: "城市种树与建房的取舍", category: "社会", subCategory: "社会", promptText: "Some people think it is more important to plant more trees in open spaces in towns and cities than to provide more housing. To what extent do you agree or disagree?", positivePoints: ["preserve urban green spaces — 保留城市绿地", "cool city streets by planting shade trees — 通过栽植遮荫树木降低城市街道温度"], negativePoints: ["sacrifice parks to new housing projects — 为住房项目牺牲公园", "restrict the supply of homes in high-demand areas — 限制住房需求高地区的住房供应"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社32", shortTitle: "独居生活的社会影响", category: "社会", subCategory: "社会", promptText: "In recent years, young people in many countries choose to live by themselves. What are the reasons and is it positive or negative for the development of the society？", positivePoints: ["learn to manage daily life independently — 学会独立安排日常生活", "learn to manage household expenses independently — 学习独立管理家庭开支"], negativePoints: ["experience loneliness while living alone — 独居时感到孤独", "experience loneliness when living alone for long periods — 长期独居时感到孤独"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社33", shortTitle: "寿命延长的社会影响", category: "社会", subCategory: "社会", promptText: "Surveys show that people are living longer in many countries. But increased life expectancy has many implications for aging individuals and for society as a whole. What are the possible effects of longer living for individuals and society?", positivePoints: ["adapt pension systems to longer lifespans — 调整养老金制度以适应寿命延长", "benefit from additional years of active retirement — 享受更多健康活跃的退休时光"], negativePoints: ["increase pressure on elderly care services — 加重老年照护服务压力", "increase demand for long-term care services — 增加长期护理服务需求"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "社34", shortTitle: "经济发展与社会价值观", category: "社会", subCategory: "社会", promptText: "Nowadays, most countries improve the standard of living through economic development. But some social values are lost as a result. Do you think the advantages of the phenomenon outweigh the disadvantages?", positivePoints: ["protect social values during economic development — 在经济发展中保护社会价值观", "raise material living standards without sacrificing community ties — 提高物质生活水平而不牺牲社区纽带"], negativePoints: ["prioritise material wealth over social relationships — 将物质财富置于社会关系之上", "weaken traditional obligations to care for relatives — 削弱照顾亲属的传统责任"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "政01", shortTitle: "接送儿童上学的责任方", category: "政府", subCategory: "政府", promptText: "Some people say it is government’s responsibility to transport children to school, while others believe parents should transport their children to school. Discuss both views and give your opinion.", positivePoints: ["provide safe school transport services — 提供安全校车服务", "provide safe school transport for children in remote areas — 为偏远地区儿童提供安全校车"], negativePoints: ["shift all school transport costs onto parents — 把接送上学全部费用转嫁给家长", "place daily transport costs entirely on parents — 将每日接送成本完全推给家长"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "政02", shortTitle: "年轻人任职政府岗位适配性", category: "政府", subCategory: "政府", promptText: "Some people think that younger people are not suitable for important positions in government. Others think that it will be a good idea for younger people to take on these positions. Discuss both these views and give your own opinion.", positivePoints: ["bring younger perspectives into policymaking — 为政策制定引入年轻人的视角", "bring younger perspectives into public decision-making — 让年轻人的视角进入公共决策"], negativePoints: ["appoint officials without sufficient experience — 任命缺乏足够经验的官员", "appoint inexperienced officials to highly complex roles — 任用缺乏经验的官员担任复杂职位"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "政03", shortTitle: "外星生命探索的资金投入", category: "政府", subCategory: "政府", promptText: "Some people think governments should spend money in looking for life on other planets, while others think that there are many unsolved problems on earth. Discuss both views and give your opinion.", positivePoints: ["balance space exploration with urgent needs on Earth — 兼顾太空探索与地球上的紧迫需求", "fund research into whether other planets could support life — 资助研究其他星球能否支持生命"], negativePoints: ["divert scarce funds from essential services — 把有限资金从基本服务中挪走", "divert funds from urgent problems on Earth — 从地球上的紧急问题转移资金"], examDate: "20250927", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "政04", shortTitle: "学校艺术体育经费投入", category: "政府", subCategory: "政府", promptText: "The government should spend money in promoting sports and art in school, rather than sponsoring professional sports and art events in communities. To what extent do you agree or disagree?", positivePoints: ["fund school sports and arts programmes — 资助学校体育和艺术项目", "make music and sports facilities accessible to schoolchildren — 让学童能使用音乐与体育设施"], negativePoints: ["concentrate subsidies on elite performers — 将补助集中于精英选手", "channel public subsidies towards elite performers alone — 只将公共补贴用于精英表演者"], examDate: "20250802", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "政05", shortTitle: "政府环保与医疗的侧重", category: "政府", subCategory: "政府", promptText: "Some people say that governments should focus on reducing environmental pollution and housing problems to help people prevent illness and disease. To what extent do you agree or disagree?", positivePoints: ["prevent illness by improving housing conditions — 通过改善住房条件预防疾病", "prevent disease by improving housing conditions — 通过改善住房条件预防疾病"], negativePoints: ["treat symptoms while neglecting environmental causes — 只治症状而忽视环境病因", "treat illnesses without addressing polluted living environments — 治疗疾病却不治理受污染的居住环境"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "政06", shortTitle: "创意艺术的政府资助", category: "政府", subCategory: "政府", promptText: "Some people think people working in creative arts should be financially supported by government. Others think they should find financial support from other resources. Discuss both sides and give your opinion.", positivePoints: ["provide grants to emerging artists — 向新兴艺术家提供资助", "support emerging artists who cannot attract commercial sponsors — 支持无法吸引商业赞助的新兴艺术家"], negativePoints: ["make artists dependent on state funding — 使艺术家依赖政府资助", "subsidise art projects with little community participation — 补贴缺少社区参与的艺术项目"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "政07", shortTitle: "医保在税收中的优先级", category: "政府", subCategory: "政府", promptText: "Some people say government should give health care the first priorities, some others believe there are more important priorities to spend the tax payers' money. Discuss both views and give your opinion.", positivePoints: ["give preventive healthcare budget priority — 优先将预算用于预防性医疗", "maintain affordable treatment for low-income patients — 让低收入病人负担得起治疗"], negativePoints: ["crowd out other essential public services — 挤占其他必要公共服务资源", "underfund schools and transport by prioritising hospitals alone — 只优先医院而使学校与交通经费不足"], examDate: "20240824", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "政08", shortTitle: "健康饮食的责任主体", category: "政府", subCategory: "政府", promptText: "The government has the duty to ensure that its citizens have a healthy diet, while others believe this is individuals' responsibility. Discuss both views and give your opinion.", positivePoints: ["set clear nutritional standards for food products — 为食品制定明确营养标准", "introduce nutrition standards for food sold in schools — 为校园食品引入营养标准"], negativePoints: ["place all dietary responsibility on individuals — 将饮食责任完全推给个人", "shift all responsibility for poor diets onto individual consumers — 将不良饮食责任全部推给个人消费者"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "媒01", shortTitle: "体育赛事的性别呈现差异", category: "媒体", subCategory: "媒体", promptText: "Today, TV channels provide men's sports shows more than women's sports shows. Why? Should TV channels give equal time for women's sports and men's sports?", positivePoints: ["give women's sports comparable media coverage — 给予女子体育相当的媒体报道", "provide equal broadcast opportunities for female athletes — 为女性运动员提供平等转播机会"], negativePoints: ["underrepresent female athletes in broadcasts — 在转播中低估女性运动员的曝光", "make women's competitions less visible to potential sponsors — 让女性赛事难以被潜在赞助商看见"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "媒02", shortTitle: "消费产品价格的社会反映", category: "媒体", subCategory: "媒体", promptText: "Today, the high sales of popular consumer goods reflect the power of advertising and not the real needs of the society in which they are sold. To what extent do you agree or disagree?", positivePoints: ["provide consumers with accurate product information — 向消费者提供准确产品信息", "stimulate demand for newly developed products — 刺激新开发商品的需求"], negativePoints: ["generate demand through aggressive advertising — 通过强势广告制造需求", "encourage consumers to purchase goods they do not need — 鼓励消费者购买不需要的商品"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "媒03", shortTitle: "网络取代传统媒体趋势", category: "媒体", subCategory: "媒体", promptText: "More and more people no longer read newspaper or watch TV programs to get news. They get news about the world through the internet. Is this a positive or negative development?", positivePoints: ["access breaking news through digital platforms — 通过数字平台获取突发新闻", "provide rapid updates on developing events — 快速提供事件的最新进展"], negativePoints: ["lose access to carefully verified reporting — 难以获取经过严格核实的报道", "allow unverified stories to spread before fact-checking — 在事实核查前让未经证实的消息扩散"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "媒04", shortTitle: "社交媒体沟通的利弊", category: "媒体", subCategory: "媒体", promptText: "Many people use social media every day to get in touch with other people and be aware of news events. Do you think the advantages of this way outweigh the disadvantages?", positivePoints: ["maintain social connections through online communities — 通过网络社区维持社交联系", "help relatives stay informed about each other's lives — 帮助亲属了解彼此近况"], negativePoints: ["compare oneself constantly with others online — 不断在网上与他人攀比", "turn social-media use into habitual comparison with others — 使社交媒体使用变为习惯性攀比"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "媒05", shortTitle: "广告的经济与社会影响", category: "媒体", subCategory: "媒体", promptText: "Some people say that advertising has positive economic effects. Others think it has negative social effects because it will make people feel dissatisfied with who they are and what they have. Discuss both views and give your own opinion.", positivePoints: ["support businesses by informing potential buyers — 通过告知潜在买家帮助企业", "inform customers about alternatives in competitive markets — 向消费者介绍竞争市场中的不同选择"], negativePoints: ["create dissatisfaction with ordinary lifestyles — 使人对普通生活产生不满", "make viewers dissatisfied with their appearance or possessions — 使观众对外表或财物感到不满"], examDate: "20240406", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "媒06", shortTitle: "儿童电视广告的管控影响", category: "媒体", subCategory: "媒体", promptText: "Nowadays, there are many television advertisements aimed at children. What are the effects of these advertisements on children? Should TV advertisements be controlled?", positivePoints: ["shield children from manipulative advertising — 保护儿童免受操纵性广告影响", "shield young children from manipulative marketing messages — 保护幼儿免受诱导性营销信息影响"], negativePoints: ["encourage children to pressure parents into purchases — 诱导儿童要求父母购物", "normalise high-sugar snacks through children's adverts — 通过儿童广告使高糖零食显得正常"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "媒07", shortTitle: "广告对生活的正负效应", category: "媒体", subCategory: "媒体", promptText: "People are surrounded by many kinds of advertising which can influence their life. Do the positive effects of this trend outweigh negative effects?", positivePoints: ["advertise socially beneficial products — 推广对社会有益的产品", "allow small businesses to reach local customers — 让小企业触及本地消费者"], negativePoints: ["normalise unnecessary purchases — 使不必要的购买常态化", "intrude on daily life through relentless promotional messages — 持续不断的推销信息侵扰日常生活"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "媒08", shortTitle: "广告对个性的抑制影响", category: "媒体", subCategory: "媒体", promptText: "dvertising discourages people from being different individuals by making us all want to do the same and look the same. To what extent do you agree or disagree?", positivePoints: ["celebrate individual tastes and preferences — 尊重个人品味与偏好", "encourage buyers to value unique personal tastes — 鼓励买家珍视独特的个人品味"], negativePoints: ["pressure consumers to conform to beauty ideals — 迫使消费者迎合审美标准", "push consumers towards the same beauty standards — 推动消费者追随同一审美标准"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "媒09", shortTitle: "新闻媒体的重要性及影响", category: "媒体", subCategory: "媒体", promptText: "News media are important in modern society. Why are they so important? Are their influences generally positive or negative?", positivePoints: ["hold public institutions accountable through reporting — 通过新闻监督公共机构", "hold powerful institutions accountable through investigative reporting — 通过调查报道监督权力机构"], negativePoints: ["spread rumours without adequate verification — 未经充分核实就传播传闻", "create public fear through sensational news coverage — 通过耸动新闻报道制造公众恐慌"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "国01", shortTitle: "国际合作的核心益处", category: "政府", subCategory: "国际", promptText: "Some people think the main benefit of international cooperation is in the protection of the environment, while others think that the main benefits are in the world of business. Discuss both views and give your own opinion.", positivePoints: ["coordinate cross-border environmental action — 协调跨国环境行动", "share environmental technology across national borders — 跨国共享环保技术"], negativePoints: ["allow commercial interests to outweigh environmental protection — 让商业利益压过环保", "let trade disputes obstruct collective climate action — 让贸易争端妨碍共同的气候行动"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "国02", shortTitle: "国际合作解决紧急问题", category: "政府", subCategory: "国际", promptText: "Most of the urgent problems can only be solved with international cooperation. To what extent do you agree or disagree？", positivePoints: ["share resources during global emergencies — 在全球紧急事件中共享资源", "coordinate emergency responses during cross-border disease outbreaks — 协调跨境疫情紧急应对"], negativePoints: ["respond to transnational crises in isolation — 孤立应对跨国危机", "delay responses while countries negotiate responsibilities — 各国协商责任期间延误应对"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "国03", shortTitle: "富国对穷国的援助方式", category: "政府", subCategory: "国际", promptText: "Some people believe that rich countries should provide poorer countries with other types of help rather than financial aid. To what extent do you agree or disagree?", positivePoints: ["transfer technical expertise to poorer countries — 向较贫困国家转移技术专长", "provide technical expertise alongside financial assistance — 在财政援助外提供技术专长"], negativePoints: ["create long-term dependence on foreign aid — 造成对外援的长期依赖", "create long-term dependence on foreign donors — 造成对外国援助方的长期依赖"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "国04", shortTitle: "国际援助的形式选择", category: "政府", subCategory: "国际", promptText: "Developing countries require help offered by international organizations to ensure healthy and sustainable development. Some people think that financial aid is important. Others believe that practical aid and advice is more important. Discuss both these views and give your own opinion.", positivePoints: ["provide practical training alongside financial support — 在资金援助之外提供技能培训", "train local workers to maintain donated infrastructure — 培训本地工人维护援助建设的基础设施"], negativePoints: ["offer funding without local capacity-building — 只给资金却不建设当地能力", "deliver equipment without providing necessary maintenance skills — 提供设备却未传授必要维护技能"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "国05", shortTitle: "名人助力国际援助的影响", category: "政府", subCategory: "国际", promptText: "Some people believe famous people's support towards international aid organizations draws the attention to problems, while others think celebrities make the problems less important. Discuss both views and give your opinion.", positivePoints: ["use celebrity influence to draw attention to crises — 借名人影响力引起对危机的关注", "raise funds for relief agencies through celebrity campaigns — 通过名人活动为救援机构筹款"], negativePoints: ["overshadow local voices with celebrity publicity — 让名人宣传掩盖当地人的声音", "turn humanitarian crises into celebrity publicity opportunities — 让人道危机沦为名人的宣传机会"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "罪01", shortTitle: "犯罪惩处与教育的选择", category: "社会", subCategory: "犯罪", promptText: "In most countries, prison is an effective solution for the problem of crime. Some people think a more effective solution is to provide a better education. To what extent do you agree or disagree？", positivePoints: ["combine education with rehabilitation programmes — 将教育与改造计划结合", "help former offenders return to work after rehabilitation — 帮助改造后的违法者重返工作"], negativePoints: ["rely solely on imprisonment to reduce crime — 只依靠监禁减少犯罪", "leave inmates without employable skills after release — 使囚犯获释后缺乏就业技能"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "罪02", shortTitle: "反社会行为的成因与解决", category: "社会", subCategory: "犯罪", promptText: "Today there is a great increase in anti-social behavior and lack of respect to others. What are the causes of this? What measures can be taken to reduce this problem?", positivePoints: ["address the causes of antisocial behaviour — 解决反社会行为的成因", "address family instability linked to youth offending — 解决与青少年犯罪相关的家庭不稳定问题"], negativePoints: ["normalise disrespectful behaviour in communities — 使社区中不尊重他人的行为常态化", "treat disruptive behaviour as a purely criminal issue — 将扰乱秩序行为仅视作刑事问题"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "罪03", shortTitle: "违法者的惩处方式选择", category: "社会", subCategory: "犯罪", promptText: "Some people think that lawbreakers should be sent to prison. However, others think that better talents among those should be made to work. Discuss both views and give your own opinion.", positivePoints: ["require offenders to perform community service — 要求违法者从事社区服务", "assign non-violent offenders to supervised community work — 安排非暴力违法者参加监督下的社区劳动"], negativePoints: ["imprison non-violent offenders unnecessarily — 不必要地监禁非暴力违法者", "send minor offenders into environments with hardened criminals — 让轻微犯罪者进入重犯聚集环境"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "罪04", shortTitle: "犯罪惩处的时长选择", category: "社会", subCategory: "犯罪", promptText: "Some people believe that in order to reduce crimes, prisoners should be given longer prison sentences while some people think there are other alternative ways. Discuss both views and give your opinion.", positivePoints: ["reduce reoffending through rehabilitation — 通过改造减少再犯", "reduce repeat offending through post-release support — 通过释放后的支持降低再犯"], negativePoints: ["extend prison sentences without clear benefits — 在效果不明时延长刑期", "keep prisoners incarcerated for longer without rehabilitation — 延长囚禁时间却不提供改造"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "文01", shortTitle: "新语言提升国际沟通影响", category: "文化", subCategory: "文化", promptText: "Some people say it is necessary to create a new language that improves international communication. Do you think the benefits outweigh the drawbacks?", positivePoints: ["facilitate communication across language barriers — 促进跨语言沟通", "remove language barriers to cross-border communication — 减少跨境沟通的语言障碍"], negativePoints: ["erase linguistic diversity through a universal language — 以通用语言抹去语言多样性", "require communities to abandon their mother tongues — 要求社区放弃母语"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "文02", shortTitle: "美术馆展品的选择倾向", category: "文化", subCategory: "文化", promptText: "Art galleries and museums should display more traditional cultural works and fewer artworks from other countries. To what extent do you agree or disagree?", positivePoints: ["showcase both local and foreign artworks — 同时展出本地与外国艺术品", "exhibit local heritage alongside international works — 同时展出本土遗产与国际艺术作品"], negativePoints: ["exclude international art from museum collections — 将外国艺术排除在博物馆收藏之外", "limit public exposure to artistic traditions from abroad — 限制公众接触外国艺术传统"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "文03", shortTitle: "音乐作为人类通用语言", category: "文化", subCategory: "文化", promptText: "Music has always been and continues to be the universal language of mankind. To what extent do you agree or disagree?", positivePoints: ["bring people together through shared musical experiences — 通过共同音乐体验连接人们", "connect people from different generations through music — 通过音乐联系不同世代人群"], negativePoints: ["overlook cultural differences in musical meaning — 忽视音乐意义的文化差异", "assume musical tastes are identical across cultures — 误以为各文化的音乐品味完全相同"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "文04", shortTitle: "语言四项技能的重要性", category: "文化", subCategory: "文化", promptText: "When you learn a foreign language, all four skills (listening, reading, speaking, writing) are equally important. To what extent do you agree or disagree?", positivePoints: ["develop listening, speaking, reading and writing skills — 培养听说读写能力", "strengthen listening and speaking through daily interaction — 通过日常互动强化听说能力"], negativePoints: ["neglect productive language skills — 忽视语言输出技能", "neglect writing practice in favour of oral fluency alone — 只注重口语流利而忽视写作练习"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "文05", shortTitle: "旅游对文化传统的影响", category: "文化", subCategory: "文化", promptText: "Some people think that cultural traditions will be destroyed when they are used as money-making machines aimed at tourists, other people believe that it is the only way to save such traditions in the world today. Discuss both sides and give your own opinion.", positivePoints: ["finance the preservation of traditional festivals — 为传统节日保护提供资金", "finance the restoration of traditional crafts through tourism — 通过旅游收入资助传统工艺修复"], negativePoints: ["turn cultural ceremonies into staged performances — 把文化仪式变成表演秀", "commercialise sacred traditions for visitors' entertainment — 为取悦游客而商业化神圣传统"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "文06", shortTitle: "建筑设计功能与外观", category: "文化", subCategory: "文化", promptText: "Some people believe that when designing a building, the most important thing to be considered is the function rather than the outward appearance. To what extent do you agree or disagree?", positivePoints: ["prioritise functionality in building design — 在建筑设计中优先考虑实用性", "make public buildings accessible to people with disabilities — 使公共建筑对残障人士无障碍"], negativePoints: ["sacrifice usability for visual appeal — 为视觉效果牺牲实用性", "prioritise decorative features over safety and functionality — 将装饰性设计置于安全功能之前"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "文07", shortTitle: "旅行与文化学习的方式", category: "文化", subCategory: "文化", promptText: "It is not necessary for people to travel to other places to learn about the culture. We can learn as much as from books, films and the Internet. To what extent do you agree or disagree?", positivePoints: ["learn about cultures through first-hand travel — 通过亲身旅行了解文化", "observe local customs directly while travelling — 旅行时直接观察当地习俗"], negativePoints: ["gain a superficial view of local customs — 对当地习俗只有肤浅认识", "mistake online stereotypes for lived cultural experience — 将网络刻板印象当作真实文化体验"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "文08", shortTitle: "小众语言保护的资源投入", category: "文化", subCategory: "文化", promptText: "Some people believe governments should spend money in saving languages of few speakers from dying out completely. Others think this is a waste of financial resources. Discuss both views and give your opinion.", positivePoints: ["pass endangered languages to younger generations — 把濒危语言传给年轻一代", "record endangered languages before native speakers disappear — 在母语使用者消失前记录濒危语言"], negativePoints: ["allow minority languages to disappear — 任由少数语言消失", "allocate language-preservation funds without community support — 在缺乏社区支持时投入语言保护经费"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "文09", shortTitle: "跨国企业全球化的影响", category: "文化", subCategory: "文化", promptText: "The spread of multinational companies and the increase of globalization produces positive effects for everyone. To what extent do you agree or disagree?", positivePoints: ["create local jobs through multinational investment — 通过跨国投资创造当地岗位", "create new markets for local producers through international trade — 通过国际贸易为本地生产者创造新市场"], negativePoints: ["drive domestic firms out of competitive markets — 将本土公司挤出竞争市场", "replace locally owned firms with powerful multinationals — 让强大的跨国企业取代本地企业"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "旅01", shortTitle: "太空旅行的发展影响", category: "文化", subCategory: "旅游", promptText: "Space travel has been possible for some time and some people believe that space tourism could be developed in the future. Do you think it is a positive or negative development?", positivePoints: ["advance space research through commercial tourism — 通过商业旅游推动太空研究", "make space science more visible to paying passengers — 使付费乘客更直观了解太空科学"], negativePoints: ["produce emissions from tourist space flights — 太空观光飞行造成排放", "direct scarce resources towards luxury space flights — 将稀缺资源用于豪华太空飞行"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "旅02", shortTitle: "负责任旅游的可行性", category: "文化", subCategory: "旅游", promptText: "In recent years, “responsible tourists” have paid attention to preserving both culture and environment of the places they visit. However, some people say that it is impossible to be a “responsible tourist”. To what extent do you agree or disagree?", positivePoints: ["respect local customs and natural environments — 尊重当地风俗与自然环境", "follow wildlife-viewing rules in protected natural areas — 在自然保护区遵守野生动物观赏规定"], negativePoints: ["damage fragile sites through irresponsible travel — 因不负责任旅行破坏脆弱景点", "damage fragile habitats through irresponsible visits — 因不负责任的游览破坏脆弱栖息地"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "旅03", shortTitle: "本地景点的游客占比", category: "文化", subCategory: "旅游", promptText: "Many museums and historical sites are mainly visited by tourists and not local people. Why is this the case? What can be done to attract local people?", positivePoints: ["attract local residents with affordable museum access — 通过低价博物馆门票吸引当地居民", "offer discounted museum admission to local residents — 为本地居民提供博物馆门票优惠"], negativePoints: ["price residents out of cultural attractions — 以高票价使当地居民难以参观", "design exhibitions solely around international tourists — 仅围绕国际游客设计展览"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "旅04", shortTitle: "跨国旅游的有害影响", category: "文化", subCategory: "旅游", promptText: "Many countries believe that international tourism has harmful effects. Why do they think so? What can be done to change their views?", positivePoints: ["manage visitor numbers in popular destinations — 管理热门目的地游客数量", "spread tourism income to smaller local businesses — 使旅游收入流向较小的本地商家"], negativePoints: ["overload local infrastructure during peak seasons — 旺季让当地基础设施超负荷", "increase rent and living costs in tourist districts — 提高旅游地区租金与生活成本"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环01", shortTitle: "环境问题的成因与解决", category: "环境", subCategory: "环境", promptText: "There are many environmental problems, such as the greenhouse effect and climate change, and people have hardly found any solutions. Why is this the case? And what measures can be taken?", positivePoints: ["address the underlying drivers of climate change — 应对气候变化的深层驱动因素", "impose binding targets for cutting industrial emissions — 对工业减排设立有约束力的目标"], negativePoints: ["postpone action on greenhouse gas emissions — 推迟减少温室气体排放行动", "postpone emissions cuts until damage becomes irreversible — 推迟减排直至环境破坏无法逆转"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环02", shortTitle: "消费品生产与自然破坏", category: "环境", subCategory: "环境", promptText: "The increase in the production of consumer goods results in damage to the natural environment. What are the causes of this? What can be done to solve this problem?", positivePoints: ["switch to less resource-intensive production — 转向资源消耗较少的生产方式", "extend product lifespans through repair and reuse — 通过维修与重复使用延长产品寿命"], negativePoints: ["increase waste from mass-produced goods — 因大规模商品生产而增加废弃物", "deplete raw materials through excessive mass production — 因过度大规模生产耗竭原材料"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环03", shortTitle: "污染治理的责任主体", category: "环境", subCategory: "环境", promptText: "Some people think that companies and individuals should pay to clear up the pollution they produced and that the government should not pay for it. To what extent do you agree or disagree?", positivePoints: ["make polluters pay for environmental clean-up — 让污染者承担环境清理费用", "require manufacturers to finance waste disposal — 要求制造商承担废物处理费用"], negativePoints: ["shift clean-up costs onto taxpayers — 将环境清理费用转嫁给纳税人", "let producers pass pollution costs to the public — 允许生产商将污染成本转嫁公众"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环04", shortTitle: "淡水短缺的成因与解决", category: "环境", subCategory: "环境", promptText: "Fresh water is a limited resource in some parts of the world. Today, increasing demand made it a global problem. What are the causes of increasing demand, what measures can governments and individuals take to solve this problem?", positivePoints: ["introduce water-saving irrigation methods — 采用节水灌溉方式", "repair leaking pipes to conserve limited freshwater supplies — 修复漏水管道以保护有限淡水"], negativePoints: ["deplete freshwater supplies through overuse — 过度使用导致淡水资源耗尽", "overuse groundwater for intensive agriculture — 因集约农业过度开采地下水"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环05", shortTitle: "塑料污染的治理措施", category: "环境", subCategory: "环境", promptText: "More and more plastic is polluting cities, countryside and oceans. What are the problems caused by plastic waste? What measures should be taken to solve it?", positivePoints: ["replace single-use plastics with reusable materials — 用可重复使用的材料替代一次性塑料", "restrict disposable packaging in takeaway services — 限制外卖服务中的一次性包装"], negativePoints: ["allow plastic waste to enter waterways — 让塑料垃圾进入水道", "allow plastic fragments to enter food chains — 让塑料碎片进入食物链"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环06", shortTitle: "气候变化对商业的影响", category: "环境", subCategory: "环境", promptText: "Some people think climate change has a negative impact on business, while others think that it provides more business opportunities. Discuss both views and give your own opinion.", positivePoints: ["create opportunities in the green economy — 在绿色经济中创造机会", "create markets for climate-resilient building materials — 为气候适应型建材创造市场"], negativePoints: ["expose firms to climate-related disruption — 使企业面临气候相关的业务中断", "disrupt supply chains through extreme weather events — 极端天气扰乱供应链"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环07", shortTitle: "生活水平与环境破坏", category: "环境", subCategory: "环境", promptText: "Damage to the environment is an inevitable consequence of the improvement in the standard of living. To what extent do you agree or disagree？", positivePoints: ["decouple economic growth from resource consumption — 推动经济增长与资源消耗脱钩", "separate rising living standards from rising resource use — 使生活水平提高与资源消耗上升脱钩"], negativePoints: ["raise living standards through unsustainable consumption — 通过不可持续消费提升生活水平", "expand consumer demand beyond ecological limits — 消费需求增长超出生态承载极限"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环08", shortTitle: "应对气候变化的方式", category: "环境", subCategory: "环境", promptText: "Some people think that instead of preventing climate change, we need to find a way to live with it. To what extent do you agree or disagree?", positivePoints: ["adapt infrastructure to extreme weather — 调整基础设施应对极端天气", "build flood defences while reducing future emissions — 建设防洪设施的同时减少未来排放"], negativePoints: ["treat adaptation as a substitute for emission cuts — 用适应措施代替减排", "treat adaptation as a substitute for preventing warming — 将适应措施当作阻止变暖的替代品"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环09", shortTitle: "野生动物保护的资源投入", category: "环境", subCategory: "环境", promptText: "Some people think that too much attention and too many resources have been given to the protection of wild animals and birds. To what extent do you agree or disagree?", positivePoints: ["protect breeding grounds for endangered animals — 保护濒危动物的繁殖地", "restore breeding habitats for threatened bird species — 修复受威胁鸟类的繁殖栖息地"], negativePoints: ["prioritise wildlife spending without assessing human needs — 不评估人类需求就优先投向野生动物", "spend on charismatic species while neglecting entire ecosystems — 只重视明星物种而忽视完整生态系统"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环10", shortTitle: "环境问题的解决主体探讨", category: "环境", subCategory: "环境", promptText: "Some people think that environmental problems are too big for individuals to solve. Others, however, believe that these problems cannot be solved if individuals do not take actions. Discuss both views and give your own opinion.", positivePoints: ["make low-carbon choices in everyday life — 在日常生活中选择低碳方式", "help households cut electricity use through home insulation — 通过住宅保温帮助家庭减少用电"], negativePoints: ["assume individual action makes no difference — 认为个人行动毫无影响", "leave all responsibility for industrial pollution to households — 将工业污染的责任全部推给家庭"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环11", shortTitle: "偏远地区能源开采影响", category: "环境", subCategory: "环境", promptText: "With the increasing demand for energy sources of oil and gas, people should look for sources of oil and gas in remote and untouched natural places. Do the advantages outweigh disadvantages of damaging such areas？", positivePoints: ["avoid drilling in ecologically sensitive regions — 避免在生态敏感地区钻探", "protect untouched habitats from oil exploration — 保护未开发栖息地免受石油勘探"], negativePoints: ["disturb remote habitats through oil exploration — 石油勘探扰乱偏远栖息地", "risk oil spills in ecologically sensitive regions — 在生态敏感地区冒石油泄漏风险"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环12", shortTitle: "偏远自然环境旅行影响", category: "环境", subCategory: "环境", promptText: "Scientists and tourists can travel to remote natural environments such as the South Pole. Do you think the advantages outweigh the disadvantages?", positivePoints: ["conduct research with minimal ecological disturbance — 以最小生态干扰开展研究", "limit visitor numbers in delicate polar ecosystems — 限制脆弱极地生态系统的游客人数"], negativePoints: ["leave waste in remote natural environments — 在偏远自然环境留下垃圾", "disturb wildlife through tourist expeditions — 旅游探险活动干扰野生动物"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环13", shortTitle: "自然资源消耗问题解决", category: "环境", subCategory: "环境", promptText: "Natural resources such as oil, forests and fresh water are being consumed at an alarming rate. What problems does this cause? How can we solve these problems?", positivePoints: ["use finite resources more efficiently — 更高效地使用有限资源", "promote sustainable forestry and water management — 推动可持续林业和水资源管理"], negativePoints: ["consume natural resources at an unsustainable rate — 以不可持续速度消耗资源", "extract natural resources faster than they can recover — 自然资源开采速度超过恢复速度"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "环14", shortTitle: "保护动物与关注人类问题", category: "环境", subCategory: "环境", promptText: "Many animal species in the world are becoming extinct nowadays. Some people say that countries and individuals should protect these animals from dying out, while others say we should concentrate more on problems of human beings. Discuss both views and give your opinion.", positivePoints: ["prevent the extinction of threatened species — 防止受威胁物种灭绝", "protect threatened animals that play important ecological roles — 保护在生态中发挥重要作用的受威胁动物"], negativePoints: ["dismiss conservation as irrelevant to human welfare — 认为生态保护与人类福祉无关", "ignore urgent human needs when setting conservation budgets — 制定保护预算时忽略紧迫的人类需求"], examDate: "20250718", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "健01", shortTitle: "竞技运动的社会价值定位", category: "社会", subCategory: "健康", promptText: "Some people think sports games are important for society, while others believe they should be taken as leisure activities. Discuss both views and give your opinion.", positivePoints: ["encourage participation in community sports — 鼓励参与社区体育运动", "encourage active lifestyles through community sports leagues — 通过社区体育联赛鼓励积极生活方式"], negativePoints: ["treat competitive sport purely as entertainment — 把竞技体育仅看作娱乐", "prioritise professional sport over opportunities for ordinary residents — 优先职业体育而非普通居民运动机会"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "健02", shortTitle: "整容的原因及发展影响", category: "社会", subCategory: "健康", promptText: "An increasing number of people are choosing cosmetic surgeries. Why do people have operations to change the way they look? Do you think this is a positive or negative development?", positivePoints: ["make informed decisions about cosmetic surgery — 理性决定是否整容", "provide counselling about the risks of elective surgery — 提供选择性手术风险咨询"], negativePoints: ["reinforce unrealistic standards of physical appearance — 强化不切实际的外貌标准", "promote unrealistic beauty standards through cosmetic procedures — 通过整容项目推广不切实际的审美标准"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "健03", shortTitle: "不健康饮食的改善措施", category: "社会", subCategory: "健康", promptText: "Many people like to eat unhealthy food even though they know it’s bad for themselves. Why? What effective ways can improve people's healthy eating habits?", positivePoints: ["limit consumption of highly processed food — 限制高度加工食品的摄入", "make healthy food affordable in low-income neighbourhoods — 使低收入社区能够负担健康食品"], negativePoints: ["develop a preference for high-sugar snacks — 养成偏爱高糖零食的习惯", "make processed snacks cheaper than nutritious meals — 使加工零食比营养餐更便宜"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "健04", shortTitle: "年轻人户外休闲少的原因", category: "社会", subCategory: "健康", promptText: "Many young people do not spend their holidays and weekends doing outdoor activities like hiking and climbing in natural environments. Why? How can they be encouraged to go out?", positivePoints: ["encourage teenagers to take part in outdoor activities — 鼓励青少年参与户外活动", "create safe walking and cycling routes for young people — 为年轻人建立安全的步行和骑行路线"], negativePoints: ["spend most leisure time indoors — 大部分休闲时间都待在室内", "leave children with few accessible outdoor spaces — 让孩子缺少方便前往的户外活动空间"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "健05", shortTitle: "素食与健康饮食的关系", category: "社会", subCategory: "健康", promptText: "Some people think everyone should be a vegetarian, because we do not need to eat meat to have a healthy diet. To what extent do you agree or disagree?", positivePoints: ["meet nutritional needs through a balanced diet — 通过均衡饮食满足营养需求", "plan balanced meals that include plant-based proteins — 安排包含植物蛋白的均衡膳食"], negativePoints: ["overlook nutrient deficiencies in restrictive diets — 忽视限制性饮食中的营养缺乏", "ignore possible nutrient deficiencies in restrictive diets — 忽视限制性饮食可能造成的营养缺乏"], examDate: "20250510", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "健06", shortTitle: "有害食品的销售管控", category: "社会", subCategory: "健康", promptText: "Some people think that shops should not be allowed to sell any food or drink that has scientifically been proved to have bad effects on people's health. To what extent do you agree or disagree？", positivePoints: ["regulate products with proven health risks — 监管有确切健康风险的产品", "require clear nutritional labels on packaged products — 要求包装食品标注清晰营养标签"], negativePoints: ["allow harmful products to be marketed freely — 允许有害产品自由营销", "remove consumer choice through overly broad food bans — 通过过于宽泛的食品禁令限制消费者选择"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "健07", shortTitle: "食品长途运输的影响", category: "社会", subCategory: "健康", promptText: "Today, some food travels thousands of miles from farms to consumers. Some people think that it would be better to our environment and economy if people only eat locally produced food. To what extent do the disadvantages outweigh the advantages?", positivePoints: ["source more food from local producers — 从当地生产者采购更多食物", "support farmers selling seasonal produce locally — 支持农民在本地销售应季农产品"], negativePoints: ["increase food miles and transport emissions — 增加食品运输距离与运输排放", "increase transport emissions from air-freighted fresh food — 增加空运生鲜食品的运输排放"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "健08", shortTitle: "过量饮食广告的管控", category: "社会", subCategory: "健康", promptText: "Research shows that overeating is as harmful as smoking. Therefore, advertising for certain food products should be banned, in the same way as cigarette advertising is banned in many countries. To what extent do you agree or disagree?", positivePoints: ["restrict advertisements for unhealthy foods — 限制不健康食品广告", "limit advertisements for energy-dense snacks aimed at children — 限制面向儿童的高能量零食广告"], negativePoints: ["expose children to persuasive junk-food marketing — 让儿童接触诱导性垃圾食品营销", "encourage overeating through constant food promotions — 通过持续食品促销刺激过量进食"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "健09", shortTitle: "化肥机械对健康的影响", category: "社会", subCategory: "健康", promptText: "The increase in food production owes much to fertilizers and better machinery. Some people think that it has a negative impact on human health and community. To what extent do you agree or disagree?", positivePoints: ["improve agricultural yields with modern machinery — 用现代机械提高农业产量", "use agricultural machinery to improve crop yields — 通过农业机械提高作物产量"], negativePoints: ["misuse chemical fertilisers in food production — 在食品生产中滥用化肥", "contaminate soil and waterways through excessive fertiliser use — 因过度施肥污染土壤与水道"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工01", shortTitle: "背井离乡找工作的影响", category: "工作", subCategory: "工作", promptText: "In many countries, people need to leave their families and friends to find jobs in other places. Do you think the advantages outweigh the disadvantages?", positivePoints: ["pursue employment beyond one's hometown — 到家乡之外寻找工作", "obtain specialist positions unavailable in one's hometown — 获得家乡没有的专业岗位"], negativePoints: ["live far away from family support networks — 远离家庭支持网络生活", "weaken emotional ties with family after moving away — 离乡后削弱与家庭的情感联系"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工02", shortTitle: "职业选择的理想与现实", category: "工作", subCategory: "工作", promptText: "Some people think young people should be free to choose their job, while others believe that they should be realistic and think about their future. Discuss both views and give your opinion.", positivePoints: ["choose careers that match individual interests — 选择符合个人兴趣的职业", "choose a career that matches long-term interests — 选择符合长期兴趣的职业"], negativePoints: ["ignore long-term job prospects — 忽视长期就业前景", "pursue unrealistic jobs without considering labour demand — 不顾劳动力需求而追求不切实际的工作"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工03", shortTitle: "技术对不同年龄就业的影响", category: "工作", subCategory: "工作", promptText: "Some people think the increasing use of technology in the workplace is good for young people's prospects of gaining a job and harder for old people. To what extent do you agree or disagree?", positivePoints: ["retrain older workers for digital jobs — 帮助年长员工再培训转向数字岗位", "help older employees retrain for digital tools — 帮助老员工再培训以掌握数字工具"], negativePoints: ["exclude older applicants from technological roles — 将年长申请者排除在科技岗位外", "exclude experienced workers who lack digital qualifications — 排除缺乏数字资格的资深员工"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工04", shortTitle: "组织高管薪资的公平性", category: "工作", subCategory: "工作", promptText: "Directors of organizations receive higher salaries than the ordinary worker. Some people think it is necessary while others think it is unfair. Discuss both views and give your own opinions.", positivePoints: ["link executive pay to measurable performance — 将高管薪酬与可衡量业绩挂钩", "link executive bonuses to measurable company performance — 将高管奖金与可量化公司表现挂钩"], negativePoints: ["allow excessive gaps between executive and staff pay — 使高管与员工薪酬差距过大", "damage staff morale through disproportionate pay gaps — 过大的薪酬差距打击员工士气"], examDate: "20240817", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工05", shortTitle: "工作满意度的影响因素", category: "工作", subCategory: "工作", promptText: "As most people spend a major part of their adult life at work, job satisfaction is an important element of individual well-being. What factors contribute to job satisfaction? How realistic is the expectation of job satisfaction for all workers?", positivePoints: ["give employees meaningful career progression — 给员工提供有意义的职业发展机会", "allow staff a meaningful say in workplace decisions — 让员工真正参与职场决策"], negativePoints: ["ignore non-financial factors in job satisfaction — 忽略工作满意度中的非经济因素", "reduce job satisfaction through excessive micromanagement — 因过度微观管理降低工作满意度"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工06", shortTitle: "工作与生活平衡的实现", category: "工作", subCategory: "工作", promptText: "People aim to keep a balance between their work and other parts of their lives, but few people achieve it. What are the problems in trying to achieve this goal and how can these problems be overcome?", positivePoints: ["set reasonable working hours — 设定合理工作时间", "protect evenings and weekends from work messages — 避免工作消息侵占夜晚和周末"], negativePoints: ["allow work demands to invade personal time — 让工作需求侵占私人时间", "normalise unpaid work outside contracted hours — 使合同工时以外的无偿劳动常态化"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工07", shortTitle: "年度假期对工作的作用", category: "工作", subCategory: "工作", promptText: "Employers should give their staff at least a 4-week holiday a year to make employees better at their jobs. To what extent do you agree or disagree?", positivePoints: ["provide adequate paid annual leave — 提供足够的带薪年假", "prevent burnout through predictable holiday schedules — 通过可预期的休假安排预防倦怠"], negativePoints: ["deny workers sufficient time to recover — 不给员工足够恢复休息的时间", "create staffing shortages when too many employees take leave — 多人同时休假时造成人手短缺"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工08", shortTitle: "职业转换的成因与影响", category: "工作", subCategory: "工作", promptText: "An increasing number of people are changing their careers. What are the reasons? Do you think it is positive or negative?", positivePoints: ["support career changes through retraining — 通过再培训支持职业转换", "use retraining programmes to move into growing industries — 借助再培训项目进入增长行业"], negativePoints: ["face skill gaps when changing careers — 转行时面临技能缺口", "lose accumulated professional networks during a career switch — 转行时失去积累的职业人脉"], examDate: "20250104", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工09", shortTitle: "短期工作模式的看法", category: "工作", subCategory: "工作", promptText: "Some people prefer to have temporary jobs, which means they only work a few months in a year and use the rest of the time to do what they want. What is your opinion?", positivePoints: ["offer flexible short-term employment options — 提供灵活的短期就业选择", "allow people to combine part-time work with caregiving — 让人们兼顾兼职工作与照护家人"], negativePoints: ["leave temporary workers without job security — 让临时雇员缺乏就业保障", "leave short-term workers without stable income — 使短期雇员缺乏稳定收入"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "工10", shortTitle: "长工作时长的经济影响", category: "工作", subCategory: "工作", promptText: "Countries with a long average working time are more economically successful than those countries which do not have a long working time. To what extent do you agree or disagree?", positivePoints: ["improve output through smarter work practices — 通过更高效的工作方式增加产出", "improve output without extending the working week — 在不延长工作周的情况下提升产出"], negativePoints: ["equate longer working hours with higher productivity — 把更长工时等同于更高生产率", "raise fatigue-related accident risks through long shifts — 长轮班增加因疲劳造成的事故风险"], examDate: nil, notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补01", shortTitle: "儿童课余活动的安排自由", category: "教育", subCategory: "教育", promptText: "Some people think that children's free time should be organised by adults, while others believe that children should be free to choose what they do in their spare time. Discuss both views and give your own opinion.", positivePoints: ["develop social skills through supervised group activities — 通过有监督的团体活动培养社交技能", "leave time for self-directed play after school — 放学后留出自主玩耍时间"], negativePoints: ["fill children's free time with adult-led schedules — 用成人安排的日程占满儿童空闲时间", "leave younger children without guidance during risky activities — 让年幼儿童在有风险的活动中缺乏指导"], examDate: "20240106", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补02", shortTitle: "未来规划与活在当下", category: "社会", subCategory: "社会", promptText: "Some people think it is a waste of time for an individual to plan for the future and it is more important to focus on the present. To what extent do you agree or disagree?", positivePoints: ["set realistic financial goals for the next five years — 为未来五年设定现实的财务目标", "remain flexible when circumstances change unexpectedly — 当环境意外变化时保持灵活"], negativePoints: ["spend excessive time worrying about uncertain future events — 花过多时间担心不确定的未来事件", "make short-term decisions without considering long-term consequences — 决策时只顾短期而不考虑长期后果"], examDate: "20240113", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补03", shortTitle: "工作中的社交与职场外的朋友", category: "工作", subCategory: "工作", promptText: "Some people prefer to make friends with colleagues at work, while others prefer to keep their social life separate from their workplace. Discuss both views and give your own opinion.", positivePoints: ["build professional friendships through shared projects — 通过共同项目建立职场友谊", "maintain friendships outside one's workplace — 维持工作场所以外的友谊"], negativePoints: ["allow office conflicts to affect one's social circle — 让办公室冲突影响私人社交圈", "depend entirely on colleagues for emotional support — 完全依赖同事获得情感支持"], examDate: "20240127", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补04", shortTitle: "儿童观看电视的内容与时长", category: "教育", subCategory: "教育", promptText: "What children watch on television and how much time they spend watching it have a significant impact on their behaviour and development. To what extent do you agree or disagree?", positivePoints: ["choose age-appropriate programmes for young viewers — 为年幼观众选择适龄节目", "set clear daily limits on children's screen time — 为儿童设定明确每日屏幕时长"], negativePoints: ["expose children to aggressive behaviour on television — 让儿童接触电视中的攻击行为", "replace active play with several hours of passive viewing — 用数小时被动观看代替积极玩耍"], examDate: "20240203", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补05", shortTitle: "艺术创作是否需要天赋", category: "文化", subCategory: "文化", promptText: "Some people think that only people who have natural talent can create art such as painting or poetry, while others believe that anyone can learn to create art. Discuss both views and give your own opinion.", positivePoints: ["make painting and poetry accessible to beginners — 让初学者也能接触绘画与诗歌创作", "improve artistic technique through regular practice — 通过定期练习提高艺术技巧"], negativePoints: ["discourage ordinary people from attempting creative work — 阻止普通人尝试创作", "equate artistic talent with guaranteed professional success — 将艺术天赋等同于必然的职业成功"], examDate: "20240224", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补06", shortTitle: "城市无车日的利弊", category: "环境", subCategory: "环境", promptText: "Some cities have introduced vehicle-free days when private cars, trucks and motorcycles are banned from the city centre. Do the advantages of this policy outweigh the disadvantages?", positivePoints: ["reduce exhaust emissions in busy city centres — 减少繁忙市中心的尾气排放", "encourage commuters to try buses and metro services — 鼓励通勤者尝试巴士及地铁"], negativePoints: ["disrupt deliveries to shops during vehicle-free periods — 无车时段干扰商店送货", "make travel inconvenient for residents with limited mobility — 使行动不便居民出行更加困难"], examDate: "20240302", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补07", shortTitle: "大学科学专业报读人数不足", category: "教育", subCategory: "教育", promptText: "In many countries, not enough students are choosing to study science subjects at university. What are the causes of this problem, and what effects does it have on society?", positivePoints: ["offer scholarships for students entering science degrees — 为攻读科学学位的学生提供奖学金", "build a larger workforce of laboratory researchers — 培养更多实验室研究人员"], negativePoints: ["make science subjects seem inaccessible through abstract teaching — 因抽象教学使科学学科显得难以接近", "leave engineering firms short of qualified graduates — 使工程企业缺乏合格毕业生"], examDate: "20240316", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补08", shortTitle: "毕业生个人理财能力不足", category: "教育", subCategory: "教育", promptText: "Many young people leave school without knowing how to manage their personal finances. Why is this the case? What can be done to improve students' financial literacy?", positivePoints: ["teach teenagers to prepare household budgets — 教青少年编制家庭预算", "explain interest rates and credit-card debt at school — 在学校解释利率与信用卡债务"], negativePoints: ["leave graduates unaware of the cost of borrowing — 使毕业生不了解借贷成本", "encourage impulsive spending without basic money-management skills — 缺乏基本理财技能而助长冲动消费"], examDate: "20240323", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补09", shortTitle: "犯罪成因：贫困还是个人性格", category: "社会", subCategory: "犯罪", promptText: "Some people believe that crime is a result of social problems and poverty, while others think that crime is a result of a person's bad nature. Discuss both views and give your own opinion.", positivePoints: ["address poverty and poor schooling linked to offending — 治理与违法有关的贫困及教育不足", "provide early intervention for at-risk teenagers — 为高风险青少年提供早期干预"], negativePoints: ["ignore social pressures that can contribute to criminal behaviour — 忽视可能促成犯罪的社会压力", "excuse deliberate harm solely on the grounds of poverty — 仅以贫困为由为故意伤害开脱"], examDate: "20240413", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补10", shortTitle: "科技使犯罪减少还是增加", category: "科技", subCategory: "科技", promptText: "Some people think that modern technology helps to prevent and reduce crime, while others believe that it leads to more crime. Discuss both views and give your own opinion.", positivePoints: ["use CCTV evidence to identify repeat offenders — 利用闭路电视证据识别惯犯", "detect financial fraud through transaction monitoring — 通过交易监测发现金融诈骗"], negativePoints: ["enable cybercriminals to steal personal information remotely — 让网络犯罪分子远程窃取个人信息", "facilitate anonymous scams through online platforms — 通过线上平台助长匿名诈骗"], examDate: "20240420", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补11", shortTitle: "互联网信息能否取代博物馆", category: "文化", subCategory: "文化", promptText: "Public museums and art galleries are no longer necessary because people can see historical objects and works of art on the Internet. To what extent do you agree or disagree?", positivePoints: ["make museum collections accessible through digital archives — 借助数字档案让公众接触博物馆馆藏", "allow visitors to study authentic artefacts in person — 让参观者亲身研究真实文物"], negativePoints: ["assume online photographs can replace original objects — 误认为网上图片可以代替文物原件", "restrict historical learning to those who can visit museums — 将历史学习机会局限于能亲临博物馆的人"], examDate: "20240427", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补12", shortTitle: "国际社会减少化石燃料消耗", category: "环境", subCategory: "环境", promptText: "The international community must act immediately to reduce all countries' consumption of fossil fuels such as gas and oil. To what extent do you agree or disagree?", positivePoints: ["agree on national targets for reducing oil consumption — 达成各国减少石油消耗的目标", "finance a transition from coal-fired power to renewables — 资助从燃煤发电转向可再生能源"], negativePoints: ["allow countries to delay action through weak agreements — 因薄弱协议而容许国家拖延行动", "make low-income households bear the full cost of energy changes — 让低收入家庭独自承担能源转型成本"], examDate: "20240511", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补13", shortTitle: "政府应否只救助本国公民", category: "政府", subCategory: "政府", promptText: "Some people think that governments should only provide financial assistance and support to citizens of their own country rather than helping people in other countries. To what extent do you agree or disagree?", positivePoints: ["fulfil basic welfare duties towards domestic residents — 履行对本国居民的基本福利义务", "support international disaster relief when resources permit — 在资源允许时支持国际救灾"], negativePoints: ["refuse emergency aid to neighbouring countries during crises — 危机期间拒绝向邻国提供紧急援助", "distribute limited public funds without clear priorities — 在优先级不明时分配有限公共资金"], examDate: "20240525", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补14", shortTitle: "私人营利医疗的利弊", category: "社会", subCategory: "健康", promptText: "In some countries, private health care is becoming more common where companies provide medical treatment for profit. Do the advantages of private health care outweigh the disadvantages?", positivePoints: ["shorten waiting lists through additional private clinics — 通过增加私人诊所缩短候诊名单", "maintain universal access to essential medical treatment — 保障基本医疗的全民可及性"], negativePoints: ["put profit targets ahead of patients' medical needs — 将盈利目标置于病人医疗需求之上", "exclude low-income patients through unaffordable treatment fees — 因高昂治疗费将低收入病人排除在外"], examDate: "20240601", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补15", shortTitle: "跨国商业文化交流与民族认同", category: "文化", subCategory: "文化", promptText: "Increasing business and cultural contact between countries is a positive development, while others think it leads to the loss of national identities. Discuss both views and give your own opinion.", positivePoints: ["increase cultural exchange through international partnerships — 通过国际合作增加文化交流", "introduce overseas consumers to traditional local products — 向海外消费者介绍传统本地产品"], negativePoints: ["replace regional customs with globally marketed lifestyles — 用全球营销的生活方式取代地方习俗", "weaken national identity through cultural homogenisation — 因文化同质化削弱民族认同"], examDate: "20240608", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补16", shortTitle: "动物自然灭绝是否应干预", category: "环境", subCategory: "环境", promptText: "It is a natural process for animal species to become extinct, so there is no reason for people to try to prevent this from happening. To what extent do you agree or disagree?", positivePoints: ["protect endangered species threatened by human activity — 保护受到人类活动威胁的濒危物种", "restore habitats damaged by logging and urban expansion — 修复伐木及城市扩张破坏的栖息地"], negativePoints: ["treat human-caused extinction as an unavoidable natural process — 将人类造成的灭绝当作不可避免的自然过程", "redirect conservation funding from urgent public services without scrutiny — 未经评估就从紧急公共服务转移经费至物种保护"], examDate: "20240622", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补17", shortTitle: "居家办公利于员工还是雇主", category: "工作", subCategory: "工作", promptText: "Many employees can now do their work from home using modern technology. However, this change may only benefit workers, not the employers. To what extent do you agree or disagree?", positivePoints: ["reduce office rental costs through remote working — 通过远程办公减少办公室租金", "improve employee retention with flexible work arrangements — 通过弹性工作安排提高员工留任率"], negativePoints: ["make new employees harder to train remotely — 使新员工远程培训更加困难", "blur expectations about availability outside office hours — 模糊下班后是否须随时在线的界限"], examDate: "20240727", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补18", shortTitle: "努力工作的动机是否只有金钱", category: "工作", subCategory: "工作", promptText: "The only reason people work hard is to earn more money and there is no other reason for doing so. To what extent do you agree or disagree?", positivePoints: ["derive satisfaction from mastering difficult tasks — 从掌握困难任务中获得满足感", "seek recognition and opportunities for promotion — 寻求认可及晋升机会"], negativePoints: ["treat salary as the only measure of career success — 将工资作为衡量事业成功的唯一标准", "ignore intrinsic motivation when designing staff incentives — 设计员工激励措施时忽略内在动力"], examDate: "20240831", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补19", shortTitle: "通过影像还是文献了解外国生活", category: "文化", subCategory: "文化", promptText: "Some people think that watching films and videos is the best way to learn about how people live in other countries, while others believe written books and articles are better. Discuss both views and give your own opinion.", positivePoints: ["observe daily routines through documentary footage — 通过纪录片画面观察日常生活", "study historical context through written accounts — 通过书面记录研究历史背景"], negativePoints: ["mistake carefully edited videos for complete cultural reality — 将精心剪辑的影片误认为完整文化现实", "struggle to understand unfamiliar customs without visual examples — 没有影像示例时难以理解陌生习俗"], examDate: "20240907", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补20", shortTitle: "老年人继续工作是否有益", category: "工作", subCategory: "工作", promptText: "In many countries, older people choose to continue working beyond retirement age. Do the advantages of this trend outweigh the disadvantages?", positivePoints: ["allow healthy older adults to work by choice — 允许身体健康的老年人自愿继续工作", "retain experienced mentors in the workforce — 留住职场中的经验丰富导师"], negativePoints: ["pressure older workers to delay retirement for financial reasons — 因经济原因迫使老员工推迟退休", "reduce openings for younger applicants in some sectors — 在部分行业减少年轻求职者岗位"], examDate: "20240914", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补21", shortTitle: "文物是否应归还原属国", category: "文化", subCategory: "文化", promptText: "Many museums and galleries display historical artefacts that were taken from other countries. Should these objects be returned to their countries of origin? To what extent do you agree or disagree?", positivePoints: ["return culturally significant artefacts to their countries of origin — 将具有重要文化意义的文物归还原属国", "negotiate shared exhibitions between international museums — 协商国际博物馆之间的联合展览"], negativePoints: ["remove objects from museums without adequate conservation facilities — 在缺乏适当保护设施时从博物馆移走文物", "ignore the historical circumstances under which artefacts were acquired — 忽略文物取得时的历史背景"], examDate: "20240928", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补22", shortTitle: "建设自行车设施与交通拥堵", category: "环境", subCategory: "环境", promptText: "Some people think that building more facilities for cyclists is the best way to reduce traffic congestion in cities, while others believe that this measure has little effect. Discuss both views and give your own opinion.", positivePoints: ["build protected cycle lanes for short urban journeys — 为城市短途出行建设隔离自行车道", "connect cycling routes with railway stations — 将自行车路线与火车站衔接"], negativePoints: ["remove traffic lanes without improving other transport options — 在未改善其他交通方式时减少机动车道", "expect cycling to replace long-distance trips for all commuters — 期望所有通勤者都用骑行代替长途出行"], examDate: "20241012", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补23", shortTitle: "大学学习为何比中学更困难", category: "教育", subCategory: "教育", promptText: "Many students find it harder to study at university or college than when they were at school. Why is this? What can be done to solve the problem?", positivePoints: ["teach students independent research and time-management skills — 教学生独立研究及时间管理能力", "provide academic-writing support for first-year students — 为大一学生提供学术写作支持"], negativePoints: ["leave new undergraduates unprepared for self-directed study — 使大学新生难以适应自主学习", "increase assessment pressure through overlapping deadlines — 多个作业截止日重叠而增加考核压力"], examDate: "20241019", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补24", shortTitle: "花钱追求年轻外貌的原因", category: "社会", subCategory: "社会", promptText: "More and more people are spending money on cosmetics, treatments and products to look younger. Why do people do this? Is it a positive or negative development?", positivePoints: ["allow people to choose non-invasive cosmetic treatments — 允许人们选择非侵入式美容项目", "encourage realistic attitudes towards natural ageing — 鼓励对自然衰老持现实态度"], negativePoints: ["create anxiety about normal signs of ageing — 让人对正常衰老迹象产生焦虑", "spend large sums on unproven anti-ageing products — 在未经证实的抗衰老产品上花巨款"], examDate: "20241026", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补25", shortTitle: "家庭价值观与学校知识谁影响成功", category: "教育", subCategory: "教育", promptText: "Some people think that the values children learn from their families are the most important factor in their future success, while others believe that knowledge and skills learned at school are more important. Discuss both views and give your own opinion.", positivePoints: ["teach perseverance and honesty through family role models — 通过家庭榜样教授毅力与诚实", "build specialist knowledge through formal schooling — 通过正规教育建立专业知识"], negativePoints: ["pass harmful prejudices down through family traditions — 通过家庭传统传递有害偏见", "assume good family values can replace professional qualifications — 误认为良好家庭价值观可以取代职业资格"], examDate: "20241102", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补26", shortTitle: "上大学还是直接就业", category: "教育", subCategory: "教育", promptText: "Some people believe that studying at university or college is the best route to a successful career, while others think it is better to get a job straight after school. Discuss both views and give your own opinion.", positivePoints: ["obtain specialised qualifications for regulated professions — 取得受监管职业所需的专业资格", "gain early work experience through entry-level employment — 通过初级工作早期积累经验"], negativePoints: ["enter the workforce without skills needed for career progression — 缺少晋升所需技能就进入职场", "incur substantial tuition costs without a clear career plan — 没有明确职业规划就承担高额学费"], examDate: "20241123", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补27", shortTitle: "媒体是否应公开名人私生活", category: "媒体", subCategory: "媒体", promptText: "Some people think that the media should not report details of the private lives of famous people, while others believe that famous people's private lives are of public interest. Discuss both views and give your own opinion.", positivePoints: ["protect public figures from intrusive coverage of private relationships — 保护公众人物免于私人关系被侵扰报道", "report genuinely relevant misconduct by influential figures — 报道有影响力人物确有公共相关性的不当行为"], negativePoints: ["publish private medical or family details without consent — 未经同意公开私人医疗或家庭信息", "confuse legitimate public interest with audience curiosity — 将正当公众利益与观众好奇心混淆"], examDate: "20241130", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补28", shortTitle: "应限制非必要航班还是私家车", category: "环境", subCategory: "环境", promptText: "Some people think that non-essential flights should be restricted to reduce air pollution, while others argue that restricting private car use is more effective. Discuss both views and give your own opinion.", positivePoints: ["reduce leisure-flight demand through better rail alternatives — 通过改善铁路替代方案减少休闲航班需求", "discourage frequent short-haul flights where rail services exist — 在有铁路替代的地区减少频繁短途航班"], negativePoints: ["restrict essential journeys for people living far from major cities — 限制远离大城市居民的必要出行", "overlook the cumulative emissions of everyday car use — 忽视日常汽车使用的累积排放"], examDate: "20241207", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补29", shortTitle: "消费者要求即时服务的原因影响", category: "社会", subCategory: "社会", promptText: "Nowadays, consumers expect to get goods and services immediately without waiting. Why is this happening? Is this a positive or negative development?", positivePoints: ["provide faster access to urgent household services — 更快获得紧急家庭服务", "use digital booking to shorten unnecessary waiting times — 通过电子预约减少不必要的等候"], negativePoints: ["encourage impatience with services requiring careful professional work — 使人对需要专业细致工作的服务失去耐心", "put delivery workers under unrealistic time pressure — 对配送工人施加不现实的时间压力"], examDate: "20241221", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补30", shortTitle: "使用动物造福人类的伦理争论", category: "环境", subCategory: "环境", promptText: "Some people think it is acceptable to use animals for human benefit such as medical research and food production, while others argue that exploiting animals is wrong. Discuss both views and give your own opinion.", positivePoints: ["require strict welfare standards in animal-based research — 在动物实验中执行严格福利标准", "develop non-animal testing methods for medical products — 为医疗产品开发非动物测试方法"], negativePoints: ["cause unnecessary suffering during product testing — 在产品测试中造成不必要的痛苦", "ban essential research before reliable alternatives exist — 可靠替代方案尚未成熟时禁止必要研究"], examDate: "20241228", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补31", shortTitle: "快时尚对环境的危害", category: "环境", subCategory: "环境", promptText: "The fashion industry produces clothing at a rapid pace and encourages people to buy new clothes frequently, which has negative effects on the environment. To what extent do you agree or disagree?", positivePoints: ["extend the life of clothing through repair and second-hand sales — 通过修补与二手销售延长衣物寿命", "promote durable garments instead of disposable trends — 推广耐用服装而非一次性潮流"], negativePoints: ["generate textile waste through rapid fashion turnover — 因服装款式快速更迭产生纺织垃圾", "consume large amounts of water in clothing production — 在服装生产中耗费大量水资源"], examDate: "20250111", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补32", shortTitle: "读商科还是历史更有益社会", category: "教育", subCategory: "教育", promptText: "Some people think that studying business and economics is more beneficial to society than studying history and literature. To what extent do you agree or disagree?", positivePoints: ["teach market analysis and business management skills — 教授市场分析与商业管理技能", "preserve historical knowledge through university study — 通过大学教育保存历史知识"], negativePoints: ["undervalue historical understanding in favour of immediate profits — 为眼前利润而低估历史理解的重要性", "produce too many similar business graduates for available positions — 培养商科毕业生数量超过岗位需求"], examDate: "20250118", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补33", shortTitle: "城市人口快速增长的利弊", category: "社会", subCategory: "社会", promptText: "Rapid population growth in cities brings many benefits to residents, while others think it creates serious problems. Discuss both views and give your own opinion.", positivePoints: ["support specialised services through a larger urban population — 通过更大城市人口支持专业服务", "create new markets for local urban businesses — 为城市本地企业创造新市场"], negativePoints: ["overload public transport and municipal services — 使公共交通与市政服务超负荷", "push rents beyond the reach of low-income residents — 使房租超过低收入居民承受范围"], examDate: "20250208", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补34", shortTitle: "使用本地食品与建材是否更环保", category: "环境", subCategory: "环境", promptText: "Some people think that using locally produced food and building materials is always better for the environment than importing them from other regions. To what extent do you agree or disagree?", positivePoints: ["reduce transport distances for locally sourced building materials — 缩短本地建材的运输距离", "support seasonal food production near consumers — 支持消费者附近的应季食品生产"], negativePoints: ["assume locally produced goods always have lower emissions — 误认为本地产品的排放一定更低", "overlook resource-intensive local production methods — 忽视本地生产可能使用大量资源"], examDate: "20250215", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补35", shortTitle: "节日送钱还是送礼物", category: "文化", subCategory: "文化", promptText: "In many cultures, people give money instead of gifts on special occasions such as weddings and birthdays. Is this a positive or negative development?", positivePoints: ["allow recipients to choose how to spend cash gifts — 让收礼者自行决定现金用途", "select thoughtful presents based on personal interests — 根据个人兴趣精心挑选礼物"], negativePoints: ["make celebrations feel impersonal through cash-only gifts — 只送现金让庆祝活动缺少个人情感", "waste money on unwanted presents that are never used — 浪费钱买永远不会使用的礼物"], examDate: "20250308", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补36", shortTitle: "追求高薪工作的利弊", category: "工作", subCategory: "工作", promptText: "When choosing a job, some people prioritise a high salary over having suficientes free time and job satisfaction. Do the advantages of this choice outweigh the disadvantages?", positivePoints: ["achieve financial security through well-paid employment — 通过高薪工作实现财务安全", "save for housing and family expenses more quickly — 更快储蓄购房及家庭支出"], negativePoints: ["sacrifice personal time for excessively demanding jobs — 为高强度工作牺牲个人时间", "choose higher pay at the expense of job satisfaction — 为了更高工资牺牲工作满意度"], examDate: "20250315", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补37", shortTitle: "学生不喜欢数学的原因和解决", category: "教育", subCategory: "教育", promptText: "Many school students dislike learning mathematics and struggle with the subject. Why is this the case, and what can schools do to make mathematics more engaging?", positivePoints: ["teach fractions through real shopping and cooking examples — 用购物和烹饪实例讲解分数", "offer extra help before students fall behind in algebra — 在学生代数学习落后前提供额外帮助"], negativePoints: ["present mathematics as a series of meaningless formulas — 将数学呈现为一连串无意义的公式", "allow repeated test failures to damage confidence in maths — 反复考试失败削弱数学信心"], examDate: "20250322", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补38", shortTitle: "保护城乡具有历史意义的老建筑", category: "文化", subCategory: "文化", promptText: "It is important for towns and cities to protect historic buildings, while others think old buildings should be replaced with modern ones. Discuss both views and give your own opinion.", positivePoints: ["restore historic buildings for community use — 修复历史建筑供社区使用", "retain distinctive streetscapes in villages and city centres — 保留村镇与市中心的特色街景"], negativePoints: ["demolish culturally important buildings for short-term development — 为短期开发拆除文化重要建筑", "leave decaying heritage buildings unsafe without maintenance — 缺乏维护让老建筑失修而存在安全隐患"], examDate: "20250329", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补39", shortTitle: "数学与其他学校学科的重要性", category: "教育", subCategory: "教育", promptText: "Some people think mathematics is the most important subject at school, while others believe other subjects such as music and art are equally important. Discuss both views and give your own opinion.", positivePoints: ["use mathematics to teach logical reasoning and numeracy — 利用数学教授逻辑推理和计算能力", "preserve time for languages and creative subjects — 保留语言与创意学科的教学时间"], negativePoints: ["overload the timetable with maths at the expense of arts — 因数学课过多挤压艺术课时", "leave pupils without essential quantitative skills — 让学生缺少必要的数量分析技能"], examDate: "20250405", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补40", shortTitle: "高级电脑技能与职场成功", category: "科技", subCategory: "科技", promptText: "Some people believe that advanced computer skills are essential for career success today, while others think basic digital literacy is sufficient for most jobs. Discuss both views and give your own opinion.", positivePoints: ["use spreadsheets and digital databases at work — 在工作中使用电子表格与数字数据库", "train staff in job-specific software rather than generic tools — 培训员工掌握岗位所需软件而非泛泛工具"], negativePoints: ["treat coding expertise as essential for every occupation — 将编程能力视为所有职业必备", "exclude capable workers who lack advanced computer training — 排除缺乏高级计算机培训的胜任员工"], examDate: "20250412", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补41", shortTitle: "儿童自由度增加的利弊", category: "教育", subCategory: "教育", promptText: "Parents today often give their children more freedom than in the past. Do you think this is a positive or negative development?", positivePoints: ["let children make age-appropriate decisions independently — 让孩子独立作出符合年龄的决定", "help teenagers practise responsible risk assessment — 帮助青少年练习负责任地评估风险"], negativePoints: ["remove parental boundaries before children can judge danger — 在孩子能判断风险前取消家长界限", "overprotect children until they lack confidence to decide — 过度保护令孩子缺乏决策信心"], examDate: "20250419", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补42", shortTitle: "教师教授价值观还是只教文化课", category: "教育", subCategory: "教育", promptText: "Some people think teachers should only teach academic subjects, while others believe teachers should also teach students moral values and how to behave. Discuss both views and give your own opinion.", positivePoints: ["address bullying and dishonesty in classroom discussions — 在课堂讨论中处理霸凌与不诚实", "teach moral reasoning alongside academic subjects — 在教授文化课的同时培养道德推理"], negativePoints: ["make teachers solely responsible for children's moral upbringing — 让教师独自承担孩子道德教育责任", "neglect subject knowledge while teaching behaviour rules — 教学行为规范时忽略学科知识"], examDate: "20250426", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补43", shortTitle: "新闻媒体是否应多报道好消息", category: "媒体", subCategory: "媒体", promptText: "News media today report too much bad news and should focus more on reporting positive stories and good news. To what extent do you agree or disagree?", positivePoints: ["report community achievements alongside serious problems — 在报道严肃问题的同时报道社区成就", "highlight successful responses to social challenges — 强调应对社会挑战的成功措施"], negativePoints: ["hide significant public-interest scandals behind positive stories — 用正面新闻掩盖重大公共利益丑闻", "overemphasise distressing events until audiences disengage — 过度强调负面事件令观众不再关注新闻"], examDate: "20250517", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补44", shortTitle: "暴力影视游戏应否禁播", category: "媒体", subCategory: "媒体", promptText: "Violent films and video games have a negative effect on people's behaviour and should be banned. To what extent do you agree or disagree?", positivePoints: ["introduce age ratings for violent films and games — 为暴力影视与游戏设置年龄分级", "help parents choose suitable entertainment for children — 帮助父母为儿童选择合适娱乐内容"], negativePoints: ["normalise aggression through repeated violent scenes — 因反复暴力镜头使攻击性行为显得正常", "impose blanket bans on fiction intended for adults — 对面向成年人的虚构作品实行一刀切禁令"], examDate: "20250524", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补45", shortTitle: "美术馆参观人数下降原因与对策", category: "文化", subCategory: "文化", promptText: "The number of people visiting art galleries and museums is declining. What are the reasons for this, and how can more people be encouraged to visit them?", positivePoints: ["organise interactive exhibitions for younger audiences — 为年轻观众举办互动展览", "offer free-entry days to local art galleries — 为本地美术馆设立免费开放日"], negativePoints: ["keep exhibitions unchanged despite shifting visitor interests — 在游客兴趣变化时仍不更新展览", "make admission fees unaffordable for local families — 使本地家庭难以负担入场费"], examDate: "20250614", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补46", shortTitle: "新房应遵从传统建筑风格吗", category: "文化", subCategory: "文化", promptText: "When new houses are built in existing towns and villages, governments should require them to be built in the traditional local style. To what extent do you agree or disagree?", positivePoints: ["preserve the visual character of historic neighbourhoods — 保留历史街区的视觉特色", "allow contemporary homes to meet modern accessibility standards — 允许现代住房满足无障碍标准"], negativePoints: ["force all new housing to imitate outdated designs — 强迫所有新房模仿过时设计", "replace coherent local streetscapes with incompatible buildings — 用不协调建筑破坏统一的地方街景"], examDate: "20250621", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补47", shortTitle: "发展中国家扩大旅游业的原因和影响", category: "文化", subCategory: "旅游", promptText: "Many developing countries are expanding their tourist industries. Why is this the case? Is it a positive or negative development?", positivePoints: ["create jobs for local guides and hospitality workers — 为本地导游及酒店服务人员创造就业", "use tourism revenue to improve regional infrastructure — 利用旅游收入改善地区基础设施"], negativePoints: ["make local economies dependent on seasonal visitor numbers — 让本地经济依赖季节性游客量", "damage coastal ecosystems through uncontrolled resort construction — 因失控的度假村建设破坏海岸生态"], examDate: "20250628", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补48", shortTitle: "科技总体利弊", category: "科技", subCategory: "科技", promptText: "Modern technology has brought many changes to our lives. Do the advantages of modern technology outweigh its disadvantages?", positivePoints: ["use assistive devices to support people with disabilities — 通过辅助设备帮助残障人士", "apply digital tools to improve emergency response systems — 运用数字工具改善紧急应对系统"], negativePoints: ["expose personal data through poorly secured digital services — 通过安全不足的数字服务泄露个人数据", "leave older users behind when essential services become digital-only — 基本服务纯数字化时使老年用户掉队"], examDate: "20250705", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补49", shortTitle: "生活方式变化对家庭关系的影响", category: "社会", subCategory: "社会", promptText: "Changing lifestyles mean that family members spend less time together and have weaker relationships than in the past. To what extent do you agree or disagree?", positivePoints: ["share domestic responsibilities in dual-income households — 在双收入家庭分担家务责任", "keep relatives connected through regular online contact — 通过定期线上联系维系亲属关系"], negativePoints: ["reduce opportunities for shared meals through irregular schedules — 不规律作息减少家庭共餐机会", "make family members less available for elderly relatives — 使家人难以抽空照料年长亲属"], examDate: "20250726", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补50", shortTitle: "老员工与年轻员工谁更有价值", category: "工作", subCategory: "工作", promptText: "Some companies prefer to hire younger workers, while others value older and more experienced employees. Discuss both views and give your own opinion.", positivePoints: ["retain older staff's industry knowledge through mentoring — 通过导师制保留老员工的行业知识", "invite younger employees to introduce emerging digital practices — 让年轻员工引入新兴数字工作方式"], negativePoints: ["judge workers' competence solely by age — 仅凭年龄评价员工胜任力", "ignore the training needs of mixed-age teams — 忽视不同年龄团队的培训需求"], examDate: "20250809", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补51", shortTitle: "久坐原因与减少久坐的办法", category: "社会", subCategory: "健康", promptText: "Many people today spend most of their working day sitting at a desk, which is harmful to their health. What problems does this cause, and what measures can be taken to reduce prolonged sitting?", positivePoints: ["install adjustable desks in offices — 在办公室安装可调高度的办公桌", "encourage short walking breaks during long shifts — 鼓励长时间轮班中的短暂步行休息"], negativePoints: ["increase back and neck pain through prolonged sitting — 因久坐加重背颈疼痛", "design jobs that require uninterrupted screen work — 设计必须长时间连续盯屏幕的工作"], examDate: "20250816", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补52", shortTitle: "男女服装风格趋同的社会影响", category: "社会", subCategory: "社会", promptText: "In many places, men's and women's clothing styles are becoming increasingly similar. Is this a positive or negative development?", positivePoints: ["give people greater freedom to choose gender-neutral clothing — 赋予人们更多选择中性服装的自由", "reduce rigid dress expectations for men and women — 减少对男女服饰的僵化期待"], negativePoints: ["stigmatise people who prefer traditional gendered clothing — 污名化偏好传统性别服装的人", "mistake similar clothing styles for the loss of all gender identities — 误将服饰趋同当成全部性别认同消失"], examDate: "20250823", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补53", shortTitle: "学习语言是不是了解文化的最佳方式", category: "文化", subCategory: "文化", promptText: "Some people think that learning a foreign language is the best way to understand another culture, while others believe there are better ways to learn about other cultures. Discuss both views and give your own opinion.", positivePoints: ["understand cultural humour through learning a local language — 通过学习当地语言理解文化幽默", "combine language lessons with direct cultural experiences — 将语言课程与直接文化体验结合"], negativePoints: ["assume vocabulary knowledge alone explains social customs — 以为仅掌握词汇就能解释社会习俗", "miss cultural nuances when relying solely on translations — 完全依赖翻译时错过文化细微差别"], examDate: "20250830", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补54", shortTitle: "长途商务面谈的利弊", category: "工作", subCategory: "工作", promptText: "Even though online communication is widely available, many business people still travel long distances for face-to-face meetings. Do the advantages of in-person business travel outweigh the disadvantages?", positivePoints: ["build trust during face-to-face negotiations — 通过面对面谈判建立信任", "resolve complex disagreements in person — 当面解决复杂分歧"], negativePoints: ["increase flight emissions through repeated business trips — 频繁商务飞行增加碳排放", "spend company funds on meetings that could be held online — 为本可在线举行的会议花费公司资金"], examDate: "20250913", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补55", shortTitle: "政府资助表演艺术培训由谁承担", category: "政府", subCategory: "政府", promptText: "Some people think that training in performing arts such as music and theatre should be funded by the government, while others believe it should be paid for by individuals or commercial sponsors. Discuss both views and give your own opinion.", positivePoints: ["offer subsidised performing-arts lessons to disadvantaged pupils — 为弱势学生提供补贴的表演艺术课程", "seek sponsorship from local firms for community theatre training — 向本地企业寻求社区戏剧培训赞助"], negativePoints: ["limit music training to families able to pay private fees — 将音乐培训机会局限于负担得起私人学费的家庭", "fund specialist arts classes without evaluating public demand — 不评估公众需求就资助专业艺术课程"], examDate: "20251012", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补56", shortTitle: "法律难以执行的原因及解决", category: "社会", subCategory: "犯罪", promptText: "In some countries, certain laws are difficult to enforce in practice. Why is this the case, and what can governments do to ensure laws are effectively enforced?", positivePoints: ["provide police with training to enforce online-fraud laws — 培训警方执行反网络诈骗法律", "simplify unclear regulations that are difficult to enforce — 简化难以执行的模糊法规"], negativePoints: ["introduce laws without adequate investigative resources — 制定法律却不配备足够调查资源", "weaken respect for legislation through inconsistent enforcement — 因执法不一致削弱对法律的尊重"], examDate: "20251018", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补57", shortTitle: "奖励优等生还是进步学生", category: "教育", subCategory: "教育", promptText: "Some schools only give prizes and awards to students with the highest academic marks, while others believe schools should reward students who show the greatest improvement. Discuss both views and give your own opinion.", positivePoints: ["recognise students who make substantial academic progress — 认可取得显著学业进步的学生", "reward consistently outstanding academic achievement — 奖励始终优秀的学业表现"], negativePoints: ["discourage weaker pupils by honouring only top scorers — 只表彰最高分使成绩较弱学生气馁", "make awards meaningless by ignoring genuine effort — 忽视真实努力令奖励失去意义"], examDate: "20251025", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补58", shortTitle: "科学种植还是自然种植", category: "环境", subCategory: "环境", promptText: "Some people support using modern scientific methods in agriculture to increase food production, while others believe natural and organic farming methods are better. Discuss both views and give your own opinion.", positivePoints: ["increase food yields through precision irrigation and pest monitoring — 借助精准灌溉与害虫监测提高粮食产量", "protect soil health through crop rotation and organic methods — 通过轮作及有机方法保护土壤健康"], negativePoints: ["overapply synthetic pesticides to maximise short-term output — 为最大化短期产量过量使用合成农药", "reject useful agricultural technology without assessing its safety — 未评估安全性就拒绝有用农业技术"], examDate: "20251101", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补59", shortTitle: "职场竞争力与团队合作能力", category: "工作", subCategory: "工作", promptText: "Some people think that encouraging competition among employees is the best way to improve company performance, while others believe that fostering teamwork and cooperation is more effective. Discuss both views and give your own opinion.", positivePoints: ["encourage employees to share expertise across departments — 鼓励员工跨部门分享专长", "motivate staff to improve through healthy competition — 通过良性竞争激励员工进步"], negativePoints: ["withhold useful information to gain an advantage over colleagues — 为获得同事间的优势而隐瞒有用信息", "reward individual targets while ignoring collective outcomes — 只奖励个人指标而忽略团队成果"], examDate: "20251115", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补60", shortTitle: "小组学习还是独立学习", category: "教育", subCategory: "教育", promptText: "Some students prefer to study in groups, while others find it more effective to study alone. Discuss the advantages and disadvantages of both approaches and give your own opinion.", positivePoints: ["clarify difficult concepts through peer discussion — 通过同伴讨论澄清难懂概念", "develop concentration through independent study sessions — 通过独立学习培养专注力"], negativePoints: ["allow stronger group members to do all the work — 让能力较强的组员包办全部任务", "miss out on constructive feedback when studying alone — 独自学习时错过建设性反馈"], examDate: "2025111122*", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补61", shortTitle: "企业不断推出新型号并劝消费者更换", category: "环境", subCategory: "环境", promptText: "Many companies constantly release new models of products and encourage consumers to replace their existing items. Why do companies do this, and is it a positive or negative development?", positivePoints: ["improve product safety through genuinely useful upgrades — 通过真正有用的升级提高产品安全性", "offer spare parts to extend older devices' lifespan — 提供备件延长旧设备寿命"], negativePoints: ["create electronic waste through frequent replacement cycles — 频繁更换产品产生电子垃圾", "promote planned obsolescence to stimulate sales — 通过计划性淘汰来刺激销量"], examDate: "20251206", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补62", shortTitle: "前往未开发自然地区旅行的利弊", category: "文化", subCategory: "旅游", promptText: "More and more tourists are travelling to remote and undeveloped natural areas. Do the advantages of this trend outweigh the disadvantages?", positivePoints: ["support small conservation projects through permit fees — 通过许可证费用支持小型保护项目", "learn about fragile ecosystems with qualified local guides — 在合格本地向导陪同下了解脆弱生态系统"], negativePoints: ["disturb wildlife in previously untouched habitats — 干扰此前未受打扰的栖息地野生动物", "make emergency rescue difficult in remote wilderness areas — 在偏远荒野地区使紧急救援困难"], examDate: "20251213", notes: nil, isUserCreated: false),
        LumaTask2TopicItem(id: "补63", shortTitle: "运动成功靠教练还是天赋", category: "社会", subCategory: "健康", promptText: "Some people think that success in sport depends mainly on having an excellent coach, while others believe natural talent is more important. Discuss both views and give your own opinion.", positivePoints: ["improve athletic technique through expert coaching — 通过专家教练指导提高运动技术", "build on natural strengths through structured practice — 通过系统练习发挥天生优势"], negativePoints: ["assume natural talent removes the need for disciplined training — 误认为天赋意味着不需要纪律训练", "limit talented athletes' progress through poor coaching — 因不良教练指导限制有天赋运动员的发展"], examDate: "20251220", notes: nil, isUserCreated: false),
    ]
}
#endif

private struct DictationHeaderEntrance: ViewModifier {
    let enabled: Bool
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .animation(enabled ? .easeOut(duration: 0.14) : nil) { header in
                header.opacity(enabled && !appeared ? 0.82 : 1)
            }
            .task { appeared = true }
    }
}

/// 听写页右上角三合一胶囊内按钮样式（对齐主页右上角 InteractiveToolbarButtonStyle 交互与排版）
struct DictationToolbarClusterButtonStyle: ButtonStyle {
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        let scale: CGFloat = reduceMotion ? 1.0 : (configuration.isPressed ? 0.92 : (hovered ? 1.08 : 1.0))
        configuration.label
            .background(Color.white.opacity(hovered ? 0.12 : 0), in: Capsule(style: .continuous))
            .scaleEffect(scale)
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.8), value: hovered)
            .animation(reduceMotion ? nil : .spring(response: 0.12, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

/// 学习中心内原 .plain 按钮：外观不变，增加按下缩放/变暗与松手轻回弹。
struct StudyFluidPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .spring(response: configuration.isPressed ? 0.12 : 0.2, dampingFraction: configuration.isPressed ? 0.82 : 0.8), value: configuration.isPressed)
    }
}

/// 听写答错时输入框左右抖动。
struct StudyShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakesPerUnit * 2), y: 0))
    }
}


// MARK: - Multiple vocabulary books: wrong-word review
extension LumaStudyCenterHostView {
    private var mixedWrongReviewSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择错词单词本").font(.title2.bold())
            Text("勾选一个或多个单词本，把其中的错词合并为一轮复习。")
                .foregroundStyle(.secondary)
            HStack {
                Button("全选") { vm.mixedWrongDecks = Set(visibleListeningDeckIDs) }
                Button("清空选择") { vm.mixedWrongDecks.removeAll() }
                Spacer()
                Text("共 \(mixedWrongCandidates.count) 词")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(visibleListeningDeckIDs, id: \.self) { deck in
                        Toggle(isOn: Binding(
                            get: { vm.mixedWrongDecks.contains(deck) },
                            set: { enabled in
                                if enabled { vm.mixedWrongDecks.insert(deck) }
                                else { vm.mixedWrongDecks.remove(deck) }
                            }
                        )) {
                            HStack {
                                Text(deckTitle(for: deck))
                                Spacer()
                                Text("\(wrongWordsForDeck(deck).count) 个错词").foregroundStyle(.secondary)
                            }
                        }.toggleStyle(.checkbox)
                    }
                }
            }.frame(minHeight: 180, maxHeight: 320)
            Toggle("随机打乱顺序", isOn: $vm.mixedWrongShuffle)
            Text("开始会保存当前进度并新建一轮；每个词继续记在原单词本里。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("取消") { vm.mixedWrongSheetShown = false }
                Spacer()
                Button("开始合并重练") {
                    let decks = vm.mixedWrongDecks.intersection(Set(visibleListeningDeckIDs)).sorted()
                    vm.mixedWrongSheetShown = false
                    startMixedWrongReview(decks: decks, resume: false)
                    mode = "学习_听力_错词复习"
                }
                .disabled(mixedWrongCandidates.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 520)
        .background(appearance.background)
        .foregroundStyle(appearance.ink)
        .tint(appearance.accent)
    }

    private var mixedWrongCandidates: [VocabularyWord] {
        visibleListeningDeckIDs.filter { vm.mixedWrongDecks.contains($0) }
            .flatMap { wrongWordsForDeck($0) }
    }

    private func showMixedWrongSelector() {
        if vm.selectedDeck.hasPrefix("__mixed_wrong__") {
            vm.mixedWrongDecks = Set(String(vm.selectedDeck.dropFirst("__mixed_wrong__".count)).components(separatedBy: "\u{1F}"))
        } else if vm.mixedWrongDecks.isEmpty {
            vm.mixedWrongDecks = [vm.selectedDeck]
        }
        vm.mixedWrongDecks.formIntersection(Set(visibleListeningDeckIDs))
        vm.mixedWrongSheetShown = true
    }

    private func startMixedWrongReview(decks: [String], resume: Bool) {
        let decks = decks.filter { visibleListeningDeckIDs.contains($0) }.sorted()
        guard !decks.isEmpty else { return }
        let deckKey = "__mixed_wrong__" + decks.joined(separator: "\u{1F}")
        let key = HostStateModel.sessionKey(mode: .wrongWordReview, date: Self.todayDateString(), deck: deckKey)
        vm.save()
        ttsEngine.stop(); audio.stop(); kokoro.stop()
        vm.selectedDeck = deckKey
        vm.activeDictationDeckKey = deckKey
        if resume, let saved = vm.storeSnapshot.dictationSessions?[key], !saved.isSessionFinished {
            vm.dictationMachine = saved
            let workspace = vm.storeSnapshot.workspace
            let matches = workspace?.deckInputWordIDs?[key] == saved.currentWord?.id
            vm.dictationInput = matches ? (workspace?.deckInputs?[key] ?? "") : ""
            vm.showMeaning = matches ? (workspace?.deckShowMeaning?[key] ?? false) : false
            vm.revealedWordID = matches ? workspace?.deckRevealedWordIDs?[key] : nil
        } else {
            var seen = Set<String>()
            var words = decks.flatMap { wrongWordsForDeck($0) }.filter { seen.insert($0.id).inserted }
            if vm.mixedWrongShuffle { words.shuffle() }
            vm.dictationMachine = DictationSessionStateMachine(
                mode: .wrongWordReview, dateString: Self.todayDateString(), initialWords: words,
                existingStubbornWordsForToday: vm.storeSnapshot.stubbornWords,
                previousLogs: vm.storeSnapshot.dictationLogs
            )
            vm.dictationInput = ""; vm.showMeaning = false; vm.revealedWordID = nil
        }
        showFirstLetterHint = false
        vm.save()
        speakCurrentWord()
    }
}

extension LumaStudyCenterHostView {
    private var dictationTotalWords: Int {
        Set(vm.dictationMachine.pendingQueue.map(\.id))
            .union(vm.dictationMachine.completedWordIDs)
            .union(vm.dictationMachine.attemptLogs.map(\.wordID)).count
    }
    private var previousDictationWord: VocabularyWord? {
        let completed = vm.dictationMachine.completedWordIDs
        guard let log = vm.dictationMachine.attemptLogs.reversed().first(where: {
            $0.isCorrect && completed.contains($0.wordID) && $0.wordID != vm.dictationMachine.currentWord?.id
        }) else { return nil }
        return allWords.first { $0.id == log.wordID }
    }
}

// final_audio_prefetch_calls_v4

// rolling_audio_calls_v5


// MARK: - 文件夹路径移动解析（可测试的最小模型）

/// 一条文件夹移动规则：把 `source` 路径及其子路径整体迁到 `destination` 下。
struct LumaFinderMoveRule: Equatable {
    let source: [String]
    let destination: [String]
}

enum LumaFinderPath {
    /// 解析 “A=B|C=D” 形式的持久化移动表，并按最长路径优先排序。
    static func rules(from redirects: [String: String]) -> [LumaFinderMoveRule] {
        redirects.compactMap { key, value -> LumaFinderMoveRule? in
            let source = key.split(separator: "/").map(String.init)
            let destination = value.split(separator: "/").map(String.init)
            guard !source.isEmpty, !destination.isEmpty else { return nil }
            return LumaFinderMoveRule(source: source, destination: destination)
        }
        .sorted { lhs, rhs in
            if lhs.source.count != rhs.source.count { return lhs.source.count > rhs.source.count }
            return lhs.source.joined(separator: "/") < rhs.source.joined(separator: "/")
        }
    }

    /// 把原始路径折叠到当前真实位置。反复迭代以支持“移动后的文件夹再次被移动”，
    /// 并在路径回到已访问位置时停止（例如移入后又移回原位）。
    static func resolve(_ path: [String], rules: [LumaFinderMoveRule]) -> [String] {
        guard !path.isEmpty, !rules.isEmpty else { return path }
        var current = path
        var visited: Set<String> = [path.joined(separator: "/")]
        var changed = true
        var passes = 0
        while changed && passes < 24 {
            changed = false
            passes += 1
            for rule in rules {
                if current == rule.source {
                    current = rule.destination
                    changed = true
                    break
                }
                if current.count > rule.source.count,
                   Array(current.prefix(rule.source.count)) == rule.source {
                    current = rule.destination + Array(current.dropFirst(rule.source.count))
                    changed = true
                    break
                }
            }
            if changed {
                let key = current.joined(separator: "/")
                if visited.contains(key) { return current }
                visited.insert(key)
            }
        }
        return current
    }
}

/// 1.9.3: rounded, hover-highlighted disclosure target. The old 16–18pt plain
// chevron was easy to miss and felt unresponsive; this is the same treatment the
// reader directory uses (30pt hit area + rounded hover fill + rotation).
private struct LumaDisclosureChevron: View {
    let expanded: Bool
    var size: CGFloat = 30
    var tint: Color
    let action: () -> Void
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
    }
    var body: some View {
        Button(action: action) {
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                .font(.system(size: size > 28 ? 11 : 10.5, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(shape.fill(hovered ? tint.opacity(0.12) : Color.clear))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(Text(expanded ? "折叠" : "展开"))
        .accessibilityValue(Text(expanded ? "已展开" : "已折叠"))
    }
}

// MARK: - 1.11.0 选择题背词（不听写，ABCD 四选一中文释义）
//
// 设计目标：
// - 不改动听写会话、错词日志与持久化结构；进度只保存在 UserDefaults（每个词库一个游标）。
// - 跟随 StudyAppearance（Monet / Space / Manga 等主题的 paper/ink/accent/surface），Manga 不使用玻璃。
// - 自动播放发音；键盘全程可操作；静态背景 + 四周暗角 + 柔化文字对比度，减少长时间使用的视疲劳；
//   单词居于视线中心，选项在其下方安静排列，周边信息全部弱化。

enum LumaChoiceQuizProgress {
    private static let key = "luma.choiceQuiz.cursorByDeck"
    static func cursor(for deck: String) -> Int {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Int])?[deck] ?? 0
    }
    static func setCursor(_ value: Int, for deck: String) {
        var all = (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
        all[deck] = max(0, value)
        UserDefaults.standard.set(all, forKey: key)
    }
    private static func draftKey(_ deck: String) -> String { "luma.choiceQuiz.draft." + deck }

    static func draft(for deck: String) -> ReadingQuizDraft? {
        guard let data = UserDefaults.standard.data(forKey: draftKey(deck)) else { return nil }
        return try? JSONDecoder().decode(ReadingQuizDraft.self, from: data)
    }

    static func saveDraft(_ draft: ReadingQuizDraft?, for deck: String) {
        if let draft, let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: draftKey(deck))
        } else if draft == nil {
            UserDefaults.standard.removeObject(forKey: draftKey(deck))
        }
    }

}

struct LumaChoiceQuizDeck: Identifiable, Equatable {
    let id: String
    let title: String
}

private enum ReadingQuizGamepadAction: Sendable {
    case answer(Int)
    case replay
    case advance
    case help
}

@MainActor
private struct ReadingQuizGamepadMonitor: NSViewRepresentable {
    let onPress: @MainActor (ReadingQuizGamepadAction) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.start(in: view, onPress: onPress)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onPress = onPress
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var view: NSView?
        private var buttonsByController: [ObjectIdentifier: [GCControllerButtonInput]] = [:]
        var onPress: (@MainActor (ReadingQuizGamepadAction) -> Void)?

        func start(in view: NSView, onPress: @escaping @MainActor (ReadingQuizGamepadAction) -> Void) {
            self.view = view
            self.onPress = onPress
            let notifications = NotificationCenter.default
            for name in [NSNotification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
                notifications.addObserver(self, selector: #selector(controllersChanged(_:)), name: name, object: nil)
            }
            refreshControllers()
        }

        func stop() {
            NotificationCenter.default.removeObserver(self)
            onPress = nil
            view = nil
            for buttons in buttonsByController.values {
                for button in buttons { button.pressedChangedHandler = nil }
            }
            buttonsByController.removeAll()
        }

        @objc private func controllersChanged(_ notification: Notification) {
            refreshControllers()
        }

        private func refreshControllers() {
            let controllers = GCController.controllers()
            let connectedIDs = Set(controllers.map { ObjectIdentifier($0) })
            for id in Array(buttonsByController.keys) where !connectedIDs.contains(id) {
                for button in buttonsByController.removeValue(forKey: id) ?? [] {
                    button.pressedChangedHandler = nil
                }
            }
            for controller in controllers {
                let id = ObjectIdentifier(controller)
                guard buttonsByController[id] == nil, let gamepad = controller.extendedGamepad else { continue }
                let bindings: [(GCControllerButtonInput, ReadingQuizGamepadAction)] = [
                    (gamepad.buttonA, .answer(0)), (gamepad.buttonB, .answer(1)),
                    (gamepad.buttonX, .answer(2)), (gamepad.buttonY, .answer(3)),
                    (gamepad.leftShoulder, .replay), (gamepad.rightShoulder, .advance),
                    (gamepad.buttonMenu, .help)
                ]
                buttonsByController[id] = bindings.map { $0.0 }
                for (button, action) in bindings {
                    button.pressedChangedHandler = { [weak self] _, _, pressed in
                        guard pressed else { return }
                        Task { @MainActor [weak self] in self?.deliver(action, from: id) }
                    }
                }
            }
        }

        private func deliver(_ action: ReadingQuizGamepadAction, from id: ObjectIdentifier) {
            guard buttonsByController[id] != nil, NSApp.isActive, NSApp.modalWindow == nil,
                  let window = view?.window, window.isKeyWindow, window.attachedSheet == nil else { return }
            onPress?(action)
        }
    }
}

private struct ReadingQuizTimer: View {
    let active: Bool
    @StateObject private var timer = StudyDailyTimer(scope: .reading)

    var body: some View {
        Button {
            if timer.running { timer.pause() } else { timer.start() }
        } label: {
            Label(timer.formatted, systemImage: timer.running ? "pause.fill" : "play.fill")
                .lumaFont(size: 12, weight: .medium, monospacedDigits: true)
        }
        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: timer.running, horizontalPadding: 10, height: 32))
        .fixedSize()
        .disabled(!active)
        .accessibilityLabel(timer.running ? "暂停阅读计时" : "继续阅读计时")
        .accessibilityValue(timer.formatted)
        .help(timer.running ? "暂停阅读计时" : "继续阅读计时")
        .onChange(of: active, initial: true) { _, active in
            if active { timer.start() } else { timer.pause() }
        }
        .onDisappear { timer.pause() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            timer.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumaReader.AppDidResignActive"))) { _ in
            timer.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            timer.pause()
        }
    }
}

struct LumaChoiceQuizView: View {
    static let shortcutRows: [String] = [
        "1–4 / A–D|选择对应选项", "Space / R / ⌘R|重播发音", "Return / →|下一个",
        "H|提示：排除两个错误选项", "E|看答案（记为不会）", "P|自动播放开关",
        "W|结果页：复习错题", "?|显示 / 隐藏快捷键", "Esc|返回词库"
    ]

    private static let gamepadRows: [(String, String)] = [
        ("面键下／右／左／上", "选择选项 A / B / C / D"),
        ("左肩键 LB / L1", "重播发音"),
        ("右肩键 RB / R1", "下一题／下一组"),
        ("菜单键", "显示／关闭操作说明")
    ]

    @Environment(\.studyAppearance) private var envAppearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaDynamicMotion) private var dynamicMotion

    @Binding var deckID: String
    let decks: [LumaChoiceQuizDeck]
    let wordsForDeck: @MainActor (String) -> [VocabularyWord]
    let globalPool: [VocabularyWord]
    let speak: @MainActor (String) -> Void
    let speechIssue: (word: String, message: String)?
    let preparingSpeech: Bool
    let stopSpeech: @MainActor () -> Void
    let onExit: @MainActor () -> Void
    let onMiss: @MainActor (VocabularyWord) -> Void
    let onReviewCorrect: @MainActor (VocabularyWord) -> Void

    @AppStorage("luma.choiceQuiz.roundSize") private var roundSize: Int = 20
    @AppStorage("luma.choiceQuiz.autoplay") private var autoplay: Bool = true
    @AppStorage("luma.choiceQuiz.autoAdvance") private var autoAdvance: Bool = true
    @AppStorage("luma.choiceQuiz.calm") private var calmMode: Bool = true
    @AppStorage("luma.choiceQuiz.showPhonetic") private var showPhonetic: Bool = true

    @State private var questions: [LumaChoiceQuizQuestion] = []
    @State private var index = 0
    @State private var picked: Int? = nil
    @State private var eliminated: Set<Int> = []
    @State private var revealedByHelp = false
    @State private var correctIDs: [String] = []
    @State private var wrongWords: [VocabularyWord] = []
    @State private var finished = false
    @State private var isReviewRound = false
    @State private var showHelp = false
    @State private var advanceTask: Task<Void, Never>? = nil
    @State private var roundStartCursor = 0
    @State private var roundEndCursor = 0
    @State private var reviewCursor = 0
    @State private var showSummaryWords = false

    private var appearance: StudyAppearance { StudyAppearance.liveOverride ?? envAppearance }
    private var animated: Bool { dynamicMotion && !reduceMotion }
    private var isManga: Bool { appearance.visualThemeSystem == "manga" }
    private var current: LumaChoiceQuizQuestion? { questions.indices.contains(index) ? questions[index] : nil }
    private var deckTitle: String { decks.first { $0.id == deckID }?.title ?? "词库" }
    private var answered: Bool { picked != nil }
    /// 正文柔化：不用纯黑/纯白，降低长时间注视时的亮度对比。
    private var softInk: Color { appearance.ink.opacity(calmMode ? 0.84 : 0.94) }
    private var quietInk: Color { appearance.ink.opacity(calmMode ? 0.46 : 0.58) }
    private var wrongTint: Color { Color(red: 0.86, green: 0.38, blue: 0.36) }

    var body: some View {
        ZStack {
            calmBackdrop
            VStack(spacing: 0) {
                topBar
                    .padding(.leading, 96)
                    .padding(.trailing, 28)
                    .padding(.top, 14)
                if finished {
                    summary.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let q = current {
                    questionStage(q).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    StudyEmptyState("这个词库还没有可背的单词", symbol: "character.book.closed")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            if showHelp { helpOverlay }
            StudyKeyboardEventMonitor { event in handleKey(event) }.frame(width: 0, height: 0)
            ReadingQuizGamepadMonitor(onPress: handleGamepad)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .saturation(calmMode ? 0.9 : 1.0)
        .onAppear { if questions.isEmpty { resumeOrStartRound() } }
        .onChange(of: deckID) { _, _ in
            reviewCursor = 0
            resumeOrStartRound()
        }
        .onDisappear { pauseReadingPlayback() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            pauseReadingPlayback()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumaReader.AppDidResignActive"))) { _ in
            pauseReadingPlayback()
        }
        .task(id: current?.id) {
            guard autoplay, let q = current, !finished else { return }
            do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
            guard NSApp.isActive, current?.id == q.id, autoplay, !finished else { return }
            speak(q.word.word)
        }
    }

    private func pauseReadingPlayback() {
        advanceTask?.cancel()
        stopSpeech()
    }

    // MARK: 背景：静态、无动画；中心微亮，四周暗角把视线收拢到单词上

    private var calmBackdrop: some View {
        ZStack {
            appearance.background
            appearance.paper.opacity(calmMode ? 0.55 : 0.25)
            RadialGradient(colors: [appearance.accent.opacity(appearance.isDark ? 0.07 : 0.05), .clear],
                           center: UnitPoint(x: 0.5, y: 0.36), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [.clear, Color.black.opacity(appearance.isDark ? (calmMode ? 0.34 : 0.22) : (calmMode ? 0.10 : 0.05))],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 260, endRadius: 980)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: 顶栏：与截图一致的极简布局（返回 · 进度 · 右侧图标）

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { stopSpeech(); onExit() } label: { Image(systemName: "house") }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 11, height: 32))
                .help("返回词库  Esc")
            Text(finished ? "完成" : "\(min(index + 1, max(questions.count, 1)))/\(max(questions.count, 1))")
                .lumaFont(size: 15, weight: .semibold, monospacedDigits: true)
                .foregroundStyle(softInk)
                .contentTransition(.numericText())
            if isReviewRound {
                Text("错题复习").lumaFont(size: 11, weight: .semibold)
                    .foregroundStyle(appearance.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(appearance.accent.opacity(0.14)))
            }
            Spacer(minLength: 8)
            ReadingQuizTimer(active: current != nil && !finished)
            Menu {
                ForEach(decks) { deck in
                    Button { deckID = deck.id } label: {
                        Label(deck.title, systemImage: deck.id == deckID ? "checkmark" : "book.closed")
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "books.vertical")
                    Text(deckTitle).lineLimit(1).frame(maxWidth: 180)
                }
            }
            .menuStyle(.button).menuIndicator(.hidden)
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
            .fixedSize()
            .help("切换词库")
            Button { autoplay.toggle(); if autoplay, let q = current { speak(q.word.word) } } label: {
                Image(systemName: autoplay ? "play.square" : "play.slash")
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(selected: autoplay, horizontalPadding: 11, height: 32))
            .help(autoplay ? "自动播放：开（P）" : "自动播放：关（P）")
            Menu {
                Section("每组单词数") {
                    ForEach([10, 20, 30, 50], id: \.self) { n in
                        Button { roundSize = n } label: { Label("\(n) 词", systemImage: roundSize == n ? "checkmark" : "number") }
                    }
                }
                Toggle("答对自动下一题", isOn: $autoAdvance)
                Toggle("护眼柔和模式", isOn: $calmMode)
                Toggle("显示音标", isOn: $showPhonetic)
                Divider()
                Button { LumaChoiceQuizProgress.setCursor(0, for: deckID); LumaChoiceQuizProgress.saveDraft(nil, for: deckID); reviewCursor = 0; startRound() } label: { Label("从词库开头重新背", systemImage: "arrow.counterclockwise") }
                Button { showHelp = true } label: { Label("键盘与手柄操作", systemImage: "gamecontroller") }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.button).menuIndicator(.hidden)
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
            .fixedSize()
        }
    }

    // MARK: 题目舞台

    private func questionStage(_ q: LumaChoiceQuizQuestion) -> some View {
        GeometryReader { geo in
            let compact = geo.size.height < 620
            VStack(spacing: 0) {
                Spacer(minLength: compact ? 12 : 28)
                wordHeader(q, compact: compact)
                Spacer(minLength: compact ? 18 : 36)
                VStack(spacing: compact ? 10 : 12) {
                    ForEach(Array(q.options.enumerated()), id: \.offset) { offset, text in
                        optionRow(q, offset: offset, text: text, compact: compact)
                    }
                }
                .frame(maxWidth: 640)
                .padding(.horizontal, 24)
                footer(q).padding(.top, compact ? 14 : 22)
                Spacer(minLength: compact ? 14 : 32)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .id(q.id)
        .transition(animated ? AnyTransition.opacity.combined(with: .offset(y: 6)) : AnyTransition.identity)
    }

    private func wordHeader(_ q: LumaChoiceQuizQuestion, compact: Bool) -> some View {
        let phonetic = q.word.phoneticUK.isEmpty ? q.word.phoneticUS : q.word.phoneticUK
        return VStack(spacing: 12) {
            Text(q.word.word)
                .font(.system(size: compact ? 58 : 76, weight: .semibold, design: isManga ? .serif : .rounded))
                .foregroundStyle(softInk)
                .lineLimit(2)
                .minimumScaleFactor(0.45)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .textSelection(.enabled)
            HStack(spacing: 10) {
                Button { speak(q.word.word) } label: {
                    HStack(spacing: 6) {
                        if showPhonetic && !phonetic.isEmpty {
                            Text(phonetic.hasPrefix("[") || phonetic.hasPrefix("/") ? phonetic : "[\(phonetic)]")
                                .lumaFont(size: 14)
                        }
                        Image(systemName: "speaker.wave.2")
                    }
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                .help("重播  Space / R")
            }
            if preparingSpeech {
                Text("正在准备神经语音…")
                    .lumaFont(size: 11.5)
                    .foregroundStyle(quietInk)
            } else if let speechIssue, speechIssue.word == q.word.word {
                Text(speechIssue.message)
                    .lumaFont(size: 11.5)
                    .foregroundStyle(quietInk)
            }
            if answered && !q.word.exampleSentence.isEmpty {
                Text(q.word.exampleSentence)
                    .lumaFont(size: 13.5)
                    .foregroundStyle(quietInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 560)
                    .transition(.opacity)
            }
        }
    }

    private func optionRow(_ q: LumaChoiceQuizQuestion, offset: Int, text: String, compact: Bool) -> some View {
        let split = LumaChoiceQuizBuilder.splitPOS(text)
        let isCorrect = q.isCorrect(offset)
        let isPicked = picked == offset
        let isGone = eliminated.contains(offset) && !answered
        let stateTint: Color? = answered ? (isCorrect ? appearance.accent : (isPicked ? wrongTint : nil)) : nil
        let letter = ["A", "B", "C", "D"][min(offset, 3)]
        let shape = RoundedRectangle(cornerRadius: isManga ? 6 : 18, style: .continuous)
        let badgeColor: Color = stateTint.map { $0.opacity(0.7) } ?? appearance.ink.opacity(0.18)
        let idleBorder: Color = isManga ? appearance.ink.opacity(0.85) : appearance.line
        let borderColor: Color = stateTint.map { $0.opacity(0.75) } ?? idleBorder
        let borderWidth: CGFloat = isManga ? appearance.mangaLineWeight : (stateTint == nil ? 0.8 : 1.4)
        let dimmed: Bool = answered && !isCorrect && !isPicked
        let rowOpacity: Double = dimmed ? 0.55 : (isGone ? 0.6 : 1.0)
        let tintFill: Color = (stateTint ?? .clear).opacity(appearance.isDark ? 0.16 : 0.10)
        let textColor: Color = isGone ? quietInk.opacity(0.5) : softInk
        return Button { choose(offset) } label: {
            HStack(spacing: 14) {
                Text(letter)
                    .lumaFont(size: 12.5, weight: .bold, monospacedDigits: true)
                    .foregroundStyle(stateTint ?? quietInk)
                    .frame(width: 26, height: 26)
                    .background(Circle().strokeBorder(badgeColor, lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    if !split.pos.isEmpty {
                        Text(split.pos).lumaFont(size: 11.5, weight: .medium).foregroundStyle(quietInk)
                    }
                    Text(split.text)
                        .lumaFont(size: compact ? 16 : 17.5, weight: .regular)
                        .foregroundStyle(textColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .strikethrough(isGone, color: quietInk)
                }
                Spacer(minLength: 8)
                if let stateTint {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(stateTint)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    Text("\(offset + 1)").lumaFont(size: 11, monospacedDigits: true).foregroundStyle(quietInk.opacity(0.7))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, compact ? 11 : 14)
            .frame(maxWidth: .infinity, minHeight: compact ? 54 : 64, alignment: .leading)
            .background {
                if isManga {
                    shape.fill(appearance.paper)
                } else if appearance.glassEnabled {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(appearance.surface.opacity(appearance.glassOpacity)))
                } else {
                    shape.fill(appearance.surface)
                }
            }
            .overlay(shape.fill(tintFill))
            .overlay(shape.strokeBorder(borderColor, lineWidth: borderWidth))
            .contentShape(shape)
            .opacity(rowOpacity)
        }
        .buttonStyle(LumaChoiceOptionPressStyle(enabled: animated))
        .disabled(answered || isGone)
        .animation(animated ? .easeOut(duration: autoAdvance && picked == q.correctIndex && !revealedByHelp ? 0.07 : 0.22) : nil, value: picked)
        .animation(animated ? .easeOut(duration: 0.22) : nil, value: eliminated)
        .accessibilityLabel(Text("选项 \(letter)：\(text)"))
    }

    private func footer(_ q: LumaChoiceQuizQuestion) -> some View {
        HStack(spacing: 12) {
            Button("提示") { hint(q) }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 30))
                .disabled(answered || eliminated.count >= max(0, q.options.count - 2))
                .help("排除两个错误选项  H")
            Spacer()
            if answered {
                Button { next() } label: {
                    HStack(spacing: 6) { Text(index + 1 >= questions.count ? "查看结果" : "下一个"); Image(systemName: "return") }
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: picked != q.correctIndex || !autoAdvance, horizontalPadding: 16, height: 30))
            } else {
                Button("看答案") { reveal(q) }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 30))
                    .help("直接显示答案（记为不会）  E")
            }
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, 24)
    }

    // MARK: 结果页

    private var summary: some View {
        let total = questions.count
        let right = correctIDs.count
        let rate = total == 0 ? 0 : Int((Double(right) / Double(total) * 100).rounded())
        return VStack(spacing: 22) {
            Text("\(rate)%")
                .font(.system(size: 64, weight: .semibold, design: isManga ? .serif : .rounded))
                .foregroundStyle(softInk)
            Text("答对 \(right) / \(total)  ·  错词 \(wrongWords.count)")
                .lumaFont(size: 14).foregroundStyle(quietInk)
            if showSummaryWords && !wrongWords.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(wrongWords, id: \.id) { w in
                            HStack(spacing: 12) {
                                Button { speak(w.word) } label: { Image(systemName: "speaker.wave.2") }.buttonStyle(.plain).foregroundStyle(quietInk)
                                Text(w.word).lumaFont(size: 15, weight: .semibold).foregroundStyle(softInk)
                                Spacer(minLength: 12)
                                Text(LumaChoiceQuizBuilder.displayMeaning(for: w)).lumaFont(size: 13).foregroundStyle(quietInk).lineLimit(1)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .studyCard()
                        }
                    }.padding(.horizontal, 2)
                }
                .frame(maxWidth: 560, maxHeight: 260)
            }
            HStack(spacing: 12) {
                if !wrongWords.isEmpty {
                    Button { startReviewRound() } label: { Label("复习错词", systemImage: "arrow.triangle.2.circlepath") }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 16, height: 34))
                }
                if hasNextGroup {
                    Button { startRound() } label: { Label("下一组", systemImage: "arrow.right") }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: wrongWords.isEmpty, horizontalPadding: 16, height: 34))
                }
                if !wrongWords.isEmpty {
                    Menu {
                        Button(showSummaryWords ? "收起错词明细" : "查看错词明细") { showSummaryWords.toggle() }
                    } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .accessibilityLabel("结果操作")
                }
            }
        }
        .padding(32)
    }

    private var helpOverlay: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea().onTapGesture { showHelp = false }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("操作说明").lumaFont(size: 15, weight: .semibold)
                    Spacer()
                    Button("完成") { showHelp = false }
                }
                Text("键盘").lumaFont(size: 13, weight: .semibold)
                ForEach(Self.shortcutRows, id: \.self) { row in
                    let parts = row.components(separatedBy: "|")
                    HStack {
                        Text(verbatim: parts[0]).lumaFont(size: 12.5, weight: .semibold, monospacedDigits: true).frame(width: 130, alignment: .leading)
                        Text(verbatim: parts.count > 1 ? parts[1] : "").lumaFont(size: 12.5).foregroundStyle(quietInk)
                    }
                }
                Divider().padding(.vertical, 3)
                Text("手柄").lumaFont(size: 13, weight: .semibold)
                ForEach(Self.gamepadRows.indices, id: \.self) { index in
                    let (button, action) = Self.gamepadRows[index]
                    HStack {
                        Text(verbatim: button).lumaFont(size: 12.5, weight: .semibold)
                            .frame(width: 130, alignment: .leading)
                        Text(verbatim: action).lumaFont(size: 12.5).foregroundStyle(quietInk)
                    }
                }
            }
            .foregroundStyle(softInk)
            .padding(22)
            .frame(width: 380)
            .studyGlassCapsule(cornerRadius: 18)
        }
    }

    // MARK: 逻辑

    private var hasNextGroup: Bool {
        deckID != LumaChoiceLibrary.reviewDeckID || reviewCursor < wordsForDeck(deckID).count
    }

    private func resumeOrStartRound() {
        advanceTask?.cancel()
        if deckID != LumaChoiceLibrary.reviewDeckID, let draft = LumaChoiceQuizProgress.draft(for: deckID) {
            if draft.isValid(for: wordsForDeck(deckID)) {
                questions = draft.questions
                index = draft.index
                picked = draft.picked
                eliminated = draft.eliminated
                revealedByHelp = draft.revealedByHelp
                correctIDs = draft.correctIDs
                wrongWords = draft.wrongWords
                roundStartCursor = draft.roundStartCursor
                roundEndCursor = draft.roundEndCursor
                finished = false
                isReviewRound = false
                showSummaryWords = false
                return
            }
            LumaChoiceQuizProgress.setCursor(draft.roundStartCursor, for: deckID)
            LumaChoiceQuizProgress.saveDraft(nil, for: deckID)
        }
        startRound()
    }

    private func persistRound() {
        guard deckID != LumaChoiceLibrary.reviewDeckID, !isReviewRound, !questions.isEmpty else { return }
        if finished { LumaChoiceQuizProgress.setCursor(roundEndCursor, for: deckID) }
        LumaChoiceQuizProgress.saveDraft(finished ? nil : ReadingQuizDraft(
            questions: questions, index: index, picked: picked, eliminated: eliminated,
            revealedByHelp: revealedByHelp, correctIDs: correctIDs, wrongWords: wrongWords,
            roundStartCursor: roundStartCursor, roundEndCursor: roundEndCursor
        ), for: deckID)
    }

    private func startRound() {
        advanceTask?.cancel()
        let pool = wordsForDeck(deckID)
        var seen = Set<String>()
        let unique = pool.filter { seen.insert($0.id).inserted && !$0.definitionZH.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if deckID == LumaChoiceLibrary.reviewDeckID {
            guard reviewCursor < unique.count else { return }
            let batch = Array(unique.dropFirst(reviewCursor).prefix(max(5, roundSize)))
            reviewCursor += batch.count
            resetRound(with: batch, deckPool: unique, review: true)
            return
        }
        var cursor = LumaChoiceQuizProgress.cursor(for: deckID)
        if cursor >= unique.count { cursor = 0 }
        roundStartCursor = cursor
        let size = max(5, roundSize)
        let slice = Array(unique[cursor..<min(unique.count, cursor + size)])
        roundEndCursor = cursor + slice.count
        resetRound(with: slice, deckPool: unique, review: false)
    }

    private func startReviewRound() {
        let words = wrongWords
        let pool = wordsForDeck(deckID)
        resetRound(with: words, deckPool: pool.isEmpty ? words : pool, review: true)
    }

    private func resetRound(with words: [VocabularyWord], deckPool: [VocabularyWord], review: Bool) {
        questions = LumaChoiceQuizBuilder.makeRound(words: words, deckPool: deckPool, globalPool: globalPool)
        index = 0; picked = nil; eliminated = []; revealedByHelp = false
        correctIDs = []; wrongWords = []; finished = false; isReviewRound = review
        showSummaryWords = false
        persistRound()
    }

    private func choose(_ offset: Int) {
        guard let q = current, !answered, q.options.indices.contains(offset), !eliminated.contains(offset) else { return }
        let isCorrect = q.isCorrect(offset) && !revealedByHelp
        let advanceQuickly = isCorrect && autoAdvance
        withAnimation(animated ? .easeOut(duration: advanceQuickly ? 0.07 : 0.22) : nil) { picked = offset }
        if isCorrect {
            correctIDs.append(q.word.id)
            if isReviewRound { onReviewCorrect(q.word) }
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            if advanceQuickly {
                advanceTask?.cancel()
                advanceTask = Task { @MainActor in
                    do { try await Task.sleep(for: .milliseconds(80)) } catch { return }
                    guard !Task.isCancelled, NSApp.isActive, autoAdvance, current?.id == q.id else { return }
                    next(quickly: true)
                }
            }
        } else {
            onMiss(q.word)
            if !wrongWords.contains(where: { $0.id == q.word.id }) { wrongWords.append(q.word) }
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
        persistRound()
    }

    private func hint(_ q: LumaChoiceQuizQuestion) {
        guard !answered else { return }
        let wrong = q.options.indices.filter { $0 != q.correctIndex && !eliminated.contains($0) }.shuffled()
        let keep = max(0, q.options.count - 2)
        let removeCount = max(0, keep - eliminated.count)
        withAnimation(animated ? .easeOut(duration: 0.22) : nil) {
            for i in wrong.prefix(removeCount) { eliminated.insert(i) }
        }
        persistRound()
    }

    private func reveal(_ q: LumaChoiceQuizQuestion) {
        guard !answered else { return }
        revealedByHelp = true
        onMiss(q.word)
        if !wrongWords.contains(where: { $0.id == q.word.id }) { wrongWords.append(q.word) }
        withAnimation(animated ? .easeOut(duration: 0.22) : nil) { picked = q.correctIndex }
        persistRound()
    }

    private func next(quickly: Bool = false) {
        advanceTask?.cancel()
        guard answered || finished else { return }
        if index + 1 >= questions.count {
            withAnimation(animated ? .easeInOut(duration: quickly ? 0.1 : 0.28) : nil) { finished = true }
            persistRound()
            stopSpeech()
            return
        }
        withAnimation(animated ? .easeInOut(duration: quickly ? 0.1 : 0.24) : nil) {
            index += 1; picked = nil; eliminated = []; revealedByHelp = false
        }
        persistRound()
    }

    private func advanceFromInput() {
        if finished {
            if hasNextGroup { startRound() }
        } else if answered {
            next()
        }
    }

    private func handleGamepad(_ action: ReadingQuizGamepadAction) {
        if case .help = action {
            showHelp.toggle()
            return
        }
        guard !showHelp else { return }
        switch action {
        case .answer(let index):
            if !finished { choose(index) }
        case .replay:
            if let q = current, !finished { speak(q.word.word) }
        case .advance:
            advanceFromInput()
        case .help:
            break
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard event.window?.isKeyWindow ?? true, event.window?.attachedSheet == nil else { return false }
        if let responder = event.window?.firstResponder as? NSTextView, responder.isEditable { return false }
        let mods = event.modifierFlags.intersection([.command, .option, .control])
        let chars = (event.charactersIgnoringModifiers ?? "").lowercased()
        if mods == .command && chars == "r" { if let q = current { speak(q.word.word) }; return true }
        guard mods.isEmpty else { return false }
        if showHelp { showHelp = false; return true }
        switch event.keyCode {
        case 53: stopSpeech(); onExit(); return true                       // Esc
        case 49: if let q = current, !finished { speak(q.word.word) }; return true // Space
        case 36, 76, 124:                                                    // Return / Enter / →
            advanceFromInput()
            return true
        default: break
        }
        if chars == "?" || chars == "/" { showHelp.toggle(); return true }
        if finished {
            if chars == "w", !wrongWords.isEmpty { startReviewRound(); return true }
            return false
        }
        guard let q = current else { return false }
        let map: [String: Int] = ["1": 0, "2": 1, "3": 2, "4": 3, "a": 0, "b": 1, "c": 2, "d": 3]
        if let i = map[chars], i < q.options.count { choose(i); return true }
        switch chars {
        case "r": speak(q.word.word); return true
        case "h": hint(q); return true
        case "e": reveal(q); return true
        case "p": autoplay.toggle(); return true
        default: return false
        }
    }
}

/// 选项按下反馈：只做极轻的缩放（静态设计 / 减少动态效果时完全关闭）。
struct LumaChoiceOptionPressStyle: ButtonStyle {
    var enabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(enabled && configuration.isPressed ? 0.985 : 1)
            .animation(enabled ? .easeOut(duration: 0.14) : nil, value: configuration.isPressed)
    }
}

// MARK: - 1.11.1 背词独立词库（与听力词库完全分开）
//
// 存储：~/Library/Application Support/LumaReader/ChoiceQuiz/choice_vocab_store.json（原子写入 + .bak 备份）。
// 听力的 luma_study_store.json、听写会话、错词日志都不会被读写。

struct LumaChoiceDeck: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var folderPath: [String]
    var createdAt: Date
    var updatedAt: Date
}

struct LumaChoiceLibrarySnapshot: Codable, Equatable, Sendable {
    var schema: Int = 1
    var decks: [LumaChoiceDeck] = []
    var words: [VocabularyWord] = []
    /// 显式创建的文件夹（含空文件夹）。词库所在路径的上级文件夹会自动视为存在。
    var folders: [[String]] = []
    var readingMisses: [String: Int]?
    var readingDueDates: [String: Date]?
    var builtInReadingFolders: [String: [String]]?
}

@MainActor
final class LumaChoiceLibrary: ObservableObject {
    static let shared = LumaChoiceLibrary()
    static let reviewDeckID = "reading_wrong_review"

    @Published private(set) var snapshot = LumaChoiceLibrarySnapshot()
    @Published var lastError: String?
    private var wordsByDeck: [String: [VocabularyWord]] = [:]
    private let fileURL: URL?

    init(directory: URL? = nil) {
        let dir: URL? = directory ?? (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            .map { $0.appendingPathComponent("LumaReader/ChoiceQuiz", isDirectory: true) }
        if let dir { try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        fileURL = dir?.appendingPathComponent("choice_vocab_store.json")
        load()
    }

    // MARK: 读写

    private var backupURL: URL? { fileURL?.appendingPathExtension("bak") }

    private func load() {
        guard let fileURL else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL) {
            if let decoded = try? decoder.decode(LumaChoiceLibrarySnapshot.self, from: data) {
                apply(decoded); return
            }
            // 损坏的原文件保留一份，绝不覆盖用户数据。
            let damaged = fileURL.deletingLastPathComponent().appendingPathComponent("choice_vocab_store.damaged-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: damaged)
            if let backupURL, let bak = try? Data(contentsOf: backupURL),
               let decoded = try? decoder.decode(LumaChoiceLibrarySnapshot.self, from: bak) {
                apply(decoded)
                lastError = "背词词库文件损坏，已从备份恢复；损坏文件已另存。"
                return
            }
            lastError = "背词词库文件无法读取，原文件已另存为 damaged 副本。"
        }
    }

    @discardableResult
    private func commit(_ next: LumaChoiceLibrarySnapshot) -> Bool {
        let previous = snapshot
        apply(next)
        guard let fileURL else { return true }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(next)
            if let backupURL, FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            }
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            apply(previous)
            lastError = "保存失败，词库保持原样：\(error.localizedDescription)"
            return false
        }
    }

    private func apply(_ next: LumaChoiceLibrarySnapshot) {
        snapshot = next
        var map: [String: [VocabularyWord]] = [:]
        for w in next.words { map[w.deckID, default: []].append(w) }
        wordsByDeck = map
    }

    // MARK: 查询

    var allWords: [VocabularyWord] { snapshot.words }
    func words(in deckID: String) -> [VocabularyWord] { wordsByDeck[deckID] ?? [] }
    func deck(_ id: String) -> LumaChoiceDeck? { snapshot.decks.first { $0.id == id } }

    var readingDecks: [LumaChoiceQuizDeck] {
        ReadingVocabularySource.allCases.map {
            LumaChoiceQuizDeck(id: ReadingVocabularyCatalog.deckID($0), title: $0.title)
        } + snapshot.decks.map {
            LumaChoiceQuizDeck(id: $0.id, title: displayTitle(for: $0))
        }
    }

    var allReadingWords: [VocabularyWord] {
        ReadingVocabularySource.allCases.flatMap { readingWords(in: ReadingVocabularyCatalog.deckID($0)) } + allWords
    }

    func readingWords(in deckID: String) -> [VocabularyWord] {
        ReadingVocabularyCatalog.wordsByDeck[deckID] ?? words(in: deckID)
    }

    func readingWord(id: String) -> VocabularyWord? {
        ReadingVocabularyCatalog.wordsByID[id] ?? allWords.first { $0.id == id }
    }

    var readingWrongWords: [VocabularyWord] {
        guard let misses = snapshot.readingMisses, !misses.isEmpty else { return [] }
        return misses.keys.compactMap { readingWord(id: $0) }.sorted {
            let left = misses[$0.id, default: 0]
            let right = misses[$1.id, default: 0]
            return left == right ? $0.word.localizedStandardCompare($1.word) == .orderedAscending : left > right
        }
    }

    func recordReadingMiss(_ id: String) {
        var next = snapshot
        var misses = next.readingMisses ?? [:]
        misses[id, default: 0] += 1
        next.readingMisses = misses
        next.readingDueDates?.removeValue(forKey: id)
        commit(next)
    }

    func isReadingReviewDue(_ id: String, at now: Date) -> Bool {
        (snapshot.readingDueDates?[id] ?? .distantPast) <= now
    }

    func deferReadingReview(_ id: String) {
        guard snapshot.readingMisses?[id] != nil else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        var next = snapshot
        var dates = next.readingDueDates ?? [:]
        dates[id] = tomorrow
        next.readingDueDates = dates
        commit(next)
    }

    func removeReadingMiss(_ id: String) {
        var next = snapshot
        next.readingMisses?.removeValue(forKey: id)
        next.readingDueDates?.removeValue(forKey: id)
        commit(next)
    }

    var allFolders: [[String]] {
        var set = Set<[String]>()
        func addWithAncestors(_ path: [String]) {
            guard !path.isEmpty else { return }
            for i in 1...path.count { set.insert(Array(path.prefix(i))) }
        }
        snapshot.folders.forEach(addWithAncestors)
        snapshot.decks.forEach { addWithAncestors($0.folderPath) }
        (snapshot.builtInReadingFolders ?? [:]).values.forEach(addWithAncestors)
        return set.sorted { $0.joined(separator: "/").localizedStandardCompare($1.joined(separator: "/")) == .orderedAscending }
    }

    func subfolders(of path: [String]) -> [[String]] {
        allFolders.filter { $0.count == path.count + 1 && Array($0.prefix(path.count)) == path }
    }

    func decks(in path: [String]) -> [LumaChoiceDeck] {
        snapshot.decks.filter { $0.folderPath == path }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// 文件夹内（含所有子文件夹）的词数。
    func wordCount(under path: [String]) -> Int {
        let custom = snapshot.decks.filter { $0.folderPath.starts(with: path) }.reduce(0) { $0 + words(in: $1.id).count }
        return builtInReadingDecks.filter { $0.folderPath.starts(with: path) }.reduce(custom) { $0 + readingWords(in: $1.id).count }
    }

    var builtInReadingDecks: [LumaChoiceDeck] {
        let stamp = Date(timeIntervalSince1970: 0)
        return ReadingVocabularySource.allCases.map { source in
            let id = ReadingVocabularyCatalog.deckID(source)
            return LumaChoiceDeck(id: id, title: source.title, folderPath: snapshot.builtInReadingFolders?[id] ?? [],
                                 createdAt: stamp, updatedAt: stamp)
        }
    }

    func displayTitle(for deck: LumaChoiceDeck) -> String {
        deck.folderPath.isEmpty ? deck.title : deck.folderPath.joined(separator: " / ") + " / " + deck.title
    }

    // MARK: 文件夹

    private func cleanName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "／")
    }

    func createFolder(named raw: String, in parent: [String]) -> String? {
        let name = cleanName(raw)
        guard !name.isEmpty else { return "文件夹名称不能为空" }
        let path = parent + [name]
        guard !allFolders.contains(path) else { return "这里已经有同名文件夹" }
        var next = snapshot
        next.folders.append(path)
        return commit(next) ? nil : lastError
    }

    private static func replacingPrefix(_ path: [String], old: [String], new: [String]) -> [String] {
        path.starts(with: old) ? new + Array(path.dropFirst(old.count)) : path
    }

    private func relocate(folder old: [String], to new: [String]) -> Bool {
        var next = snapshot
        next.folders = next.folders.map { Self.replacingPrefix($0, old: old, new: new) }
        if !next.folders.contains(new) { next.folders.append(new) }
        for i in next.decks.indices where next.decks[i].folderPath.starts(with: old) {
            next.decks[i].folderPath = Self.replacingPrefix(next.decks[i].folderPath, old: old, new: new)
        }
        next.builtInReadingFolders = next.builtInReadingFolders?.mapValues { Self.replacingPrefix($0, old: old, new: new) }
        next.folders = Array(Set(next.folders))
        return commit(next)
    }

    func renameFolder(_ path: [String], to raw: String) -> String? {
        let name = cleanName(raw)
        guard !name.isEmpty, !path.isEmpty else { return "文件夹名称不能为空" }
        let target = Array(path.dropLast()) + [name]
        guard target != path else { return nil }
        guard !allFolders.contains(target) else { return "已经有同名文件夹" }
        return relocate(folder: path, to: target) ? nil : lastError
    }

    func moveFolder(_ path: [String], into parent: [String]) -> String? {
        guard let name = path.last else { return nil }
        guard !parent.starts(with: path) else { return "不能把文件夹移到它自己里面" }
        let target = parent + [name]
        guard target != path else { return nil }
        guard !allFolders.contains(target) else { return "目标位置已有同名文件夹" }
        return relocate(folder: path, to: target) ? nil : lastError
    }

    /// 删除文件夹：里面的词库和子文件夹移到上一级，词条一个都不删。
    func deleteFolder(_ path: [String]) -> String? {
        guard !path.isEmpty else { return nil }
        let parent = Array(path.dropLast())
        var next = snapshot
        next.folders = next.folders.compactMap { f in
            if f == path { return nil }
            return f.starts(with: path) ? parent + Array(f.dropFirst(path.count)) : f
        }
        for i in next.decks.indices where next.decks[i].folderPath.starts(with: path) {
            next.decks[i].folderPath = parent + Array(next.decks[i].folderPath.dropFirst(path.count))
        }
        next.builtInReadingFolders = next.builtInReadingFolders?.mapValues { Self.replacingPrefix($0, old: path, new: parent) }
        next.folders = Array(Set(next.folders))
        return commit(next) ? nil : lastError
    }

    // MARK: 词库

    private func uniqueTitle(_ raw: String, in path: [String], excluding: String? = nil) -> String {
        let base = cleanName(raw).isEmpty ? "未命名词库" : cleanName(raw)
        let taken = Set(snapshot.decks.filter { $0.folderPath == path && $0.id != excluding }.map(\.title))
        guard taken.contains(base) else { return base }
        var n = 2
        while taken.contains("\(base) (\(n))") { n += 1 }
        return "\(base) (\(n))"
    }

    private static func rebased(_ w: VocabularyWord, deckID: String, title: String, keepID: Bool = false) -> VocabularyWord {
        VocabularyWord(id: keepID ? w.id : deckID + "_" + UUID().uuidString,
                       word: w.word, phoneticUK: w.phoneticUK, phoneticUS: w.phoneticUS,
                       partOfSpeech: w.partOfSpeech, definitionZH: w.definitionZH,
                       exampleSentence: w.exampleSentence, deckID: deckID, deckTitle: title)
    }

    @discardableResult
    func createDeck(title raw: String, in path: [String], words: [VocabularyWord]) -> String? {
        let id = "cq_" + UUID().uuidString
        let title = uniqueTitle(raw, in: path)
        var next = snapshot
        next.decks.append(LumaChoiceDeck(id: id, title: title, folderPath: path, createdAt: Date(), updatedAt: Date()))
        next.words += words.map { Self.rebased($0, deckID: id, title: title) }
        return commit(next) ? id : nil
    }

    /// 追加导入：全部保留（包括同词不同义、完全重复），是否加入已由导入预览里的用户勾选决定。
    func appendWords(_ words: [VocabularyWord], to deckID: String) -> String? {
        guard let deck = deck(deckID) else { return "词库不存在" }
        var next = snapshot
        next.words += words.map { Self.rebased($0, deckID: deckID, title: deck.title) }
        if let i = next.decks.firstIndex(where: { $0.id == deckID }) { next.decks[i].updatedAt = Date() }
        return commit(next) ? nil : lastError
    }

    func replaceWords(in deckID: String, with words: [VocabularyWord]) -> String? {
        guard let deck = deck(deckID) else { return "词库不存在" }
        var next = snapshot
        next.words.removeAll { $0.deckID == deckID }
        next.words += words.map { Self.rebased($0, deckID: deckID, title: deck.title, keepID: true) }
        if let i = next.decks.firstIndex(where: { $0.id == deckID }) { next.decks[i].updatedAt = Date() }
        return commit(next) ? nil : lastError
    }

    func renameDeck(_ id: String, to raw: String) -> String? {
        guard let deck = deck(id) else { return nil }
        guard !cleanName(raw).isEmpty else { return "词库名称不能为空" }
        let title = uniqueTitle(raw, in: deck.folderPath, excluding: id)
        var next = snapshot
        if let i = next.decks.firstIndex(where: { $0.id == id }) { next.decks[i].title = title; next.decks[i].updatedAt = Date() }
        next.words = next.words.map { $0.deckID == id ? Self.rebased($0, deckID: id, title: title, keepID: true) : $0 }
        return commit(next) ? nil : lastError
    }

    func moveDeck(_ id: String, to path: [String]) -> String? {
        if let builtIn = builtInReadingDecks.first(where: { $0.id == id }) {
            guard builtIn.folderPath != path else { return nil }
            var next = snapshot
            var folders = next.builtInReadingFolders ?? [:]
            folders[id] = path
            next.builtInReadingFolders = folders
            return commit(next) ? nil : lastError
        }
        guard let deck = deck(id), deck.folderPath != path else { return nil }
        let title = uniqueTitle(deck.title, in: path, excluding: id)
        var next = snapshot
        if let i = next.decks.firstIndex(where: { $0.id == id }) {
            next.decks[i].folderPath = path; next.decks[i].title = title; next.decks[i].updatedAt = Date()
        }
        return commit(next) ? nil : lastError
    }

    func deleteDeck(_ id: String) -> String? {
        var next = snapshot
        next.decks.removeAll { $0.id == id }
        for word in words(in: id) {
            next.readingMisses?.removeValue(forKey: word.id)
            next.readingDueDates?.removeValue(forKey: word.id)
        }
        next.words.removeAll { $0.deckID == id }
        let ok = commit(next)
        if ok {
            LumaChoiceQuizProgress.setCursor(0, for: id)
            LumaChoiceQuizProgress.saveDraft(nil, for: id)
        }
        return ok ? nil : lastError
    }
}

// MARK: 背词词库主页（文件夹 + 词库 + 导入 / 编辑 / 分类）

struct LumaChoiceLibraryView: View {
    @Environment(\.studyAppearance) private var envAppearance
    @ObservedObject var library: LumaChoiceLibrary
    let onStart: @MainActor (String) -> Void

    @Binding var path: [String]
    @Binding var search: String
    @Binding var cardID: String?
    @State private var importShown = false
    @State private var importTargetDeck: String? = nil
    @State private var importDraft: VocabularyImportDraft? = nil
    @State private var editingDeck: LumaChoiceDeck? = nil
    @State private var nameRequest: NameRequest? = nil
    @State private var nameInput = ""
    @State private var deckToDelete: LumaChoiceDeck? = nil
    @State private var folderToDelete: [String]? = nil
    @State private var dropTarget: String? = nil
    @State private var toast: String? = nil

    enum NameRequest: Equatable {
        case newFolder([String]), renameFolder([String]), newDeck([String]), renameDeck(String)
        var title: String {
            switch self {
            case .newFolder: return "新建文件夹"
            case .renameFolder: return "重命名文件夹"
            case .newDeck: return "新建空词库"
            case .renameDeck: return "重命名词库"
            }
        }
    }

    private var appearance: StudyAppearance { StudyAppearance.liveOverride ?? envAppearance }
    private var isManga: Bool { appearance.visualThemeSystem == "manga" }
    private var deckToDeleteCount: Int { deckToDelete.map { library.words(in: $0.id).count } ?? 0 }
    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)]

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var visibleFolders: [[String]] {
        guard !query.isEmpty else { return library.subfolders(of: path) }
        return library.allFolders.filter { $0.starts(with: path) && $0.last?.localizedStandardContains(query) == true }
    }
    private var visibleDecks: [LumaChoiceDeck] {
        let builtIn = library.builtInReadingDecks
        guard !query.isEmpty else { return builtIn.filter { $0.folderPath == path } + library.decks(in: path) }
        return (builtIn + library.snapshot.decks).filter { d in
            d.folderPath.starts(with: path) &&
            (d.title.localizedStandardContains(query) ||
             library.readingWords(in: d.id).contains { $0.word.localizedStandardContains(query) || $0.definitionZH.localizedStandardContains(query) })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            breadcrumb
            if let error = library.lastError {
                HStack {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Spacer()
                    Button("关闭") { library.lastError = nil }.buttonStyle(.borderless)
                }.lumaFont(size: 12)
            }
            ScrollView {
                if visibleFolders.isEmpty && visibleDecks.isEmpty {
                    emptyState.frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(visibleFolders, id: \.self) { folder in folderCard(folder) }
                        ForEach(visibleDecks) { deck in deckCard(deck).id(deck.id) }
                    }
                    .scrollTargetLayout()
                    .padding(.bottom, 32)
                }
            }
            .scrollPosition(id: $cardID)
            .scrollContentBackground(.hidden)
        }
        .padding(.horizontal, 42)
        .padding(.top, 26)
        .background(appearance.background.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).lumaFont(size: 12.5).padding(.horizontal, 16).padding(.vertical, 9)
                    .studyGlassCapsule(cornerRadius: 18).padding(.bottom, 22)
                    .transition(.opacity)
                    .task { try? await Task.sleep(for: .seconds(2.6)); self.toast = nil }
            }
        }
        .fileImporter(isPresented: $importShown, allowedContentTypes: [.plainText, .utf8PlainText, .tabSeparatedText, .commaSeparatedText, .json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                importDraft = try VocabularyImportDraft(data: Data(contentsOf: url), filename: url.lastPathComponent)
            } catch {
                library.lastError = "导入失败，背词词库未更改：\(error.localizedDescription)"
            }
        }
        .sheet(item: $importDraft) { draft in
            VocabularyImportReview(draft: draft, existing: importTargetDeck.map { library.words(in: $0) } ?? [], onConfirm: { words in
                saveImport(words, title: draft.deckTitle)
            })
            .environment(\.studyAppearance, appearance)
        }
        .sheet(item: $editingDeck) { deck in
            LumaChoiceDeckEditorSheet(deck: deck, originalWords: library.words(in: deck.id)) { words in
                library.replaceWords(in: deck.id, with: words)
            }
            .environment(\.studyAppearance, appearance)
        }
        .alert(nameRequest?.title ?? "", isPresented: Binding(get: { nameRequest != nil }, set: { if !$0 { nameRequest = nil } })) {
            TextField("名称", text: $nameInput)
            Button("取消", role: .cancel) { nameRequest = nil }
            Button("确定") { submitName() }
        }
        .confirmationDialog("删除词库「\(deckToDelete?.title ?? "")」？", isPresented: Binding(get: { deckToDelete != nil }, set: { if !$0 { deckToDelete = nil } }), titleVisibility: .visible) {
            Button("删除词库及其 \(deckToDeleteCount) 个词", role: .destructive) {
                if let d = deckToDelete { report(library.deleteDeck(d.id), ok: "已删除「\(d.title)」") }
                deckToDelete = nil
            }
            Button("取消", role: .cancel) { deckToDelete = nil }
        } message: { Text("将删除这个阅读词库及其词条。") }
        .confirmationDialog("删除文件夹「\(folderToDelete?.last ?? "")」？", isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } }), titleVisibility: .visible) {
            Button("删除文件夹（内容移到上一级）", role: .destructive) {
                if let f = folderToDelete { report(library.deleteFolder(f), ok: "已删除文件夹，内容已移到上一级") }
                folderToDelete = nil
            }
            Button("取消", role: .cancel) { folderToDelete = nil }
        } message: { Text("文件夹里的词库和单词不会被删除。") }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("分类").lumaFont(size: 30, weight: .bold, design: .serif).foregroundStyle(appearance.ink)
                Text("\(library.readingDecks.count) 个词库 · \(library.allReadingWords.count) 个词")
                    .lumaFont(size: 12, monospacedDigits: true).foregroundStyle(appearance.ink.opacity(0.55))
            }
            Spacer()
            StudySearchField("搜索词库或单词", text: $search, width: 200)
            Menu {
                Button { requestName(.newFolder(path)) } label: { Label("新建文件夹", systemImage: "folder.badge.plus") }
                Button { requestName(.newDeck(path)) } label: { Label("新建空词库", systemImage: "rectangle.stack.badge.plus") }
            } label: { Image(systemName: "plus") }
            .menuStyle(.button).menuIndicator(.hidden)
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32)).fixedSize()
            .help("新建文件夹 / 词库")
            Button { importTargetDeck = nil; importShown = true } label: { Label("导入", systemImage: "square.and.arrow.down") }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                .help("导入 txt / csv / tsv / json 到当前文件夹")
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            crumb(title: "全部", target: [])
            ForEach(Array(path.enumerated()), id: \.offset) { i, name in
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(appearance.ink.opacity(0.35))
                crumb(title: name, target: Array(path.prefix(i + 1)))
            }
            Spacer()
            if !path.isEmpty, library.wordCount(under: path) > 0 {
                Text("\(library.wordCount(under: path)) 词").lumaFont(size: 12, monospacedDigits: true).foregroundStyle(appearance.ink.opacity(0.5))
            }
        }
    }

    private func crumb(title: String, target: [String]) -> some View {
        let key = "crumb:" + target.joined(separator: "\u{1F}")
        return Button { withAnimation(StudyMotion.page) { path = target } } label: {
            Text(title).lumaFont(size: 13, weight: target == path ? .semibold : .regular)
        }
        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: target == path || dropTarget == key, horizontalPadding: 10, height: 26))
        .dropDestination(for: String.self) { items, _ in handleDrop(items, into: target) } isTargeted: { dropTarget = $0 ? key : (dropTarget == key ? nil : dropTarget) }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack").font(.system(size: 36, weight: .light)).foregroundStyle(appearance.ink.opacity(0.35))
            Text(query.isEmpty ? (path.isEmpty ? "还没有背词词库" : "这个文件夹是空的") : "没有找到匹配的词库")
                .lumaFont(size: 15).foregroundStyle(appearance.ink.opacity(0.6))
            if query.isEmpty {
                HStack(spacing: 10) {
                    Button { importTargetDeck = nil; importShown = true } label: { Label("导入词库", systemImage: "square.and.arrow.down") }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                    Button { requestName(.newDeck(path)) } label: { Label("新建空词库", systemImage: "plus") }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 32))
                }
            }
        }
    }

    // MARK: 卡片

    private func cardBackground(highlight: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: isManga ? 6 : 16, style: .continuous)
        let stroke: Color = highlight ? appearance.accent : (isManga ? appearance.ink.opacity(0.85) : appearance.line)
        let width: CGFloat = highlight ? 2 : (isManga ? appearance.mangaLineWeight : 1)
        return shape.fill(isManga ? AnyShapeStyle(appearance.paper) : AnyShapeStyle(appearance.secondaryGradient))
            .overlay(shape.strokeBorder(stroke, lineWidth: width))
    }

    private func folderCard(_ folder: [String]) -> some View {
        let key = "folder:" + folder.joined(separator: "\u{1F}")
        let deckCount = (library.builtInReadingDecks + library.snapshot.decks).filter { $0.folderPath.starts(with: folder) }.count
        return Button { withAnimation(StudyMotion.page) { path = folder; search = "" } } label: {
            HStack(spacing: 14) {
                Image(systemName: dropTarget == key ? "folder.fill.badge.plus" : "folder.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(appearance.accent.opacity(0.85))
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.last ?? "").lumaFont(size: 15, weight: .semibold).foregroundStyle(appearance.ink).lineLimit(1)
                    Text("\(deckCount) 个词库 · \(library.wordCount(under: folder)) 词")
                        .lumaFont(size: 11.5, monospacedDigits: true).foregroundStyle(appearance.ink.opacity(0.5))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(appearance.ink.opacity(0.3))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(cardBackground(highlight: dropTarget == key))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(LumaChoiceOptionPressStyle(enabled: true))
        .contextMenu {
            Button("打开", systemImage: "folder") { path = folder }
            Button("在此新建文件夹", systemImage: "folder.badge.plus") { requestName(.newFolder(folder)) }
            Button("导入到此文件夹", systemImage: "square.and.arrow.down") { path = folder; importTargetDeck = nil; importShown = true }
            Button("重命名…", systemImage: "pencil") { requestName(.renameFolder(folder)) }
            moveMenu(excluding: folder) { target in report(library.moveFolder(folder, into: target), ok: "已移动文件夹") }
            Divider()
            Button("删除文件夹…", systemImage: "trash", role: .destructive) { folderToDelete = folder }
        }
        .draggable("cq-folder:" + folder.joined(separator: "\u{1F}"))
        .dropDestination(for: String.self) { items, _ in handleDrop(items, into: folder) } isTargeted: { dropTarget = $0 ? key : (dropTarget == key ? nil : dropTarget) }
    }

    private func deckCard(_ deck: LumaChoiceDeck) -> some View {
        let words = library.readingWords(in: deck.id)
        let cursor = min(LumaChoiceQuizProgress.cursor(for: deck.id), words.count)
        let draft = LumaChoiceQuizProgress.draft(for: deck.id)
        let completed = draft.map { $0.roundStartCursor + $0.answeredCount } ?? cursor
        let progress = words.isEmpty ? 0 : Double(min(words.count, completed)) / Double(words.count)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.title).lumaFont(size: 15.5, weight: .semibold).foregroundStyle(appearance.ink).lineLimit(2)
                    if !query.isEmpty && !deck.folderPath.isEmpty {
                        Text(deck.folderPath.joined(separator: " / ")).lumaFont(size: 11).foregroundStyle(appearance.ink.opacity(0.45)).lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                Menu { deckMenu(deck) } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.button).menuIndicator(.hidden).buttonStyle(.borderless).fixedSize()
                    .foregroundStyle(appearance.ink.opacity(0.5))
            }
            Text(words.prefix(4).map(\.word).joined(separator: " · "))
                .lumaFont(size: 12).foregroundStyle(appearance.ink.opacity(0.5)).lineLimit(1)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(words.count) 词").lumaFont(size: 11.5, monospacedDigits: true)
                    Spacer()
                    Text("已背 \(Int((progress * 100).rounded()))%").lumaFont(size: 11.5, monospacedDigits: true)
                }
                .foregroundStyle(appearance.ink.opacity(0.55))
                GeometryReader { g in
                    Capsule().fill(appearance.ink.opacity(0.08))
                        .overlay(alignment: .leading) { Capsule().fill(appearance.accent.opacity(0.75)).frame(width: g.size.width * progress) }
                }.frame(height: 4)
            }
            HStack(spacing: 8) {
                if library.deck(deck.id) != nil {
                    Button { editingDeck = deck } label: { Label("编辑", systemImage: "square.and.pencil").frame(maxWidth: .infinity) }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 8, height: 28))
                }
                Button { onStart(deck.id) } label: { Label(draft == nil ? "开始背词" : "继续背词", systemImage: "play.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 8, height: 28))
                    .disabled(words.isEmpty)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .leading)
        .background(cardBackground(highlight: false))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(count: 2) { if !words.isEmpty { onStart(deck.id) } }
        .contextMenu { deckMenu(deck) }
        .draggable("cq-deck:" + deck.id)
    }

    @ViewBuilder
    private func deckMenu(_ deck: LumaChoiceDeck) -> some View {
        Button("开始背词", systemImage: "play.fill") { onStart(deck.id) }
        if library.deck(deck.id) != nil {
            Button("编辑词条…", systemImage: "square.and.pencil") { editingDeck = deck }
            Button("追加导入到此词库…", systemImage: "square.and.arrow.down") { importTargetDeck = deck.id; importShown = true }
            Button("重命名…", systemImage: "pencil") { requestName(.renameDeck(deck.id)) }
        }
        moveMenu(excluding: nil) { target in report(library.moveDeck(deck.id, to: target), ok: "已移动「\(deck.title)」") }
        Button("从头重新背", systemImage: "arrow.counterclockwise") { LumaChoiceQuizProgress.setCursor(0, for: deck.id); LumaChoiceQuizProgress.saveDraft(nil, for: deck.id); toast = "进度已重置" }
        if library.deck(deck.id) != nil {
            Divider()
            Button("删除词库…", systemImage: "trash", role: .destructive) { deckToDelete = deck }
        }
    }

    /// 「移动到…」子菜单：列出全部文件夹（排除自身及其子文件夹）。
    private func moveMenu(excluding folder: [String]?, perform: @escaping ([String]) -> Void) -> some View {
        let targets = library.allFolders.filter { f in
            guard let folder else { return true }
            return !f.starts(with: folder) && f != Array(folder.dropLast())
        }
        return Menu {
            Button { perform([]) } label: { Label("全部（最外层）", systemImage: "tray") }
            Divider()
            ForEach(targets, id: \.self) { f in
                Button { perform(f) } label: {
                    Text(String(repeating: "    ", count: f.count - 1) + (f.last ?? ""))
                }
            }
        } label: { Label("移动到…", systemImage: "folder") }
    }

    // MARK: 动作

    private func requestName(_ request: NameRequest) {
        switch request {
        case .renameFolder(let f): nameInput = f.last ?? ""
        case .renameDeck(let id): nameInput = library.deck(id)?.title ?? ""
        default: nameInput = ""
        }
        nameRequest = request
    }

    private func submitName() {
        guard let request = nameRequest else { return }
        nameRequest = nil
        switch request {
        case .newFolder(let parent): report(library.createFolder(named: nameInput, in: parent), ok: "已新建文件夹")
        case .renameFolder(let f):
            let error = library.renameFolder(f, to: nameInput)
            if error == nil, path.starts(with: f) {
                path = Array(f.dropLast()) + [nameInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "／")] + Array(path.dropFirst(f.count))
            }
            report(error, ok: "已重命名")
        case .newDeck(let parent):
            if let id = library.createDeck(title: nameInput, in: parent, words: []), let deck = library.deck(id) {
                editingDeck = deck
            }
        case .renameDeck(let id): report(library.renameDeck(id, to: nameInput), ok: "已重命名")
        }
    }

    private func saveImport(_ words: [VocabularyWord], title: String) -> String? {
        guard !words.isEmpty else { return "没有可导入的词条，背词词库保持不变。" }
        if let target = importTargetDeck {
            let error = library.appendWords(words, to: target)
            if error == nil { toast = "已追加 \(words.count) 个词" }
            return error
        }
        guard library.createDeck(title: title, in: path, words: words) != nil else { return library.lastError ?? "保存失败" }
        toast = "已导入 \(words.count) 个词"
        return nil
    }

    private func handleDrop(_ items: [String], into target: [String]) -> Bool {
        guard let item = items.first else { return false }
        if item.hasPrefix("cq-deck:") {
            report(library.moveDeck(String(item.dropFirst("cq-deck:".count)), to: target), ok: "已移动词库")
            return true
        }
        if item.hasPrefix("cq-folder:") {
            let folder = String(item.dropFirst("cq-folder:".count)).components(separatedBy: "\u{1F}")
            guard folder != target else { return false }
            report(library.moveFolder(folder, into: target), ok: "已移动文件夹")
            return true
        }
        return false
    }

    private func report(_ error: String?, ok: String) {
        if let error { library.lastError = error } else { withAnimation(StudyMotion.hover) { toast = ok } }
    }
}

// MARK: 背词词条编辑（允许同一单词保留多个不同释义）

struct LumaChoiceDeckEditorSheet: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.dismiss) private var dismiss
    let deck: LumaChoiceDeck
    let originalWords: [VocabularyWord]
    let onSave: ([VocabularyWord]) -> String?

    @State private var rows: [LumaVocabularyEditRow] = []
    @State private var phonetics: [String: String] = [:]
    @State private var search = ""
    @State private var errorMessage = ""
    @State private var loaded = false

    private var visibleRowIDs: [String] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows.map(\.id) }
        return rows.filter { $0.word.localizedStandardContains(q) || $0.meaning.localizedStandardContains(q) }.map(\.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("编辑背词词库").lumaFont(size: 24, weight: .medium).foregroundStyle(appearance.ink)
                    Text(deck.title + " · \(rows.count) 个词").lumaFont(size: 12).foregroundStyle(appearance.ink.opacity(0.55))
                }
                Spacer()
                StudySearchField("搜索词条", text: $search, width: 200)
                Button { addRow() } label: { Label("新增", systemImage: "plus") }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
            }
            HStack(spacing: 10) {
                Text("英文").frame(minWidth: 180, alignment: .leading)
                Text("音标").frame(width: 120, alignment: .leading)
                Text("中文释义（可写词性，如 n. 门廊）").frame(maxWidth: .infinity, alignment: .leading)
            }
            .lumaFont(size: 11.5).foregroundStyle(appearance.ink.opacity(0.5)).padding(.horizontal, 20)
            List {
                ForEach(visibleRowIDs, id: \.self) { id in editRow(id) }
            }
            .scrollContentBackground(.hidden)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(appearance.surface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(appearance.line, lineWidth: 1)))
            HStack(spacing: 12) {
                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill").lumaFont(size: 12.5).foregroundStyle(appearance.accent)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 16, height: 36))
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 22, height: 36))
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 540)
        .background(appearance.background)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            rows = originalWords.map { LumaVocabularyEditRow(id: $0.id, word: $0.word, meaning: $0.definitionZH) }
            for w in originalWords { phonetics[w.id] = w.phoneticUK.isEmpty ? w.phoneticUS : w.phoneticUK }
        }
    }

    private func binding(_ id: String, _ keyPath: WritableKeyPath<LumaVocabularyEditRow, String>) -> Binding<String> {
        Binding(get: { rows.first { $0.id == id }?[keyPath: keyPath] ?? "" },
                set: { v in if let i = rows.firstIndex(where: { $0.id == id }) { rows[i][keyPath: keyPath] = v } })
    }

    private func phoneticBinding(_ id: String) -> Binding<String> {
        Binding(get: { phonetics[id] ?? "" }, set: { phonetics[id] = $0 })
    }

    private func editRow(_ id: String) -> some View {
        HStack(spacing: 10) {
            TextField("英文单词或短语", text: binding(id, \.word)).autocorrectionDisabled().textFieldStyle(.roundedBorder).frame(minWidth: 180)
            TextField("音标", text: phoneticBinding(id)).autocorrectionDisabled().textFieldStyle(.roundedBorder).frame(width: 120)
            TextField("中文释义", text: binding(id, \.meaning)).textFieldStyle(.roundedBorder).frame(minWidth: 240)
            Button(role: .destructive) { rows.removeAll { $0.id == id } } label: { Image(systemName: "trash").font(.system(size: 12)) }
                .buttonStyle(.borderless).help("删除此条")
        }
        .padding(.vertical, 3)
    }

    private func addRow() {
        search = ""
        rows.insert(LumaVocabularyEditRow(id: deck.id + "_edit_" + UUID().uuidString, word: "", meaning: ""), at: 0)
    }

    private func save() {
        var result: [VocabularyWord] = []
        for row in rows {
            let word = row.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = row.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            if word.isEmpty && meaning.isEmpty { continue }
            guard VocabularyImport.isValidEnglishTerm(word) else { errorMessage = "「\(word.isEmpty ? meaning : word)」不是有效的英文词条"; return }
            guard !meaning.isEmpty else { errorMessage = "「\(word)」缺少中文释义"; return }
            let phonetic = (phonetics[row.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let original = originalWords.first { $0.id == row.id }
            result.append(VocabularyWord(id: row.id, word: word, phoneticUK: phonetic,
                                         phoneticUS: original?.phoneticUS ?? "", partOfSpeech: original?.partOfSpeech ?? "",
                                         definitionZH: meaning, exampleSentence: original?.exampleSentence ?? "",
                                         deckID: deck.id, deckTitle: deck.title))
        }
        if let issue = onSave(result) { errorMessage = issue } else { dismiss() }
    }
}
