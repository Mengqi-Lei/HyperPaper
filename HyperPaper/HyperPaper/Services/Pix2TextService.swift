//
// Pix2TextService.swift
// HyperPaper
//
// Pix2Text OCR服务 - 通过Process调用Python脚本
//

import Foundation
import AppKit

enum Pix2TextError: Error, LocalizedError {
    case pythonNotFound
    case scriptNotFound
    case processFailed(String)
    case invalidOutput
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "未找到Python环境，请确保已安装Python 3"
        case .scriptNotFound:
            return "未找到Pix2Text脚本"
        case .processFailed(let message):
            return "OCR处理失败: \(message)"
        case .invalidOutput:
            return "OCR输出格式无效"
        case .timeout:
            return "OCR处理超时"
        }
    }
}

/// Pix2Text OCR服务
class Pix2TextService {
    /// 进度更新回调
    typealias ProgressCallback = (Double) -> Void
    
    /// 单例实例
    static let shared = Pix2TextService()
    
    private init() {}
    
    /// 识别图像内容（返回Markdown格式，包含LaTeX公式）
    /// - Parameters:
    ///   - imagePath: 图像文件路径
    ///   - progressCallback: 进度回调（0.0-1.0）
    /// - Returns: 识别结果（Markdown格式）
    func recognizeImage(
        imagePath: String,
        progressCallback: @escaping ProgressCallback
    ) async throws -> String {
        // 1. 查找Python可执行文件
        guard let pythonPath = findPythonPath() else {
            throw Pix2TextError.pythonNotFound
        }
        
        // 2. 查找OCR脚本路径
        guard let scriptPath = findOCRScriptPath() else {
            throw Pix2TextError.scriptNotFound
        }
        
        // 3. 执行OCR（imagePath已经是文件路径）
        return try await executeOCR(
            pythonPath: pythonPath,
            scriptPath: scriptPath,
            imagePath: imagePath,
            progressCallback: progressCallback
        )
    }
    
    /// 识别NSImage内容
    func recognizeImage(
        image: NSImage,
        progressCallback: @escaping ProgressCallback
    ) async throws -> String {
        // 1. 保存图像到临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let imageURL = tempDir.appendingPathComponent("ocr_input_\(UUID().uuidString).png")
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw Pix2TextError.invalidOutput
        }
        
        try pngData.write(to: imageURL)
        defer {
            // 清理临时文件
            try? FileManager.default.removeItem(at: imageURL)
        }
        
        // 2. 调用识别
        return try await recognizeImage(
            imagePath: imageURL.path,
            progressCallback: progressCallback
        )
    }
    
    // MARK: - 私有方法
    
    /// 查找Python可执行文件路径（公开方法，用于环境检查）
    func findPythonPath() -> String? {
        // 优先查找app bundle内的Python
        if let bundlePath = Bundle.main.resourcePath {
            let bundlePython = "\(bundlePath)/Python3/python3"
            if FileManager.default.fileExists(atPath: bundlePython) {
                return bundlePython
            }
        }
        
        // 查找系统Python
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // 忽略错误，继续尝试常见路径
        }
        
        // 尝试常见路径
        let commonPaths = [
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    /// 查找OCR脚本路径
    private func findOCRScriptPath() -> String? {
        // 优先查找app bundle内的脚本
        if let bundlePath = Bundle.main.resourcePath {
            let bundleScript = "\(bundlePath)/Scripts/pix2text_ocr.py"
            if FileManager.default.fileExists(atPath: bundleScript) {
                return bundleScript
            }
        }
        
        // 查找项目目录中的脚本（开发时使用）
        // 方法1: 使用当前工作目录（可能不可靠）
        let currentDir = FileManager.default.currentDirectoryPath
        let projectScript1 = "\(currentDir)/Scripts/pix2text_ocr.py"
        if FileManager.default.fileExists(atPath: projectScript1) {
            return projectScript1
        }
        
        // 方法2: 从可执行文件路径推断项目根目录
        // 可执行文件通常在: DerivedData/.../Build/Products/Debug/HyperPaper.app/Contents/MacOS/HyperPaper
        // 项目根目录应该在: 从可执行文件向上查找，直到找到包含 Scripts 目录的路径
        if let executablePath = Bundle.main.executablePath {
            var searchPath = (executablePath as NSString).deletingLastPathComponent // Contents/MacOS
            searchPath = (searchPath as NSString).deletingLastPathComponent // Contents
            searchPath = (searchPath as NSString).deletingLastPathComponent // HyperPaper.app
            searchPath = (searchPath as NSString).deletingLastPathComponent // Debug
            searchPath = (searchPath as NSString).deletingLastPathComponent // Products
            searchPath = (searchPath as NSString).deletingLastPathComponent // Build
            
            // 从 Build 目录向上查找，直到找到包含 Scripts 目录的路径
            var currentSearchPath = searchPath
            for _ in 0..<10 { // 最多向上查找10层
                let scriptPath = "\(currentSearchPath)/Scripts/pix2text_ocr.py"
                if FileManager.default.fileExists(atPath: scriptPath) {
                    return scriptPath
                }
                
                // 检查是否到达根目录
                if currentSearchPath == "/" {
                    break
                }
                
                // 向上查找
                currentSearchPath = (currentSearchPath as NSString).deletingLastPathComponent
            }
        }
        
        // 方法3: 尝试查找相对于可执行文件的路径
        if let executablePath = Bundle.main.executablePath {
            let executableDir = (executablePath as NSString).deletingLastPathComponent
            let relativeScript = "\(executableDir)/../Scripts/pix2text_ocr.py"
            let resolvedScript = (relativeScript as NSString).standardizingPath
            if FileManager.default.fileExists(atPath: resolvedScript) {
                return resolvedScript
            }
        }
        
        // 方法4: 尝试查找相对于资源路径的上级目录
        if let bundlePath = Bundle.main.resourcePath {
            let parentDir = (bundlePath as NSString).deletingLastPathComponent
            let parentScript = "\(parentDir)/Scripts/pix2text_ocr.py"
            if FileManager.default.fileExists(atPath: parentScript) {
                return parentScript
            }
        }
        
        // 方法5: 尝试使用环境变量或硬编码路径（开发时使用）
        // 检查常见的项目路径
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let commonProjectPaths = [
            "\(homeDir)/Projects/HyperPaper/Scripts/pix2text_ocr.py",
            "/Volumes/T7Shield/Projects/HyperPaper/Scripts/pix2text_ocr.py",
            "\(FileManager.default.currentDirectoryPath)/Scripts/pix2text_ocr.py"
        ]
        
        for projectPath in commonProjectPaths {
            if FileManager.default.fileExists(atPath: projectPath) {
                return projectPath
            }
        }
        
        return nil
    }
    
    /// 执行OCR处理
    private func executeOCR(
        pythonPath: String,
        scriptPath: String,
        imagePath: String,
        progressCallback: @escaping ProgressCallback
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath, imagePath]
            
            // 创建管道捕获输出
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            // 进度解析状态（使用Actor保护并发访问）
            let progressState = ProgressState()
            
            // 错误信息收集器（用于收集stderr中的错误信息）
            let errorData = ResultData()
            
            // 模拟进度定时器
            // 使用nonisolated(unsafe)来避免Sendable检查（Timer在实际使用中是线程安全的）
            let simulatedProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                Task { @MainActor in
                    if await !progressState.isParsed {
                        let currentProgress = await progressState.simulatedProgress
                        let newProgress = min(currentProgress + 0.02, 1.0)
                        await progressState.setSimulatedProgress(newProgress)
                        progressCallback(newProgress)
                        
                        if newProgress >= 1.0 {
                            timer.invalidate()
                        }
                    } else {
                        timer.invalidate()
                    }
                }
            }
            
            // 异步读取stderr（进度输出和错误信息）
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                
                // 收集所有stderr数据（用于错误诊断）
                Task { @MainActor in
                    await errorData.append(data)
                }
                
                if let output = String(data: data, encoding: .utf8) {
                    // 尝试解析真实进度
                    if let progress = self.parseProgress(from: output) {
                        Task { @MainActor in
                            await progressState.setParsed(true)
                            simulatedProgressTimer.invalidate()
                            progressCallback(progress)
                        }
                    }
                }
            }
            
            // 异步读取stdout（结果输出）
            let resultData = ResultData()
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                Task { @MainActor in
                    await resultData.append(data)
                }
            }
            
            // 处理完成回调
            process.terminationHandler = { process in
                print("   🔍 [OCR调试] 进程终止，退出码: \(process.terminationStatus)")
                simulatedProgressTimer.invalidate()
                
                // 关闭readabilityHandler，确保所有数据都已读取
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                
                Task {
                    // 读取所有剩余数据（包括stdout和stderr）
                    let finalStdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let finalStderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    print("   🔍 [OCR调试] 读取剩余数据 - stdout: \(finalStdoutData.count) 字节, stderr: \(finalStderrData.count) 字节")
                    
                    // 合并所有数据（包括已收集的和剩余的）
                    let allStdoutData = await resultData.getData() + finalStdoutData
                    let allStderrData = await errorData.getData() + finalStderrData
                    
                    print("   🔍 [OCR调试] 合并后数据 - stdout: \(allStdoutData.count) 字节, stderr: \(allStderrData.count) 字节")
                    
                    if process.terminationStatus != 0 {
                        // 进程失败，尝试从stdout和stderr中提取错误信息
                        var errorMessage = "OCR进程执行失败（退出码: \(process.terminationStatus)）"
                        
                        // 首先尝试从stdout解析JSON错误
                        if let stdoutString = String(data: allStdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !stdoutString.isEmpty {
                            print("   🔍 [OCR调试] 进程失败，stdout内容: \(stdoutString.prefix(200))")
                            
                            if let jsonData = stdoutString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                if let error = json["error"] as? String {
                                    errorMessage = error
                                } else if let error = json["error"] as? [String: Any],
                                          let errorStr = error["error"] as? String {
                                    errorMessage = errorStr
                                }
                            }
                        }
                        
                        // 如果stdout没有错误信息，尝试从stderr解析
                        if errorMessage.contains("退出码") {
                            if let stderrString = String(data: allStderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !stderrString.isEmpty {
                                print("   🔍 [OCR调试] 进程失败，stderr内容: \(stderrString.prefix(200))")
                                
                                // 尝试解析JSON格式的错误信息
                                if let jsonData = stderrString.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                    if let error = json["error"] as? String {
                                        errorMessage = error
                                    }
                                } else {
                                    // 如果不是JSON，直接使用stderr内容（去除tqdm进度条输出）
                                    let cleanedStderr = stderrString
                                        .components(separatedBy: "\n")
                                        .filter { !$0.contains("%|") && !$0.contains("it/s") && !$0.isEmpty }
                                        .joined(separator: " ")
                                    
                                    if !cleanedStderr.isEmpty {
                                        errorMessage = cleanedStderr
                                    }
                                }
                            }
                        }
                        
                        print("   ❌ [OCR调试] OCR进程失败，错误信息: \(errorMessage)")
                        continuation.resume(throwing: Pix2TextError.processFailed(errorMessage))
                        return
                    }
                    
                    // 进程成功，解析结果
                    print("   🔍 [OCR调试] 进程成功，开始解析结果...")
                    guard let resultString = String(data: allStdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !resultString.isEmpty else {
                        print("   ❌ [OCR调试] stdout为空或无法解析")
                        if let debugString = String(data: allStdoutData, encoding: .utf8) {
                            print("   🔍 [OCR调试] stdout原始内容: \(debugString)")
                        }
                        continuation.resume(throwing: Pix2TextError.invalidOutput)
                        return
                    }
                    
                    print("   🔍 [OCR调试] stdout内容（前200字符）: \(resultString.prefix(200))")
                    print("   🔍 [OCR调试] stdout完整长度: \(resultString.count) 字符")
                    
                    // 尝试提取JSON部分（如果stdout包含警告信息）
                    let jsonString = self.extractJSON(from: resultString)
                    print("   🔍 [OCR调试] 提取的JSON长度: \(jsonString.count) 字符")
                    
                    // 解析JSON输出
                    guard let jsonData = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                        print("   ❌ [OCR调试] 无法解析JSON输出")
                        print("   🔍 [OCR调试] 尝试解析的JSON内容: \(jsonString.prefix(500))")
                        continuation.resume(throwing: Pix2TextError.invalidOutput)
                        return
                    }
                    
                    // 检查是否有错误字段
                    if let error = json["error"] as? String {
                        print("   ❌ [OCR调试] JSON中包含错误: \(error)")
                        continuation.resume(throwing: Pix2TextError.processFailed(error))
                        return
                    }
                    
                    // 检查success字段
                    guard let success = json["success"] as? Bool, success == true else {
                        let errorMsg = (json["error"] as? String) ?? "OCR处理失败（success=false）"
                        print("   ❌ [OCR调试] success=false: \(errorMsg)")
                        continuation.resume(throwing: Pix2TextError.processFailed(errorMsg))
                        return
                    }
                    
                    // 获取结果
                    guard let result = json["result"] as? String else {
                        print("   ❌ [OCR调试] JSON中缺少result字段")
                        continuation.resume(throwing: Pix2TextError.invalidOutput)
                        return
                    }
                    
                    // 确保进度为100%
                    progressCallback(1.0)
                    print("   ✅ [OCR调试] OCR处理成功，结果长度: \(result.count)")
                    continuation.resume(returning: result)
                }
            }
            
            // 启动进程
            print("   🔍 [OCR调试] 准备启动OCR进程...")
            print("   🔍 [OCR调试] Python路径: \(pythonPath)")
            print("   🔍 [OCR调试] 脚本路径: \(scriptPath)")
            print("   🔍 [OCR调试] 图像路径: \(imagePath)")
            do {
                try process.run()
                print("   ✅ [OCR调试] OCR进程已启动")
            } catch {
                print("   ❌ [OCR调试] OCR进程启动失败: \(error.localizedDescription)")
                simulatedProgressTimer.invalidate()
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// 从tqdm输出中解析进度
    /// tqdm格式示例: "50%|████████| 1/2 [00:03<00:03]"
    nonisolated func parseProgress(from output: String) -> Double? {
        // 方法1: 匹配百分比 "50%"
        let percentPattern = #"(\d+)%"#
        if let match = output.range(of: percentPattern, options: .regularExpression) {
            let matchedString = String(output[match])
            if let percent = Int(matchedString.replacingOccurrences(of: "%", with: "")) {
                return Double(percent) / 100.0
            }
        }
        
        // 方法2: 匹配分数 "1/2"
        let fractionPattern = #"(\d+)/(\d+)"#
        if let match = output.range(of: fractionPattern, options: .regularExpression) {
            let matchedString = String(output[match])
            let parts = matchedString.split(separator: "/")
            if parts.count == 2,
               let current = Int(parts[0]),
               let total = Int(parts[1]),
               total > 0 {
                return Double(current) / Double(total)
            }
        }
        
        return nil
    }
    
    /// 从可能包含警告信息的stdout中提取JSON部分
    /// 策略：查找最后一个完整的JSON对象（以{开头，以}结尾）
    nonisolated private func extractJSON(from output: String) -> String {
        // 方法1: 尝试直接解析整个字符串（如果已经是纯JSON）
        if let _ = try? JSONSerialization.jsonObject(with: output.data(using: .utf8) ?? Data()) {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 方法2: 查找最后一个 { 和对应的 }
        var braceCount = 0
        var jsonStartIndex: String.Index?
        var jsonEndIndex: String.Index?
        
        // 从后往前查找最后一个 {
        if let lastOpenBrace = output.lastIndex(of: "{") {
            jsonStartIndex = lastOpenBrace
            braceCount = 1
            
            // 从 { 开始，向前查找匹配的 }
            var currentIndex = output.index(after: lastOpenBrace)
            while currentIndex < output.endIndex {
                let char = output[currentIndex]
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        jsonEndIndex = output.index(after: currentIndex)
                        break
                    }
                }
                currentIndex = output.index(after: currentIndex)
            }
            
            // 如果找到了完整的JSON对象
            if let start = jsonStartIndex, let end = jsonEndIndex {
                let jsonCandidate = String(output[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                // 验证是否是有效的JSON
                if let _ = try? JSONSerialization.jsonObject(with: jsonCandidate.data(using: .utf8) ?? Data()) {
                    return jsonCandidate
                }
            }
        }
        
        // 方法3: 按行查找，找到包含JSON的行
        let lines = output.components(separatedBy: .newlines)
        for line in lines.reversed() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("{") && trimmedLine.hasSuffix("}") {
                if let _ = try? JSONSerialization.jsonObject(with: trimmedLine.data(using: .utf8) ?? Data()) {
                    return trimmedLine
                }
            }
        }
        
        // 如果都失败了，返回原始字符串（让上层处理错误）
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 辅助类（用于线程安全的状态管理）

private actor ProgressState {
    var isParsed: Bool = false
    var simulatedProgress: Double = 0.0
    
    func setParsed(_ value: Bool) {
        isParsed = value
    }
    
    func setSimulatedProgress(_ value: Double) {
        simulatedProgress = value
    }
}

private actor ResultData {
    private var data: Data = Data()
    
    func append(_ newData: Data) {
        data.append(newData)
    }
    
    func getData() -> Data {
        return data
    }
}

