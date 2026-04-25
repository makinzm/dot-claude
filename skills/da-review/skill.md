---
name: da-review
description: "DA (Devil's Advocate) Reviewer agentを起動して実装をレビューする。実装完了後、本番マージ前に批判的レビューを実施したいときに使用する。"
---

# DA Review スキル

このスキルは `da-reviewer` agent をサブエージェントとして起動します。
agent の詳細定義は `.claude/agents/da-reviewer.md` を参照（単一の情報源）。

## 起動方法

```
Agent(
  subagent_type="da-reviewer",
  prompt="以下の変更をレビューしてください。\n\n<変更内容・差分・コンテキストを渡す>"
)
```

## いつ使うか

- 実装が完了してPR作成前のタイミング
- 自分の実装に自信がなく、第三者の目で確認したいとき
- セキュリティ・パフォーマンス・テスト品質を重点的に確認したいとき

## 渡すべきコンテキスト

- 変更内容の概要
- `git diff` または変更したファイルのパス
- 実装した機能の要件（requirements.md や TODO.md があれば渡す）
- 特に注意して見てほしい観点（あれば）

## レビュー後のフロー

1. DA から指摘事項リストが返ってくる
2. 実装者（developer agent またはメインClaude）が修正する
3. 修正後、再度 `/da-review` でレビューを依頼する
4. LGTM が出たら PR 作成に進む

レビュー結果は `tasks/YYYYMMDD-<title>/da-review.md` に保存する。
