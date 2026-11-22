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
│   ├── tdd-pr-workflow.md
│   └── dod-*.md        # DoD項目ごとの自動生成レビューAgent（後述「DoD Factory」）
├── skills/             # ユーザー起動スキル（agents/ を参照する薄いラッパー）
│   ├── architect/
│   ├── developer/
│   ├── po/
│   ├── da-review/
│   ├── writing-code/
│   └── dod-*/          # DoD項目ごとの自動生成Skill（後述「DoD Factory」）
├── dod/
│   └── deliverables-dod.json  # DoD項目の正本（id/title/check）。Skill/Agentはここから生成される
├── scripts/            # フック用シェルスクリプト・DoD Factory生成器
│   ├── pre-task-estimate.sh   # UserPromptSubmit: 難易度推定
│   ├── loop-detection.sh      # PreToolUse: ループ検出
│   ├── tdd-guard.sh           # PreToolUse: TDD強制
│   ├── post-task-analysis.sh  # Stop: セッション分析
│   ├── notify.sh               # 完了通知
│   ├── sync-dod-skills.py      # dod/deliverables-dod.json → skills/dod-*/, agents/dod-*.md を生成
│   └── test_sync_dod_skills.py # 上記のテスト
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

## DoD Factory（成果物のDoD項目ごとにSkill/Agentを自動生成する）

このリポジトリ自体が「DoD項目の数だけレビューAgent/Skillを作る工場」として動く。正本は `dod/deliverables-dod.json` で、ここに書かれたDoD項目1件につき、生成器が **Skill 1つ + Agent 1つ** を機械的に材料化する。項目を増やせば増え、減らせば消える。

```
dod/deliverables-dod.json  (id/title/check の配列。正本)
        │
        ▼  python3 scripts/sync-dod-skills.py
        │
        ├─→ skills/dod-<id>/SKILL.md   (軽量: 成果物を書く/直す作業中にコンテキストへ読み込む観点)
        └─→ agents/dod-<id>.md         (重量: Task ツールで個別起動する独立レビュワー)
```

Skill と Agent は役割が違う。Skill はこれから書く・直す成果物に観点を思い出させるための軽い参照。Agent は書き終えた成果物を**独立したコンテキストで**判定させるためのサブエージェントで、`Task` ツールに `subagent_type: "dod-<id>"` を渡すと起動できる。例えば記事を書き終えたら、現在の5項目それぞれに対応する `dod-ambiguous-acronym-confirm` / `dod-adr-structure` / `dod-rubric-completeness` / `dod-no-edit-timeline-narration` / `dod-source-accuracy` を並列で起動し、各々からPASS/FAILと具体的な指摘を受け取る、という使い方をする。

### DoD項目を増やす/減らす手順

1. `dod/deliverables-dod.json` の `items` 配列を編集する(`{"id": "...", "title": "...", "check": "..."}` を追加・削除)。
2. `uv run --with pytest pytest scripts/test_sync_dod_skills.py` でテストが通ることを確認する(先にテストを直すべき変更ならTDDに従う)。
3. `python3 scripts/sync-dod-skills.py` を実行する。出力に `Skills written` と `Agents written` の件数がJSONの項目数と一致していることを確認する(一致しなければ非0終了する)。
4. `git add` → commit → push。このリポジトリをチェックアウトしている側(例: このdotfiles自体)は `chezmoi apply` で反映する。

### 他プロジェクトからSkillだけを取り込む(apm経由の横断配布)

Skillは [microsoft/apm](https://github.com/microsoft/apm) で配布可能な形になっている。消費側リポジトリの `apm.yml` に以下のように書いて `apm install` すると、必要な項目だけ `.claude/skills/dod-<id>/` に配置される(実例: `makinzm/qiita-dir` の `apm.yml`)。

```yaml
dependencies:
  apm:
    - git: makinzm/dot-claude
      ref: <commit-or-tag>   # pin推奨。省略するとapmが "unpinned" 警告を出す
      skills:
        - dod-adr-structure
        - dod-ambiguous-acronym-confirm
        - dod-no-edit-timeline-narration
        - dod-rubric-completeness
        - dod-source-accuracy
```

Agent(`agents/dod-*.md`)は現時点では**この横断配布の対象外**。apmのAgent探索は「パッケージルート直下の `*.agent.md`」または「`.apm/agents/` 配下」しか見ず、このリポジトリの既存レイアウト(`agents/<name>.md`)とは一致しないため、他プロジェクトから `apm install` で取り込むことはできない(実機のapmソースコードを読んで確認した制約で、未実装)。Agentは今のところこのマシン上(`~/.claude/agents/`)でのみ使う。

### レイアウト上の既知の落とし穴(実機で踏んだ地雷)

- Skillは `skills/<name>/SKILL.md` という1階層フラットな配置が必須。`skills/dod/<id>/SKILL.md` のように余分な `dod/` 名前空間フォルダでネストすると、`git:` 依存のみ(pathなし)でのapm一括スキャンが見つけられず `apm install` が `Not a valid APM package` で失敗する。
- 同様にAgentも `agents/<name>.md` のフラット配置。

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
