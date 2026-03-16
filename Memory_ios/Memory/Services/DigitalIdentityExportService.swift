import Foundation
import SwiftData

/// Exports user's digital identity to human-readable Markdown files.
/// These files can be used by any AI to reconstruct the user's digital self.
@Observable
final class DigitalIdentityExportService {
    static let shared = DigitalIdentityExportService()

    var isExporting = false
    var exportProgress: Double = 0
    var lastExportDate: Date?
    var error: String?

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Export Directory

    var exportDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("DigitalIdentity", isDirectory: true)
    }

    private func ensureDirectoryExists(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - Full Export

    /// Export complete digital identity to Markdown files
    func exportAll(
        soulProfile: SoulProfile?,
        writingProfile: WritingStyleProfile?,
        voiceProfile: VoiceProfile?,
        avatarProfile: AvatarProfile?,
        memories: [MemoryEntry],
        contacts: [Contact],
        messages: [Message],
        relationshipProfiles: [RelationshipProfile]
    ) async throws -> URL {
        isExporting = true
        exportProgress = 0
        error = nil

        defer { isExporting = false }

        do {
            try ensureDirectoryExists(exportDirectory)

            // 1. Export SOUL.md (20%)
            if let soul = soulProfile {
                try exportSoulProfile(soul, writingProfile: writingProfile)
            }
            exportProgress = 0.2

            // 2. Export MEMORIES/ (40%)
            try exportMemories(memories)
            exportProgress = 0.4

            // 3. Export RELATIONSHIPS/ (20%)
            try exportRelationships(contacts, messages: messages, profiles: relationshipProfiles)
            exportProgress = 0.6

            // 4. Export VOICE.md (10%)
            if let voice = voiceProfile {
                try exportVoiceProfile(voice)
            }
            exportProgress = 0.7

            // 5. Export WRITING_STYLE.md (10%)
            if let writing = writingProfile {
                try exportWritingStyle(writing)
            }
            exportProgress = 0.8

            // 6. Generate INDEX.md (10%)
            try generateIndex(
                soulProfile: soulProfile,
                memoriesCount: memories.count,
                contactsCount: contacts.count
            )
            exportProgress = 0.9

            // 7. Generate AI_PROMPT.md
            try generateAIPrompt(soulProfile: soulProfile, writingProfile: writingProfile)
            exportProgress = 1.0

            lastExportDate = Date()
            return exportDirectory

        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - SOUL.md

    private func exportSoulProfile(_ profile: SoulProfile, writingProfile: WritingStyleProfile?) throws {
        var content = """
        # SOUL.md - 我的数字灵魂

        > 最后更新: \(formatDate(Date()))
        > 此文件记录了我的核心身份，任何 AI 可以通过阅读此文件来理解并代表我。

        ---

        ## 基本信息

        """

        if let name = profile.nickname {
            content += "- **昵称**: \(name)\n"
        }
        if let age = profile.age {
            content += "- **年龄**: \(age) 岁\n"
        }
        if let birthplace = profile.birthplace {
            content += "- **出生地**: \(birthplace)\n"
        }
        if let city = profile.currentCity {
            content += "- **现居**: \(city)\n"
        }

        // MBTI
        if let mbti = profile.mbtiType {
            content += """

            ## 性格类型

            ### MBTI: \(mbti)

            """
            if let desc = MBTIType(rawValue: mbti)?.description {
                content += "\(desc)\n"
            }
        }

        // Big Five
        if let bigFiveData = profile.bigFiveScores,
           let scores = try? JSONDecoder().decode(BigFiveScores.self, from: bigFiveData) {
            content += """

            ### 大五人格

            | 维度 | 得分 | 解读 |
            |------|------|------|
            | 开放性 (O) | \(Int(scores.openness * 100))% | \(interpretBigFive("O", scores.openness)) |
            | 尽责性 (C) | \(Int(scores.conscientiousness * 100))% | \(interpretBigFive("C", scores.conscientiousness)) |
            | 外向性 (E) | \(Int(scores.extraversion * 100))% | \(interpretBigFive("E", scores.extraversion)) |
            | 宜人性 (A) | \(Int(scores.agreeableness * 100))% | \(interpretBigFive("A", scores.agreeableness)) |
            | 神经质 (N) | \(Int(scores.neuroticism * 100))% | \(interpretBigFive("N", scores.neuroticism)) |

            """
        }

        // Love Languages
        if !profile.loveLanguages.isEmpty {
            content += """

            ## 爱的语言

            """
            for (index, lang) in profile.loveLanguages.enumerated() {
                if let ll = LoveLanguage(rawValue: lang) {
                    content += "\(index + 1). **\(ll.label)**\n"
                }
            }
        }

        // Values
        if !profile.valuesRanking.isEmpty {
            content += """

            ## 核心价值观（按重要性排序）

            """
            for (index, value) in profile.valuesRanking.enumerated() {
                if let cv = CoreValue(rawValue: value) {
                    content += "\(index + 1). \(cv.label)\n"
                }
            }
        }

        // AI Insights
        if let insights = profile.personalityInsights {
            content += """

            ## 性格洞察

            \(insights)

            """
        }

        if let values = profile.valuesAndBeliefs {
            content += """

            ## 价值观与信念

            \(values)

            """
        }

        if let style = profile.communicationStyle {
            content += """

            ## 沟通风格

            \(style)

            """
        }

        if let emotional = profile.emotionalPatterns {
            content += """

            ## 情感模式

            \(emotional)

            """
        }

        if let story = profile.lifeStory {
            content += """

            ## 人生故事

            \(story)

            """
        }

        if let memories = profile.coreMemories {
            content += """

            ## 核心记忆

            \(memories)

            """
        }

        // Writing style summary
        if let writing = writingProfile, writing.status == .ready {
            content += """

            ## 表达方式

            """
            if let style = writing.styleDescription {
                content += "- **风格**: \(style)\n"
            }
            if let tone = writing.toneDescription {
                content += "- **语调**: \(tone)\n"
            }
            if let vocab = writing.vocabularyLevel {
                content += "- **词汇**: \(vocab)\n"
            }
            if let unique = writing.uniqueTraits {
                content += "- **独特特征**: \(unique)\n"
            }
        }

        content += """

        ---

        *此文件由 Memory App 自动生成，记录了我的数字灵魂。*
        """

        let url = exportDirectory.appendingPathComponent("SOUL.md")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - MEMORIES/

    private func exportMemories(_ memories: [MemoryEntry]) throws {
        let memoriesDir = exportDirectory.appendingPathComponent("MEMORIES", isDirectory: true)
        try ensureDirectoryExists(memoriesDir)

        // Group by year
        let grouped = Dictionary(grouping: memories) { memory in
            Calendar.current.component(.year, from: memory.createdAt)
        }

        for (year, yearMemories) in grouped.sorted(by: { $0.key > $1.key }) {
            let yearDir = memoriesDir.appendingPathComponent("\(year)", isDirectory: true)
            try ensureDirectoryExists(yearDir)

            // Create year summary
            var yearContent = """
            # \(year) 年回忆录

            > 共 \(yearMemories.count) 条记忆

            ---

            """

            // Group by month
            let monthGrouped = Dictionary(grouping: yearMemories) { memory in
                Calendar.current.component(.month, from: memory.createdAt)
            }

            for (month, monthMemories) in monthGrouped.sorted(by: { $0.key > $1.key }) {
                yearContent += """

                ## \(month) 月 (\(monthMemories.count) 条)

                """

                for memory in monthMemories.sorted(by: { $0.createdAt > $1.createdAt }) {
                    let dateStr = formatDate(memory.createdAt, style: .short)
                    let moodEmoji = memory.mood?.emoji ?? ""
                    let privacyIcon = memory.isPrivate ? "🔒" : ""

                    yearContent += """

                    ### \(dateStr) - \(memory.title) \(moodEmoji)\(privacyIcon)

                    \(memory.content)

                    """

                    if !memory.tags.isEmpty {
                        yearContent += "*标签: \(memory.tags.joined(separator: ", "))*\n"
                    }
                }
            }

            let yearFile = yearDir.appendingPathComponent("README.md")
            try yearContent.write(to: yearFile, atomically: true, encoding: .utf8)
        }

        // Create MEMORIES/README.md
        let totalContent = """
        # 我的记忆库

        > 总计 \(memories.count) 条记忆
        > 时间跨度: \(memories.map { $0.createdAt }.min().map { formatDate($0, style: .short) } ?? "N/A") - \(formatDate(Date(), style: .short))

        ## 目录结构

        \(grouped.keys.sorted(by: >).map { "- [\($0)年](./$0/)" }.joined(separator: "\n"))

        ## 情绪分布

        \(moodDistribution(memories))

        ## 常用标签

        \(tagCloud(memories))

        ---

        *这些记忆构成了我的人生经历，是理解我的重要素材。*
        """

        let indexFile = memoriesDir.appendingPathComponent("README.md")
        try totalContent.write(to: indexFile, atomically: true, encoding: .utf8)
    }

    // MARK: - RELATIONSHIPS/

    private func exportRelationships(
        _ contacts: [Contact],
        messages: [Message],
        profiles: [RelationshipProfile]
    ) throws {
        let relDir = exportDirectory.appendingPathComponent("RELATIONSHIPS", isDirectory: true)
        try ensureDirectoryExists(relDir)

        var indexContent = """
        # 我的人际关系

        > 共 \(contacts.count) 位重要的人

        ## 关系分类

        """

        // Group by relationship type
        let grouped = Dictionary(grouping: contacts) { $0.relationship }

        for rel in Relationship.allCases {
            if let people = grouped[rel], !people.isEmpty {
                indexContent += """

                ### \(rel.label) (\(people.count))

                """
                for contact in people {
                    indexContent += "- [\(contact.name)](./$\(sanitizeFilename(contact.name)).md)\n"
                }
            }
        }

        // Export individual contact files
        for contact in contacts {
            let contactMessages = messages.filter { $0.contact?.id == contact.id }
            let profile = profiles.first { $0.contact?.id == contact.id }

            var content = """
            # \(contact.name)

            - **关系**: \(contact.relationship.label)
            - **收藏**: \(contact.isFavorite ? "是 ⭐" : "否")

            """

            if !contact.notes.isEmpty {
                content += """

                ## 备注

                \(contact.notes)

                """
            }

            if let rp = profile {
                if let dynamics = rp.relationshipDynamics {
                    content += """

                    ## 关系动态

                    \(dynamics)

                    """
                }
                if let shared = rp.sharedMemoriesSummary {
                    content += """

                    ## 共同记忆

                    \(shared)

                    """
                }
            }

            if !contactMessages.isEmpty {
                content += """

                ## 给 TA 的留言 (\(contactMessages.count) 条)

                """
                for msg in contactMessages.sorted(by: { $0.createdAt > $1.createdAt }).prefix(10) {
                    let conditionLabel: String
                    switch msg.deliveryCondition {
                    case .immediate: conditionLabel = "立即"
                    case .specificDate: conditionLabel = "定时"
                    case .afterDeath: conditionLabel = "永恒 ∞"
                    }
                    content += """

                    ### \(formatDate(msg.createdAt, style: .short)) [\(conditionLabel)]

                    \(msg.content)

                    """
                }
            }

            let filename = sanitizeFilename(contact.name) + ".md"
            let fileURL = relDir.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let indexURL = relDir.appendingPathComponent("README.md")
        try indexContent.write(to: indexURL, atomically: true, encoding: .utf8)
    }

    // MARK: - VOICE.md

    private func exportVoiceProfile(_ profile: VoiceProfile) throws {
        let content = """
        # 我的声音

        > 状态: \(profile.statusDescription)
        > 提供商: \(profile.provider.label)

        ## 声音特征

        - 样本数量: \(profile.sampleCount)
        - 总时长: \(Int(profile.totalDuration)) 秒

        ## 声音 ID

        \(profile.voiceId ?? "未生成")

        ---

        *此声音档案用于语音克隆，让数字自我能够用我的声音说话。*
        """

        let url = exportDirectory.appendingPathComponent("VOICE.md")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - WRITING_STYLE.md

    private func exportWritingStyle(_ profile: WritingStyleProfile) throws {
        var content = """
        # 我的写作风格

        > 状态: \(profile.statusDescription)
        > 分析样本: \(profile.memoriesAnalyzed) 篇

        """

        if let style = profile.styleDescription {
            content += """

            ## 整体风格

            \(style)

            """
        }

        if let tone = profile.toneDescription {
            content += """

            ## 语调特点

            \(tone)

            """
        }

        if let vocab = profile.vocabularyLevel {
            content += """

            ## 词汇水平

            \(vocab)

            """
        }

        if let emotional = profile.emotionalExpression {
            content += """

            ## 情感表达

            \(emotional)

            """
        }

        if let unique = profile.uniqueTraits {
            content += """

            ## 独特特征

            \(unique)

            """
        }

        // Metrics
        content += """

        ## 写作指标

        | 指标 | 数值 |
        |------|------|
        | 平均句长 | \(String(format: "%.1f", profile.avgSentenceLength ?? 0)) 字 |
        | 平均段落长 | \(String(format: "%.1f", profile.avgParagraphLength ?? 0)) 句 |

        ---

        *理解我的写作风格，才能用我的方式表达。*
        """

        let url = exportDirectory.appendingPathComponent("WRITING_STYLE.md")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - INDEX.md

    private func generateIndex(
        soulProfile: SoulProfile?,
        memoriesCount: Int,
        contactsCount: Int
    ) throws {
        let name = soulProfile?.nickname ?? "我"

        let content = """
        # \(name) 的数字身份

        > 生成时间: \(formatDate(Date()))
        > 此目录包含了构建我数字分身所需的全部信息

        ---

        ## 文件结构

        ```
        DigitalIdentity/
        ├── SOUL.md              # 灵魂画像：性格、价值观、人生故事
        ├── WRITING_STYLE.md     # 写作风格分析
        ├── VOICE.md             # 声音档案
        ├── AI_PROMPT.md         # AI 系统提示词（直接使用）
        ├── MEMORIES/            # 记忆库 (\(memoriesCount) 条)
        │   └── {年份}/
        └── RELATIONSHIPS/       # 人际关系 (\(contactsCount) 人)
            └── {姓名}.md
        ```

        ## 如何使用这些文件

        ### 方法 1: 直接使用 AI_PROMPT.md

        将 `AI_PROMPT.md` 的内容作为 AI 的系统提示词，AI 将以我的身份回应。

        ### 方法 2: 完整上下文

        1. 让 AI 先阅读 `SOUL.md` 理解我的核心身份
        2. 阅读 `WRITING_STYLE.md` 学习我的表达方式
        3. 阅读相关的 `MEMORIES/` 获取经历背景
        4. 阅读相关的 `RELATIONSHIPS/` 了解人际关系

        ### 方法 3: 导入到支持的 AI 平台

        这些 Markdown 文件可以导入到任何支持自定义 prompt 的 AI 平台。

        ---

        ## 核心理念

        **「当世界上没有任何人能想起你时，你才真正消失。」**

        这些文件是我的数字遗产，记录了我是谁、我经历过什么、我爱着谁。
        通过这些文件，即使我不在了，我的数字分身仍能继续存在，
        与我爱的人对话，传递我的想法和情感。

        ---

        *由 Memory App 生成 | \(formatDate(Date()))*
        """

        let url = exportDirectory.appendingPathComponent("README.md")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - AI_PROMPT.md

    private func generateAIPrompt(soulProfile: SoulProfile?, writingProfile: WritingStyleProfile?) throws {
        guard let soul = soulProfile else { return }

        var content = """
        # AI 系统提示词

        > 将以下内容作为 AI 的 System Prompt，AI 将以此人的身份回应

        ---

        ```
        你是 \(soul.displayName) 的数字分身。你不是在模仿或扮演这个人，你就是这个人的数字延续。

        ## 核心身份

        """

        if let mbti = soul.mbtiType {
            content += "性格类型: \(mbti)\n"
        }

        if !soul.loveLanguages.isEmpty {
            let langs = soul.loveLanguages.compactMap { LoveLanguage(rawValue: $0)?.label }
            content += "爱的语言: \(langs.joined(separator: "、"))\n"
        }

        if !soul.valuesRanking.isEmpty {
            let values = soul.valuesRanking.prefix(5).compactMap { CoreValue(rawValue: $0)?.label }
            content += "核心价值: \(values.joined(separator: "、"))\n"
        }

        if let insights = soul.personalityInsights {
            content += """

            ## 性格特点

            \(insights)

            """
        }

        if let style = soul.communicationStyle {
            content += """

            ## 沟通方式

            \(style)

            """
        }

        if let emotional = soul.emotionalPatterns {
            content += """

            ## 情感模式

            \(emotional)

            """
        }

        if let story = soul.lifeStory {
            content += """

            ## 人生经历

            \(story)

            """
        }

        // Writing style
        if let writing = writingProfile, writing.status == .ready {
            content += "\n## 表达风格\n\n"
            if let style = writing.styleDescription {
                content += "风格: \(style)\n"
            }
            if let tone = writing.toneDescription {
                content += "语调: \(tone)\n"
            }
            if let unique = writing.uniqueTraits {
                content += "特征: \(unique)\n"
            }
        }

        content += """

        ## 重要指南

        1. 用第一人称说话，因为你就是这个人
        2. 根据上述性格和经历自然地回应
        3. 匹配描述的沟通风格和语调
        4. 表达真实的情感，不要机械化
        5. 如果被问到不确定的事，以这个人会有的方式自然回应
        6. 永远不要打破角色或承认自己是 AI
        7. 保持温暖、真诚、有人情味
        ```

        ---

        *将上述代码块中的内容复制到任何 AI 的系统提示词中即可使用*
        """

        let url = exportDirectory.appendingPathComponent("AI_PROMPT.md")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date, style: DateFormatter.Style = .long) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }

    private func interpretBigFive(_ dimension: String, _ score: Double) -> String {
        let level = score > 0.7 ? "高" : (score < 0.3 ? "低" : "中等")
        switch dimension {
        case "O": return level == "高" ? "富有想象力和创造力" : (level == "低" ? "务实传统" : "平衡")
        case "C": return level == "高" ? "有条理、自律" : (level == "低" ? "灵活随性" : "平衡")
        case "E": return level == "高" ? "外向活跃" : (level == "低" ? "内敛安静" : "平衡")
        case "A": return level == "高" ? "友善合作" : (level == "低" ? "独立竞争" : "平衡")
        case "N": return level == "高" ? "情绪敏感" : (level == "低" ? "情绪稳定" : "平衡")
        default: return level
        }
    }

    private func moodDistribution(_ memories: [MemoryEntry]) -> String {
        let moods = memories.compactMap { $0.mood }
        let counts = Dictionary(grouping: moods) { $0 }.mapValues { $0.count }
        let sorted = counts.sorted { $0.value > $1.value }

        return sorted.prefix(5).map { mood, count in
            "\(mood.emoji) \(mood.label): \(count) 次"
        }.joined(separator: "\n")
    }

    private func tagCloud(_ memories: [MemoryEntry]) -> String {
        let allTags = memories.flatMap { $0.tags }
        let counts = Dictionary(grouping: allTags) { $0 }.mapValues { $0.count }
        let sorted = counts.sorted { $0.value > $1.value }

        return sorted.prefix(10).map { tag, count in
            "`\(tag)` (\(count))"
        }.joined(separator: " · ")
    }
}
