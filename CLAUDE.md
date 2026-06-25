# CLAUDE.md — kozuchi

## Project Overview

**kozuchi（小槌）** — Flutter 製の家計簿・支出管理 RPG アプリ。支出を打ち負かすべき敵として可視化し、デイリークエスト・実績・守護神エフェクトなどの RPG 要素でモチベーションを高める。

## Tech Stack

- **Framework**: Flutter (Dart SDK ^3.6.2)
- **State Management**: Riverpod (via takamagahara_ui)
- **Backend**: Supabase (`supabase_flutter: ^2.8.3`)
- **Charts**: fl_chart (`fl_chart: ^0.70.2`)
- **Local Storage**: shared_preferences
- **Deep Links**: app_links (`app_links: ^6.3.3`)
- **Image**: image_picker
- **Env**: flutter_dotenv (`flutter_dotenv: ^5.2.1`)
- **Monorepo Packages**: takamagahara_ui (`../../packages/`)
- **Current Version**: 1.0.4+31

## Project Structure

```
lib/
  main.dart              # App entry point
  core/                  # Core infrastructure (deep_link, cloud_sync)
  domain/                # Domain models
  features/              # Feature modules
    achievements/        # 実績システム
    daily_quest/         # デイリークエスト
    effects/             # 守護神エフェクト
    shared/              # 共有機能 (expenditure_repository)
    transaction_history/ # 取引履歴
    trial_quest/         # 試練クエスト
    tsundoku/            # 積読連携
    weekly_report/       # 週次レポート
  screens/               # Top-level screens
```

## Common Commands

```bash
# Get dependencies
flutter pub get

# Run app
flutter run

# Analyze (warnings = CI failure!)
flutter analyze --no-fatal-infos

# Run tests
flutter test

# Build Android App Bundle
flutter build appbundle --release
```

## ⛩️ Push Gate

**Pre-push hook** at `.git/hooks/pre-push` runs `flutter analyze --no-fatal-infos` before every push.
- Warnings (not just errors) cause exit code 1 = push REJECTED.
- This mirrors the CI check exactly — prevents CI failures from missed warnings.
- Info-level issues are suppressed by `--no-fatal-infos` and won't block.

## 🚀 Pre-Deploy Check

Before deploying, run the full CI simulation:
```bash
bash scripts/pre-deploy-check.sh
```
This runs: `flutter pub get` → `flutter analyze --no-fatal-infos` → `flutter test`
All must pass before deployment.

## CI/CD

- **CI**: `.github/workflows/flutter-ci.yml` — runs on push/PR to main
  - Setup monorepo packages → flutter pub get → analyze → test
- **Deploy**: `.github/workflows/deploy.yml` — triggers on `pubspec.yaml` change on main
  - Builds AAB → deploys to Google Play via fastlane

## Pitfalls

- **analyze warning = CI failure**: `--no-fatal-infos` only suppresses `info`, not `warning`. Always run `flutter analyze --no-fatal-infos` before pushing.
- **Monorepo packages**: CI clones packages from `shorie9293/takamagahara` repo. Locally they're at `../../packages/`.
- **flutter_dotenv**: `.env` must be present at build time. CI generates it from GitHub Secrets.
