---
name: adr
description: ADR（Architecture Decision Record）を作成するスキル。アーキテクチャや技術的な意思決定を記録するドキュメントを作成する。ユーザーが「ADRを作りたい」「意思決定を記録したい」「技術選定のドキュメントを作りたい」などと言った場合に使用する。ADRのテンプレートに沿って、コンテキスト・選択肢・決定軸・評価・決定・結果を整理してファイルを生成する。
---

# ADR スキル

Architecture Decision Record（ADR）を正しいフォーマットで作成するスキル。

## 概要

ADR は技術的・アーキテクチャ的な意思決定を記録するドキュメント。なぜその決定をしたか、どの選択肢を検討したか、どの軸で評価したかを残すことで、将来の自分やチームが文脈を理解できるようにする。

## ファイルの配置

1. プロジェクトに `docs/adr/` があればそこに配置する
2. なければ `adr/` を探す
3. どちらもなければ `docs/adr/` を作成する

ファイル名は `ADR-NNN-<kebab-case-title>.md` の形式で連番付与（例: `ADR-001-use-postgresql.md`）。

既存のADRファイルを確認して次の番号を決める。

## 作成前に収集する情報

ユーザーから以下を確認する（引数で渡された場合はスキップ）：

1. **タイトル** — 何についての決定か（例: "データベースの選定"）
2. **提案者** — 誰が提案したか（例: "Alice"）
3. **関連Issue/PR** — 参照すべきIssueやPRがあれば番号
4. **コンテキスト** — 背景となる事実（参照URLがあれば教えてもらう）
5. **検討した選択肢** — A案、B案など（2〜4個程度）
6. **決定軸** — 何を基準に評価するか（例: パフォーマンス、コスト、運用負荷）
7. **決定内容** — 最終的に何を選んだか

情報が不十分な場合は、プレースホルダーを入れて後から編集できる形で作成する。

## ADR フォーマット

```markdown
# <タイトル>

## Statuses

(新しいステータスが上に来るよう降順で記載)

| Status | Date | Reason |
| ------ | ---- | ------ |
| Proposed | YYYY-MM-DD | Initial proposal from <提案者>. Reference to <Issue/PR>. |

## Context

(事実のみを記載。意見・解釈は含めない。)
(参照情報はマークダウンリンク形式のURLと blockquote の引用を組み合わせて記載する。)

> "引用テキスト"
> — [Source Title](URL)

**要約**: <コンテキストの要約を1〜3文で>

## Options considered

### Option A: <選択肢名>

<選択肢の概要>

### Option B: <選択肢名>

<選択肢の概要>

## Decision criteria

(決定の軸を定義する。重み付けで評価の優先順位を明示する。)

| Criterion | Weight | Description |
| --------- | ------ | ----------- |
| <軸名> | High / Medium / Low | <この軸が重要な理由・評価方法> |

## Evaluation

(各選択肢を決定軸ごとに評価する。記号の目安: ✅ 良い / ⚠️ 許容範囲 / ❌ 問題あり)

| Criterion | Option A | Option B |
| --------- | -------- | -------- |
| <軸名> | ✅ <理由> | ❌ <理由> |

## Decision

<選んだ選択肢> を採用する。

<Evaluation の結果を踏まえ、なぜこの選択が最善かを説明する。>

## Consequences

### Positive
- <この决定によって得られるメリット>

### Negative
- <この决定によるデメリット・トレードオフ>

### Risks
- <将来起きうるリスクと対処方針>

## References

- [<タイトル>](<URL>)
```

## ステータスの種類と運用

| Status | 意味 |
| ------ | ---- |
| Proposed | 提案中。レビュー待ち。 |
| Accepted | 合意済み。実装対象。 |
| Deprecated | 別のADRに置き換えられた。 |
| Superseded | より新しい決定で上書きされた。 |
| Rejected | 却下された。 |

既存のADRが新しいADRで置き換えられる場合、古いADRの Statuses テーブルに `Deprecated` 行を追加し、新しいADRへの参照を Reason に記載する。

## コンテキストの書き方

- **事実のみ** を書く。意見・推測・解釈は含めない。
- 参照元がある場合は必ずURLをマークダウンリンクで記載する。
- blockquote（`>`）で原文を引用し、その下に `— [Source](URL)` を書く。
- 引用の後に `**要約**:` で自分の言葉でまとめる。

**良い例:**
```
> "PostgreSQL has been the world's most advanced open source relational database for over 35 years."
> — [PostgreSQL About](https://www.postgresql.org/about/)

**要約**: PostgreSQL は長年の実績を持つオープンソースRDBで、豊富な機能セットを持つ。
```

**悪い例:**
```
PostgreSQL は良いデータベースだと思う。（意見が混入している）
```

## 決定軸（Decision criteria）の書き方

決定を下す前に必ず軸を定義する。これにより：
- 恣意的な決定を防ぐ
- 後から「なぜこれを選んだか」を説明できる
- 軸の重み付けで優先事項が明確になる

Weight は `High / Medium / Low` で表現する。

## 完成後の案内

ファイルを作成したら以下を伝える：
- 作成したファイルのパス
- 次にやること（プレースホルダーが残っている場合は埋めるよう案内）
- 既存ADRを Deprecated にする必要がある場合はその手順
