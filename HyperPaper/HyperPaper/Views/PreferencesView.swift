//
// PreferencesView.swift
// HyperPaper
//
// 偏好设置视图：整合模型设置和公式处理设置
//

import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedModelId: String = APIConfig.model
    @State private var selectedMode: FormulaProcessingMode = FormulaProcessingMode.current
    @State private var selectedTargetLanguage: TranslationTargetLanguage = TranslationTargetLanguage.current
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            contentView
            footerView
        }
        .frame(width: 600, height: 700)
        .background(backgroundView)
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            Text("偏好设置")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.thinMaterial)
    }
    
    // MARK: - 内容区域
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 30) {
                modelSettingsSection
                formulaModeSection
                translationLanguageSection
            }
            .padding()
        }
    }
    
    // MARK: - 模型设置区域
    private var modelSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模型设置")
                .font(.headline)
                .foregroundColor(.primary)
            
            List(APIConfig.availableModels, id: \.id) { model in
                ModelRow(
                    model: model,
                    isSelected: selectedModelId == model.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedModelId = model.id
                        }
                    }
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .frame(height: 250)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - 翻译目标语言设置区域
    private var translationLanguageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("翻译目标语言")
                .font(.headline)
                .foregroundColor(.primary)
            
            List(TranslationTargetLanguage.allCases, id: \.id) { language in
                TranslationLanguageRow(
                    language: language,
                    isSelected: selectedTargetLanguage.id == language.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTargetLanguage = language
                        }
                    }
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - 公式处理模式设置区域
    private var formulaModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("公式处理模式")
                .font(.headline)
                .foregroundColor(.primary)
            
            List(FormulaProcessingMode.allCases, id: \.id) { mode in
                FormulaModeRow(
                    mode: mode,
                    isSelected: selectedMode.id == mode.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMode = mode
                        }
                    }
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - 底部按钮
    private var footerView: some View {
        HStack(spacing: 12) {
            Button("取消") {
                dismiss()
            }
            .buttonStyle(LiquidGlassButtonStyle(color: .gray, isProminent: false))
            
            Button("确定") {
                saveSettings()
                dismiss()
            }
            .buttonStyle(LiquidGlassButtonStyle(color: Color(red: 0.5, green: 0.2, blue: 0.8), isProminent: true))
        }
        .padding()
        .background(.thinMaterial)
    }
    
    // MARK: - 背景视图
    private var backgroundView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.white.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 保存设置
    private func saveSettings() {
        // 保存模型设置
        APIConfig.model = selectedModelId
        UserDefaults.standard.synchronize()
        
        // 保存公式处理模式
        FormulaProcessingMode.current = selectedMode
        UserDefaults.standard.synchronize()
        
        // 保存翻译目标语言
        TranslationTargetLanguage.current = selectedTargetLanguage
        UserDefaults.standard.synchronize()
    }
}

// MARK: - 模型行视图
private struct ModelRow: View {
    let model: ModelInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(model.price)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(red: 0.5, green: 0.2, blue: 0.8))
                    .symbolEffect(.bounce, value: isSelected)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(selectionBackground)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private var selectionBackground: some View {
        Group {
            if isSelected {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2),
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.4),
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - 公式模式行视图
private struct FormulaModeRow: View {
    let mode: FormulaProcessingMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(mode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(red: 0.5, green: 0.2, blue: 0.8))
                    .symbolEffect(.bounce, value: isSelected)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(selectionBackground)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private var selectionBackground: some View {
        Group {
            if isSelected {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2),
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.4),
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - 翻译语言行视图
private struct TranslationLanguageRow: View {
    let language: TranslationTargetLanguage
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(language.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if language == .auto {
                    Text("根据源文本自动选择目标语言")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("始终翻译成 \(language.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(red: 0.5, green: 0.2, blue: 0.8))
                    .symbolEffect(.bounce, value: isSelected)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(selectionBackground)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private var selectionBackground: some View {
        Group {
            if isSelected {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2),
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.4),
                                    Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            } else {
                Color.clear
            }
        }
    }
}
