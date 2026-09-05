# FinanceTracker — macOS App Project

Это версия проекта с настоящим macOS App target, а не Swift Package executable.

## Как открыть

Откройте **FinanceTracker.xcodeproj** в Xcode. Package.swift здесь больше не нужен.

Bundle Identifier: `com.local.FinanceTracker`
Deployment target: macOS 26.0

Данные продолжают храниться в:
`~/Library/Application Support/FinanceTracker/finance.json`

Поэтому данные из предыдущего прототипа должны остаться доступными.
