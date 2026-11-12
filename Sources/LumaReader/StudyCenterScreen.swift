import SwiftUI
import LumaReaderStudyKit

struct StudyCenterScreen: View {
    @Binding var mode:String
    @Bindable var store:LibraryStore
    let session:LumaStudySession
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body:some View {
        let themeSystem = store.visualThemeSystem
        let dark = store.isDarkAppearance || ((themeSystem == .monet || themeSystem.isAnimeFreshSeries) && colorScheme == .dark && store.appearance == .system)
        let mangaWeight = CGFloat(store.mangaLineWeight)
        let palette = store.readingPalette(dark:dark)
        let paperColor = store.paper(dark:dark)
        let chromeColor = store.chrome(dark:dark)
        let accentColor = store.accent
        let inkColor = palette.ink
        let glassActive: Bool = {
            if reduceTransparency || !store.effectiveGlassEffectsEnabled { return false }
            switch themeSystem {
            case .monet, .space: return true
            case .manga: return false
            default: return store.animeBlendLiquidGlass
            }
        }()
        let currentAppearance = StudyAppearance(
            paper: paperColor,
            ink: inkColor,
            accent: accentColor,
            surface: chromeColor,
            glassEnabled: glassActive,
            glassOpacity: themeSystem == .space ? store.spaceGlassOpacity : store.glassOpacity,
            isDark: dark,
            visualThemeSystem: themeSystem == .manga ? store.mangaStyleSystemKey : themeSystem.rawValue,
            spaceGlowIntensity: themeSystem.isAnimeFreshSeries ? store.animeAtmosphereIntensity : store.spaceGlowIntensity,
            spaceOrbitalLines: themeSystem.isAnimeFreshSeries ? store.animeShowCanvasDetails : store.spaceOrbitalLines,
            mangaScreentoneDensity: themeSystem.isAnimeFreshSeries ? store.animeAtmosphereIntensity : store.mangaScreentoneDensity,
            mangaLineWeight: store.mangaLineWeight,
            mangaPopoverTranslucent: store.mangaPopoverTranslucent,
            glassRenderer: { view, radius, prominent, selected, _ in
                if themeSystem == .manga {
                    let shape = RoundedRectangle(cornerRadius:min(radius,4),style:.continuous)
                    return AnyView(view.background {
                        ZStack {
                            shape.fill(accentColor).offset(x:2.2,y:2.2)
                            shape.fill(prominent ? accentColor : (selected ? chromeColor : paperColor))
                        }
                    }
                    .foregroundStyle(prominent ? paperColor : inkColor)
                    .overlay(shape.strokeBorder(accentColor,lineWidth:mangaWeight + (selected ? 0.5:0)).allowsHitTesting(false)))
                }
                if themeSystem == .space {
                    let shape = RoundedRectangle(cornerRadius:radius,style:.continuous)
                    if prominent {
                        return AnyView(view.background(shape.fill(LinearGradient(colors:[accentColor.opacity(0.85),Color(hex:"111629")],startPoint:.topLeading,endPoint:.bottomTrailing)))
                            .overlay(shape.strokeBorder(Color(hex:"C6CAD9").opacity(0.55),lineWidth:1).allowsHitTesting(false)))
                    }
                    return AnyView(view.readerGlass(radius:radius,enabled:glassActive,tint:chromeColor)
                        .overlay(shape.strokeBorder(accentColor.opacity(selected ? 0.75:0),lineWidth:1.15).allowsHitTesting(false)))
                }
                if themeSystem.isAnimeFreshSeries {
                    let effectiveRadius: CGFloat = {
                        switch themeSystem {
                        case .nier: return min(radius, 2)
                        case .zelda: return min(radius, 4)
                        case .wasteland: return min(radius, 3)
                        case .kanagawa, .mangaCity: return min(radius, 5)
                        case .mangaOcean: return min(radius, 6)
                        case .mangaForest: return min(radius, 9)
                        case .akari: return min(radius, 10)
                        case .chihiro: return min(radius, 11)
                        case .shinkai: return min(radius, 12)
                        case .roseDawn: return min(radius, 14)
                        case .matcha: return min(radius, 18)
                        default: return radius
                        }
                    }()
                    let shape = RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                    if prominent {
                        return AnyView(
                            view.background(shape.fill(accentColor))
                                .overlay(shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 1.0).allowsHitTesting(false))
                        )
                    } else if selected {
                        return AnyView(
                            view.readerGlass(radius: effectiveRadius, enabled: glassActive, tint: chromeColor)
                                .overlay(shape.fill(accentColor.opacity(dark ? 0.24 : 0.14)).allowsHitTesting(false))
                                .overlay(shape.strokeBorder(accentColor, lineWidth: 1.5).allowsHitTesting(false))
                        )
                    } else {
                        return AnyView(
                            view.readerGlass(radius: effectiveRadius, enabled: glassActive, tint: chromeColor)
                        )
                    }
                }
                if prominent {
                    return AnyView(
                        view.background(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(accentColor.gradient)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(Color.white.opacity(dark ? 0.22 : 0.35), lineWidth: 0.8)
                        )
                    )
                } else if selected {
                    return AnyView(
                        view.readerGlass(radius: radius, enabled: glassActive, tint: accentColor.opacity(dark ? 0.35 : 0.24))
                            .overlay(
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .strokeBorder(accentColor.opacity(0.60), lineWidth: 1.1)
                            )
                    )
                } else {
                    return AnyView(
                        view.readerGlass(radius: radius, enabled: glassActive, tint: chromeColor)
                    )
                }
            }
        )
        let _ = {
            StudyAppearance.current = currentAppearance
            StudyAppearance.liveOverride = currentAppearance
        }()
        LumaGlassCluster(enabled: glassActive) {
            Group {
            let taskAwareEvaluator: @MainActor (WritingSubmissionRecord, Task1QuestionItem) async throws -> IELTSFourCriteriaEstimate = { record, question in
                let audit = IELTSOfficialRubricEngine.audit(record: record, question: question)
                let enrichedQuestion = IELTSOfficialRubricEngine.enrichQuestionWithOfficialRubric(question, for: record, audit: audit)
                let prompts = IELTSOfficialRubricEngine.buildTaskAwareAIPrompt(record: record, question: question, audit: audit)

                let customAI = LumaCustomAIProviderStore.shared
                let activeProv = customAI.activeProvider
                let hasCustomConfig = !activeProv.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || activeProv.baseURL.contains("localhost")
                    || activeProv.baseURL.contains("127.0.0.1")
                if hasCustomConfig {
                    if let rawReply = try? await customAI.performCompletionRequest(
                        provider: activeProv,
                        systemPrompt: prompts.systemPrompt,
                        history: [LumaAIChatMessageItem(role: .user, content: prompts.userPrompt, providerName: "你", modelID: activeProv.modelID)]
                    ), let jsonStart = rawReply.firstIndex(of: "{"), let jsonEnd = rawReply.lastIndex(of: "}") {
                        let jsonSlice = String(rawReply[jsonStart...jsonEnd])
                        if let data = jsonSlice.data(using: .utf8),
                           let decoded = try? JSONDecoder().decode(IELTSFourCriteriaEstimate.self, from: data) {
                            return IELTSOfficialRubricEngine.calibrate(aiEstimate: decoded, with: audit)
                        }
                    }
                }

                do {
                    let rawAI = try await StudyWritingEvaluation.evaluate(record, question: enrichedQuestion, store: store)
                    return IELTSOfficialRubricEngine.calibrate(aiEstimate: rawAI, with: audit)
                } catch {
                    return audit.deterministicEstimate
                }
            }
            #if DEBUG
            LumaStudyCenterHostView(mode:$mode,session:session,evaluateWriting:taskAwareEvaluator)
                .onAppear { DebugReaderAcceptance.studyMounted = true }
                .onDisappear { DebugReaderAcceptance.studyMounted = false }
            #else
            LumaStudyCenterHostView(mode:$mode,session:session,evaluateWriting:taskAwareEvaluator)
            #endif
            }
            .environment(\.lumaSurfacePolish, true)
            .environment(\.studyAppearance, currentAppearance)
            .foregroundStyle(inkColor)
            .tint(accentColor)
            .accentColor(accentColor)
        }
    }
}
