---
name: developer
description: "Developer agentを起動してTDD実装・バグ修正・リファクタリングを行う。実装タスクをメインコンテキストから分離して実行したいときに使用する。"
---

# Developer スキル

このスキルは `developer` agent をサブエージェントとして起動します。
agent の詳細定義は `.claude/agents/developer.md` を参照（単一の情報源）。

## 起動方法

```
Agent(
  subagent_type="developer",
  prompt="<実装タスクの詳細・設計仕様・完了条件を渡す>"
)
```

## いつ使うか

- XL・L サイズのタスクでメインコンテキストを守りたいとき
- architect agent が設計した方針に基づいて実装を進めるとき
- 既存コードのバグを修正するとき
- リファクタリングを実施するとき

## 渡すべきコンテキスト

- 実装するタスクの詳細な仕様
- architect が作成した設計文書・ADR（あれば）
- 対象ファイルのパス
- 完了条件（definition of done）
- テストファーストで進めること（必須）

## 注意

実装完了後は必ず `da-reviewer` agent でレビューを実施すること。
`/da-review` スキルを参照。
