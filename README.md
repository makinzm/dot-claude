# .claude — Claude Code 個人設定

Claude Code の個人設定・エージェント・スキル・フックの管理リポジトリ。

---

## ディレクトリ構成

```
.claude/
├── CLAUDE.md           # Claude へのグローバル指示（ワークフロー・原則）
├── settings.json       # 権限・フック・ステータスライン設定
├── agents/             # サブエージェント定義（単一の情報源）
│   ├── architect.md
│   ├── developer.md
│   ├── po.md
│   ├── da-reviewer.md
│   └── tdd-pr-workflow.md
├── skills/             # ユーザー起動スキル（agents/ を参照する薄いラッパー）
│   ├── architect/
│   ├── developer/
│   ├── po/
│   ├── da-review/
│   └── writing-code/
├── scripts/            # フック用シェルスクリプト
│   ├── pre-task-estimate.sh   # UserPromptSubmit: 難易度推定
│   ├── loop-detection.sh      # PreToolUse: ループ検出
│   ├── tdd-guard.sh           # PreToolUse: TDD強制
│   ├── post-task-analysis.sh  # Stop: セッション分析
│   └── notify.sh              # 完了通知
└── external/           # 外部ツール（git submodule）
    ├── claude-statusline/      # ステータスライン表示
    └── claude-code-monitoring-guide/  # OTel監視スタック
```

---

## ユーザーが Claude に指示したときの流れ

```
ユーザー入力
    │
    ▼
[UserPromptSubmit フック]
    • 難易度自動推定 (S/M/L/XL)
    • ループカウンター・TDDマーカーをリセット
    • L/XL の場合: tasks/ に状態ファイル作成
    • XL の場合: サブエージェント委譲を推奨するメッセージを注入
    │
    ▼
Claude が作業開始
    │
    ├─ [PreToolUse フック — 全ツール]  ←  ループ検出
    │       同一 Bash コマンド 3回以上 → ブロック & ユーザーへ確認促す
    │       40 回以上のツール呼び出し → ブロック & 進捗報告を促す
    │
    ├─ [PreToolUse フック — Write/Edit]  ←  TDD ガード
    │       実装ファイルへの書き込み検出
    │       → テスト未実行なら ブロック（まずテストを書いて失敗させること）
    │       → テスト済みなら 通過
    │
    ├─ [Bash でテスト実行]
    │       cargo test / pytest / npm test / go test など
    │       → TDD マーカーファイルを作成（ガード解除）
    │
    └─ [Stop フック]
            完了通知 (notify.sh)
            非同期でセッション分析レポートを生成 → tasks/ に保存
```

### タスクサイズと推奨フロー

| サイズ | 目安 | 推奨フロー |
|---|---|---|
| **S** | 1ステップ、明確な作業 | メインClaude が直接対応 |
| **M** | 2〜3ステップ、技術的に単純 | メインClaude が直接対応 |
| **L** | 複数ファイル・システム横断 | メインClaude + 必要に応じてサブエージェント |
| **XL** | アーキテクチャ変更・大規模実装 | サブエージェント委譲（コンテキスト汚染防止） |

---

## エージェントとスキルの関係

**二重管理なし**: エージェントの役割定義は `agents/*.md` のみ。スキルはそれを呼び出す薄いラッパー。

```
/architect  (スキル)
    └─→  Agent(subagent_type="architect", ...)  → agents/architect.md の定義で動作

/da-review  (スキル)
    └─→  Agent(subagent_type="da-reviewer", ...) → agents/da-reviewer.md の定義で動作
```

### 典型的なワークフロー

```
1. /po       → 要件整理・ユーザーストーリー作成
       ↓
2. /architect → 設計・ADR 作成
       ↓
3. /developer → TDD 実装（RED → GREEN → REFACTOR）
       ↓
4. /da-review → 批判的レビュー（指摘 → 修正 → 再レビュー）
       ↓
5. PR 作成
```

---

## サウンド通知の設定

タスク完了時・承認/通知イベント時に音が鳴る。以下の環境変数で制御できる。

| 環境変数 | デフォルト | 説明 |
|---|---|---|
| `CLAUDE_SOUND` | `1` | `1` = 音あり、`0` = 無音 |
| `CLAUDE_SOUND_STOP_NAME` | `Glass` | タスク完了時の音（Mac システムサウンド名） |
| `CLAUDE_SOUND_NOTIFY_NAME` | `Ping` | 通知・承認イベント時の音 |

**Mac システムサウンド一覧**（`/System/Library/Sounds/` にある）:
`Glass` `Ping` `Purr` `Tink` `Hero` `Sosumi` `Basso` `Blow` `Bottle` `Frog`

**設定例** (`~/.zshrc` に追記):

```bash
# Claude Code サウンドを無効化
export CLAUDE_SOUND=0

# タスク完了はHeroサウンド、通知はTinkサウンドにする
export CLAUDE_SOUND_STOP_NAME=Hero
export CLAUDE_SOUND_NOTIFY_NAME=Tink

# カスタム音声ファイルを使う（フルパス指定可）
export CLAUDE_SOUND_STOP_NAME=/path/to/custom.aiff
```

> `settings.json` の `env` セクションにデフォルト値が設定されている。`~/.zshrc` で上書きすると Claude Code セッションに引き継がれる。

**Linux の場合**: `paplay` または `aplay` で `/usr/share/sounds/` 以下のシステムサウンドが使われる。`CLAUDE_SOUND_STOP_NAME` にフルパスを指定してカスタム音声ファイルも使用可能。

---

## 監視スタック (OTel)

セッション開始時に Docker Compose が自動起動する。

| ツール | URL | 用途 |
|---|---|---|
| Grafana | http://localhost:13000 | トークン使用量・コスト可視化 |
| Prometheus | http://localhost:9090 | メトリクス蓄積 |
| Loki | http://localhost:3100 | 会話ログ・イベント蓄積 |

ステータスライン: `✍️ X% $Y.YY | ブランチ | 経過時間 | レートリミット`

---

## 参考

- [Claude Code ドキュメント](https://code.claude.com/docs/ja/overview)
- [Hooks リファレンス](https://code.claude.com/docs/ja/hooks)
- [Sub-agents リファレンス](https://code.claude.com/docs/ja/sub-agents)
