# カスタマージャーニーマップ: Document/Software Factory の利用者

## 対象者（ペルソナ）

**「自分のリポジトリで成果物(記事・ドキュメント・設計案)を書き、`makinzm/dot-claude` の DoD Factory を使って完了条件を確認し、公開するまでを一人でやりきる開発者」**。

- 例: `makinzm/qiita-dir` で記事を書く本人。あるいは、同じ仕組みを自分の別リポジトリに導入したい別の開発者。
- 前提知識: Git / GitHub / `apm` CLI の基本操作はできるが、`makinzm/dot-claude` のDoD Factoryの内部実装(`dod/deliverables-dod.json`, `sync-dod-skills.py`)は知らない。

## ジャーニー全体図

```
① 気づく → ② 導入する(apm install) → ③ 書く → ④ 確認する(DoD) → ⑤ 公開する → ⑥ 拡張する(DoD項目追加)
```

## 各ステージの詳細

### ① 気づく — 「このリポジトリにはDoDがある」と知る

| 項目 | 内容 |
|---|---|
| 必要な情報 | 自分のリポジトリ(例: qiita-dir)がDocument Factoryとして運用されていること |
| 参照先 | 消費側リポジトリのトップレベル `README.md` |
| 現状 | ✅ qiita-dir には `# qiita-dir — Document Factory` セクションがある(PR #11) |
| 実際に踏んだ地雷 | ローカルの `git clone` が `origin/main` に1コミット遅れていたため、**ファイルは存在するのに手元には反映されていなかった**。`git pull` するまで「書いてあるはずなのに見つからない」状態になった。 |
| 教訓 | 「READMEに書いた」だけでは消費者に届かない。ローカルの作業コピーが最新である前提が崩れると、ドキュメントの有無そのものが分からなくなる。 |

### ② 導入する — `apm install` で依存を実体化する

| 項目 | 内容 |
|---|---|
| 必要な情報 | `apm.yml` の書き方、`apm install` / `apm audit` の使い方 |
| 参照先 | 消費側 `README.md`「使い方」節、`apm.yml` 本体 |
| 現状 | ✅ qiita-dir で動作確認済み(PR #9, #10) |
| 既知の落とし穴 | `ref` を pin しないと apm が "unpinned" 警告を出す。Skillは `skills/<name>/SKILL.md` のフラット配置が必須で、ネストすると `apm install` が `Not a valid APM package` で失敗する(dot-claude README「レイアウト上の既知の落とし穴」に記録済み)。 |

### ③ 書く — Skillを参照しながら成果物を書く

| 項目 | 内容 |
|---|---|
| 必要な情報 | 取り込んだ `dod-*` Skill + リポジトリ固有のSkill(例: `qiita-dod-review`)の内容 |
| 参照先 | `.claude/skills/dod-*/SKILL.md`, `.claude/skills/qiita-dod-review/SKILL.md` |
| 現状 | ✅ Skillはコンテキストに軽量に読み込める設計で機能している |

### ④ 確認する — Agentで個別にレビューする

| 項目 | 内容 |
|---|---|
| 必要な情報 | `Task` ツールで `subagent_type: dod-<id>` を起動する方法 |
| 参照先 | dot-claude `README.md`「DoD Factory」節 |
| 現状 | ⚠️ **部分的**。Agent(`agents/dod-*.md`)は dot-claude をマシンに `chezmoi apply` した**このマシン上でしか使えない**。apmのAgent探索規約(`*.agent.md` をパッケージルート直下、または `.apm/agents/` 配下)と `agents/<name>.md` という既存レイアウトが一致しないため、他プロジェクトが `apm install` で取り込んでも Agent は手に入らず、Skillだけになる。 |
| 影響 | 別の開発者が自分のリポジトリにこの仕組みを導入しても、「個別コンテキストでのレビュー(Agent)」は享受できず、「執筆中の軽量な観点リマインド(Skill)」しか得られない。ペルソナが「`makinzm/dot-claude` を直接使っている本人」以外の場合、このギャップに気づきにくい。 |

### ⑤ 公開する — PRを作り、マージする

| 項目 | 内容 |
|---|---|
| 必要な情報 | 通常のPRフロー(ブランチ作成→PR→レビュー→マージ) |
| 参照先 | CLAUDE.md「プロセス原則」 |
| 現状 | ✅ qiita-dir PR #8〜#11 で実際に運用できている |

### ⑥ 拡張する — DoD項目を追加/削除する

| 項目 | 内容 |
|---|---|
| 必要な情報 | `dod/deliverables-dod.json` を編集し `sync-dod-skills.py` を実行する手順 |
| 参照先 | dot-claude `README.md`「DoD項目を増やす/減らす手順」(4ステップ) |
| 現状 | ⚠️ **手順はドキュメント化されているが、エントリーポイントが分散している**。「DoDを増やしたい」と思ったとき、まずどのリポジトリ(dot-claude)のどのファイル(README.md、CLAUDE.mdではない)を見ればいいかが、消費側リポジトリ(qiita-dir等)からは直接リンクされていない。qiita-dir の README「DoD項目の定義場所」は正本の場所(`dod/deliverables-dod.json`)を示しているが、そこから dot-claude の README の具体的な4ステップへのリンクはない。 |
| 対応 | qiita-dir側「DoD項目の定義場所」節に、dot-claude `README.md#dod項目を増やす減らす手順` への直接リンクを張ることを推奨(本ドキュメント作成時点では未実施 — 次のアクション)。 |

## このジャーニーマップの維持

- Factory側(dot-claude)の README/CLAUDE.md/`sync-dod-skills.py` の挙動を変更したときは、このドキュメントの関連ステージを見直し、矛盾があれば更新する(CLAUDE.md「運用方式はトップレベルREADMEに書く」と対になる、ジャーニー単位の整合性チェック)。
- 新しい消費側リポジトリでこの仕組みを導入する機会があれば、実際にこのジャーニーをゼロから踏んで、表の「現状」列を実測で更新する。
