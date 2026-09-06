# Сборка FinanceTracker.app

Запусти из корня проекта:

```bash
./build-app.sh
```

или двойным кликом по `build-app.command` (если Gatekeeper разрешил запуск).

Готовые файлы появятся в:

- `dist/FinanceTracker.app`
- `dist/FinanceTracker.zip`

## Иконка

Скрипт v5.2 дополнительно гарантирует, что Finder увидит иконку приложения:

1. копирует `FinanceTracker/AppIcon.icns` в `FinanceTracker.app/Contents/Resources/AppIcon.icns`;
2. явно записывает `CFBundleIconFile = AppIcon` и `CFBundleIconName = AppIcon` в `Contents/Info.plist`;
3. только после этого подписывает готовый bundle.

Поэтому иконка должна отображаться не только в Dock во время работы, но и у самого `.app` в Finder.
