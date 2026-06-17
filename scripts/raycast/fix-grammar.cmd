@echo off
:: @raycast.schemaVersion 1
:: @raycast.title Fix Grammar
:: @raycast.mode compact
:: @raycast.packageName Writing
:: @raycast.description Fix grammar and typos in clipboard text using local Ollama (qwen3.5:9b)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\fix-grammar.ps1"
