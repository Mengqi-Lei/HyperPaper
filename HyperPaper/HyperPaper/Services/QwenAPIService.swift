//
// QwenAPIService.swift
// HyperPaper
//
// Qwen API服务封装
//

import Foundation
import Combine
import AppKit

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的API响应"
        case .networkError(let error):
            let nsError = error as NSError
            var description = "网络错误: \(error.localizedDescription)"
            
            // 提供更友好的错误信息
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    description = "网络错误: 请检查网络连接"
                case NSURLErrorTimedOut:
                    description = "网络错误: 请求超时，请稍后重试"
                case NSURLErrorCannotFindHost:
                    description = "网络错误: 无法连接到服务器，请检查网络设置"
                case NSURLErrorCannotConnectToHost:
                    description = "网络错误: 无法连接到服务器"
                case NSURLErrorNetworkConnectionLost:
                    description = "网络错误: 网络连接已断开"
                default:
                    description = "网络错误: \(error.localizedDescription)"
                }
            }
            
            return description
        case .decodingError(let error):
            return "解析错误: \(error.localizedDescription)"
        case .apiError(let message):
            return "API错误: \(message)"
        }
    }
}

class QwenAPIService: ObservableObject {
    private let apiKey: String
    private let baseURL: String
    
    init(apiKey: String = APIConfig.apiKey, 
         baseURL: String = APIConfig.baseURL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    /// 调用Qwen API进行问答
    /// - Parameters:
    ///   - question: 用户问题
    ///   - context: 上下文文本（选中的论文内容）
    /// - Returns: API返回的回答
    func askQuestion(question: String, context: String?) async throws -> String {
        var messages: [Message] = []
        
        // 系统提示词
        messages.append(Message(
            role: "system",
            content: """
            你是一个专业的学术论文阅读助手。用户选中了一段论文内容，并提出了问题。
            
            请基于选中的论文内容回答问题。如果问题涉及的内容在选中文本中找不到，请明确说明。
            回答要准确、简洁、专业。
            """
        ))
        
        // 如果有上下文，添加上下文
        if let context = context, !context.isEmpty {
            messages.append(Message(
                role: "user",
                content: """
                论文内容：
                \(context)
                
                用户问题：
                \(question)
                """
            ))
        } else {
            // 如果没有上下文，直接提问
            messages.append(Message(
                role: "user",
                content: question
            ))
        }
        
        let request = ChatRequest(messages: messages)
        
        return try await performRequest(request: request)
    }
    
    /// 调用Qwen API进行翻译
    /// - Parameters:
    ///   - text: 要翻译的文本
    ///   - targetLanguage: 目标语言（"中文" 或 "English"）
    /// - Returns: 翻译后的文本
    func translate(text: String, targetLanguage: String) async throws -> String {
        var messages: [Message] = []
        
        // 系统提示词
        messages.append(Message(
            role: "system",
            content: """
            你是一个专业的翻译助手。请将用户提供的文本翻译成目标语言。
            
            翻译要求：
            1. 保持原文的语义和语气
            2. 专业术语保持准确
            3. 如果是学术论文内容，保持学术严谨性
            4. 只返回翻译结果，不要添加任何解释或说明
            """
        ))
        
        // 添加翻译请求
        messages.append(Message(
            role: "user",
            content: """
            请将以下文本翻译成\(targetLanguage)：
            
            \(text)
            """
        ))
        
        let request = ChatRequest(messages: messages)
        
        return try await performRequest(request: request)
    }
    
    /// 检测文本语言（简单检测）
    /// - Parameter text: 待检测的文本
    /// - Returns: 语言名称
    private func detectLanguage(text: String) -> String {
        // 简单的语言检测：检查是否包含中文字符
        let chinesePattern = "[\\u4e00-\\u9fa5]"
        if text.range(of: chinesePattern, options: .regularExpression) != nil {
            return "中文"
        }
        return "English"
    }
    
    /// 执行API请求
    private func performRequest(request: ChatRequest) async throws -> String {
        // 尝试不同的URL格式
        var url: URL?
        let urlStrings = [
            baseURL,
            "https://api.probex.top/v1/chat/completions",
            "https://api.probex.top/v1",
        ]
        
        for urlString in urlStrings {
            if let testURL = URL(string: urlString) {
                url = testURL
                break
            }
        }
        
        guard let finalURL = url else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        
        // 添加调试信息
        let encoder = JSONEncoder()
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw APIError.decodingError(error)
        }
        
        do {
            // 配置URLSession以允许网络访问
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            config.waitsForConnectivity = true
            config.allowsCellularAccess = true
            
            let session = URLSession(configuration: config)
            
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // 检查HTTP状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                // 尝试解析错误信息
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    let errorMessage = errorResponse.error?.message ?? "Unknown error"
                    throw APIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw APIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
                }
            }
            
            // 解析响应
            let decoder = JSONDecoder()
            let chatResponse = try decoder.decode(ChatResponse.self, from: data)
            
            guard let answer = chatResponse.choices.first?.message.content else {
                throw APIError.invalidResponse
            }
            
            return answer
            
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    /// 测试API连接
    func testConnection() async throws -> Bool {
        let testMessage = Message(role: "user", content: "你好，请回复'连接成功'")
        let request = ChatRequest(messages: [testMessage], max_tokens: 10)
        
        let response = try await performRequest(request: request)
        return response.contains("成功") || response.contains("连接") || response.contains("你好")
    }
    
    /// 使用 Vision API 处理图像（识别、翻译、问答）
    /// - Parameters:
    ///   - imageBase64: Base64 编码的图像数据（格式：data:image/png;base64,...）
    ///   - prompt: 提示词
    ///   - model: 模型名称（默认使用 Qwen-VL-Max）
    /// - Returns: API返回的结果
    func processImageWithVision(
        imageBase64: String,
        prompt: String,
        model: String = "Qwen-VL-Max"
    ) async throws -> String {
        // 构建 Vision API 消息格式
        let imageURL = VisionMessage.ContentItem.ImageURL(
            url: imageBase64.starts(with: "data:") ? imageBase64 : "data:image/png;base64,\(imageBase64)"
        )
        
        let content: [VisionMessage.ContentItem] = [
            .text(prompt),
            .imageURL(imageURL)
        ]
        
        let visionMessage = VisionMessage(role: "user", content: content)
        
        // 将 VisionMessage 转换为 JSON
        let encoder = JSONEncoder()
        let messageData = try encoder.encode(visionMessage)
        let messageDict = try JSONSerialization.jsonObject(with: messageData) as? [String: Any]
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [messageDict as Any],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        // 执行请求
        return try await performVisionRequest(requestBody: requestBody)
    }
    
    /// 执行 Vision API 请求
    private func performVisionRequest(requestBody: [String: Any]) async throws -> String {
        // 尝试不同的URL格式
        var url: URL?
        let urlStrings = [
            baseURL,
            "https://api.probex.top/v1/chat/completions",
            "https://api.probex.top/v1",
        ]
        
        for urlString in urlStrings {
            if let testURL = URL(string: urlString) {
                url = testURL
                break
            }
        }
        
        guard let finalURL = url else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60 // Vision API 可能需要更长时间
        
        // 将请求体转换为 JSON
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 120
            config.waitsForConnectivity = true
            config.allowsCellularAccess = true
            
            let session = URLSession(configuration: config)
            
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // 检查HTTP状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                // 尝试解析错误信息
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    let errorMessage = errorResponse.error?.message ?? "Unknown error"
                    throw APIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw APIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
                }
            }
            
            // 解析响应
            let decoder = JSONDecoder()
            let chatResponse = try decoder.decode(ChatResponse.self, from: data)
            
            guard let answer = chatResponse.choices.first?.message.content else {
                throw APIError.invalidResponse
            }
            
            return answer
            
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    /// 使用 Vision API 识别并翻译图像内容
    /// - Parameters:
    ///   - imageBase64: Base64 编码的图像数据
    ///   - targetLanguage: 目标语言（"中文" 或 "English"）
    ///   - model: 模型名称（默认使用 Qwen-VL-Max）
    /// - Returns: 翻译后的文本（包含LaTeX公式）
    func translateImage(
        imageBase64: String,
        targetLanguage: String,
        model: String = "Qwen-VL-Max"
    ) async throws -> String {
        let prompt = """
        请识别这张图片中的内容，并翻译成\(targetLanguage)。
        
        要求：
        1. 如果包含数学公式，请转换为LaTeX代码（使用$...$格式包裹）
        2. 保持原文的格式和结构
        3. 只返回翻译结果，不要添加任何解释或说明
        """
        
        return try await processImageWithVision(
            imageBase64: imageBase64,
            prompt: prompt,
            model: model
        )
    }
    
    /// 使用 Vision API 对图像内容进行问答
    /// - Parameters:
    ///   - imageBase64: Base64 编码的图像数据
    ///   - question: 用户问题
    ///   - model: 模型名称（默认使用 Qwen-VL-Max）
    /// - Returns: API返回的回答
    func askQuestionAboutImage(
        imageBase64: String,
        question: String,
        model: String = "Qwen-VL-Max"
    ) async throws -> String {
        let prompt = """
        请识别这张图片中的内容。如果包含数学公式，请转换为LaTeX代码（使用$...$格式包裹）。
        
        然后基于识别的内容回答问题：
        \(question)
        
        要求：
        1. 回答要准确、简洁、专业
        2. 如果问题涉及的内容在图片中找不到，请明确说明
        """
        
        return try await processImageWithVision(
            imageBase64: imageBase64,
            prompt: prompt,
            model: model
        )
    }
    
    /// 使用 Vision API 识别图像内容（不翻译，仅识别）
    /// - Parameters:
    ///   - imageBase64: Base64 编码的图像数据
    ///   - model: 模型名称（默认使用 Qwen-VL-Max）
    /// - Returns: 识别结果（文本+LaTeX公式）
    func recognizeImage(
        imageBase64: String,
        model: String = "Qwen-VL-Max"
    ) async throws -> String {
        let prompt = """
        请识别这张图片中的内容。
        
        要求：
        1. 如果包含数学公式，请转换为LaTeX代码（使用$...$格式包裹）
        2. 保持原文的格式和结构
        3. 只返回识别结果，不要添加任何解释或说明
        """
        
        return try await processImageWithVision(
            imageBase64: imageBase64,
            prompt: prompt,
            model: model
        )
    }
    
}

