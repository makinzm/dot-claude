---
name: po
description: "PO (Product Owner) agentを起動して要件整理・ユーザーストーリー作成・優先付けを行う。曖昧な要求を実装可能な仕様に変換したいときに使用する。"
---

# PO スキル

このスキルは `po` agent をサブエージェントとして起動します。
agent の詳細定義は `.claude/agents/po.md` を参照（単一の情報源）。

## 起動方法

```
Agent(
  subagent_type="po",
  prompt="<ユーザーの要求・背景・期待する成果物を渡す>"
)
```

## いつ使うか

- 要件が曖昧でまず仕様を固めたいとき
- ユーザーストーリーと受け入れ条件を作りたいとき
- 機能の優先順位を整理したいとき
- スコープを定義してから実装に入りたいとき

## 渡すべきコンテキスト

- ユーザーの要求（できるだけ原文で）
- 背景・目的
- 期待するアウトプット（requirements.md / ユーザーストーリー / 優先付けリスト）

## 成果物の保存先

`tasks/YYYYMMDD-<title>/requirements.md` に保存する。
この requirements.md を architect / developer agent に渡して実装を進める。
