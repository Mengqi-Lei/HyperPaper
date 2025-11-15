#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pix2Text OCR脚本包装器
用于从Swift应用调用Pix2Text进行OCR识别
"""

import sys
import json
import os
import warnings
from pathlib import Path
from contextlib import redirect_stderr, redirect_stdout
import io

# 重定向警告信息到stderr
warnings.filterwarnings('ignore')

try:
    from pix2text import Pix2Text
except ImportError:
    print(json.dumps({
        "error": "Pix2Text未安装，请运行: pip install pix2text"
    }), file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "用法: python pix2text_ocr.py <图像路径>"
        }), file=sys.stderr)
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    # 检查图像文件是否存在
    if not os.path.exists(image_path):
        print(json.dumps({
            "error": f"图像文件不存在: {image_path}"
        }), file=sys.stderr)
        sys.exit(1)
    
    try:
        # 创建一个StringIO来捕获stdout中的警告信息
        # 这样可以将Pix2Text的警告信息重定向，只保留JSON输出
        stdout_capture = io.StringIO()
        stderr_capture = io.StringIO()
        
        # 初始化Pix2Text（首次运行会下载模型）
        # 注意：Pix2Text可能会输出一些警告信息到stdout，我们需要捕获它们
        with redirect_stdout(stdout_capture), redirect_stderr(stderr_capture):
            p2t = Pix2Text()
            # 识别图像（返回Markdown格式，包含LaTeX公式）
            result = p2t.recognize(image_path)
        
        # 将警告信息输出到stderr（不影响JSON解析）
        captured_stdout = stdout_capture.getvalue()
        captured_stderr = stderr_capture.getvalue()
        if captured_stdout:
            print(captured_stdout, file=sys.stderr, end='')
        if captured_stderr:
            print(captured_stderr, file=sys.stderr, end='')
        
        # 输出结果到stdout（JSON格式，便于Swift解析）
        output = {
            "success": True,
            "result": result
        }
        print(json.dumps(output, ensure_ascii=False))
        
    except Exception as e:
        # 输出错误信息到stderr
        error_output = {
            "error": str(e),
            "type": type(e).__name__
        }
        print(json.dumps(error_output), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

