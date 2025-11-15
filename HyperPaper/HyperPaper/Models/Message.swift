//
// Message.swift
// HyperPaper
//
// API消息模型
//

import Foundation

// 标准文本消息
struct Message: Codable {
    let role: String
    let content: String
}

// Vision API 支持：多模态消息内容
struct VisionMessage: Codable {
    let role: String
    let content: [ContentItem]
    
    enum ContentItem: Codable {
        case text(String)
        case imageURL(ImageURL)
        
        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }
        
        struct ImageURL: Codable {
            let url: String
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "text":
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case "image_url":
                let imageURL = try container.decode(ImageURL.self, forKey: .imageURL)
                self = .imageURL(imageURL)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .imageURL(let imageURL):
                try container.encode("image_url", forKey: .type)
                try container.encode(imageURL, forKey: .imageURL)
            }
        }
    }
}

struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int
    let enable_thinking: Bool? // 可选参数：关闭thinking模式以提升响应速度
    
    init(model: String = APIConfig.model, 
         messages: [Message], 
         temperature: Double = 0.7, 
         max_tokens: Int = 2000,
         enable_thinking: Bool? = false) { // 默认关闭thinking模式
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.enable_thinking = enable_thinking
    }
}

struct ChatResponse: Codable {
    let id: String?
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        let finish_reason: String?
    }
}

struct APIErrorResponse: Codable {
    let error: ErrorDetail?
    
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}

