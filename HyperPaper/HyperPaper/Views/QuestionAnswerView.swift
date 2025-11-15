//
// QuestionAnswerView.swift
// HyperPaper
//
// 问答功能视图
//

import SwiftUI

struct QuestionAnswerView: View {
    @StateObject private var apiService = QwenAPIService()
    
    @State private var selectedText: String = ""
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("HyperPaper - 问答功能验证")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // 选中文本区域
            VStack(alignment: .leading, spacing: 8) {
                Text("选中的论文内容（测试用）:")
                    .font(.headline)
                
                TextEditor(text: $selectedText)
                    .frame(height: 150)
                    .border(Color.gray.opacity(0.3), width: 1)
                    .padding(.horizontal)
                    .font(.system(.body, design: .monospaced))
            }
            .padding()
            
            // 问题输入
            VStack(alignment: .leading, spacing: 8) {
                Text("你的问题:")
                    .font(.headline)
                
                TextField("输入你的问题...", text: $question)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
            }
            .padding()
            
            // 提交按钮
            Button(action: submitQuestion) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "思考中..." : "提问")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isLoading || question.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading || question.isEmpty)
            .padding(.horizontal)
            
            // 回答显示
            VStack(alignment: .leading, spacing: 8) {
                Text("回答:")
                    .font(.headline)
                
                ScrollView {
                    if answer.isEmpty {
                        Text("等待回答...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .foregroundColor(.secondary)
                    } else {
                        MarkdownLaTeXView(content: answer)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(height: 200)
                .border(Color.gray.opacity(0.3), width: 1)
                .padding(.horizontal)
            }
            .padding()
            
            // 错误提示
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // 成功提示
            if showSuccess {
                Text("✓ 回答成功")
                    .foregroundColor(.green)
                    .padding()
            }
            
            Spacer()
        }
        .frame(minWidth: 600, minHeight: 700)
        .padding()
    }
    
    private func submitQuestion() {
        guard !question.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        showSuccess = false
        answer = ""
        
        Task {
            do {
                let response = try await apiService.askQuestion(
                    question: question,
                    context: selectedText.isEmpty ? nil : selectedText
                )
                
                await MainActor.run {
                    answer = response
                    isLoading = false
                    showSuccess = true
                    
                    // 3秒后隐藏成功提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSuccess = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "错误: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

