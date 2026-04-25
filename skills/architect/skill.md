---
name: architect
description: "Architect agentを起動してアーキテクチャレビュー・設計・ADR作成を行う。ユーザーが「設計を見てほしい」「アーキテクチャを考えたい」「技術選定をしたい」「ADRを書きたい」と言った場合に使用する。"
---

# Architect スキル

このスキルは `architect` agent をサブエージェントとして起動します。
agent の詳細定義は `.claude/agents/architect.md` を参照（単一の情報源）。

## 起動方法

以下のように Agent tool で architect agent を起動する:

```
Agent(
  subagent_type="architect",
  prompt="<ユーザーの要求と関連コンテキストを渡す>"
)
```

## いつ使うか

- 大規模なリファクタリングの前に設計方針を決めたいとき
- 新しいシステム・モジュールの設計をしたいとき
- 技術選定で複数の選択肢を比較検討したいとき
- アーキテクチャ上の問題を発見・解決したいとき
- ADR（Architecture Decision Record）を作成したいとき

## 渡すべきコンテキスト

- 対象のコードベースのパス・構造
- 解決したい問題・課題
- 既存の制約（パフォーマンス要件・使用技術スタックなど）
- architect に期待するアウトプット（ADR / 設計文書 / レビューコメント など）
