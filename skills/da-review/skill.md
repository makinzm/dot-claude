---
name: da-review
description: "DA (Devil's Advocate) Reviewer agentを起動して実装をレビューする。実装完了後、本番マージ前に批判的レビューを実施したいときに使用する。"
---

# DA Review スキル

## 最重要ルール

> **あなた（呼び出し元 Claude）はレビューを実施してはいけない。**
>
> このスキルが呼ばれたとき、あなた自身がレビューコメントを書くことは禁止。
> 必ず `Agent(subagent_type="da-reviewer", ...)` を使って別のサブエージェントに委譲すること。
> インラインでレビューを完結させることは無効とみなす。

このスキルは `da-reviewer` agent をサブエージェントとして起動します。
agent の詳細定義は `.claude/agents/da-reviewer.md` を参照（単一の情報源）。

## 起動方法

```
Agent(
  subagent_type="da-reviewer",
  prompt="以下の変更をレビューしてください。\n\n<変更内容・差分・コンテキストを渡す>"
)
```

渡すコンテキストに必ず含めること:
- 変更内容の概要
- `git diff` または変更ファイルパス
- タスクの要件（requirements.md や TODO.md があれば）

## いつ使うか

- 実装が完了してPR作成前のタイミング
- 第三者の目で確認したいとき
- セキュリティ・テスト品質を重点的に確認したいとき

## レビュー後のフロー

1. da-reviewer サブエージェントから指摘事項リストが返ってくる
2. 実装者が修正する
3. 修正後、再度 `/da-review` でレビューを依頼する
4. LGTM が出たら PR 作成に進む

結果は `tasks/YYYYMMDD-<title>/da-review.md` に保存する。
