---
name: factory-init
description: 新しいプロジェクトを「Software Factory」運用(dot-claudeのDoD駆動Hook・BACKLOG・apm経由のDoD Skill取り込み)が最初から効いた状態でブートストラップする。新規プロジェクトを始めるときに使う。「新しいリポジトリをSoftware Factoryとして始めたい」「DoDをこのプロジェクトにも入れたい」「会社/他組織のDoDを取り込みたい」と言われたら使う。
---

# factory-init スキル

新しいプロジェクトを、`makinzm/dot-claude` が前提にしている「Software Factory」運用がすでに効いた状態でスタートさせるスキル。エージェントは起動しない(決定論的なスキャフォールディング作業のため、`adr` skillと同じ直接実行スタイル)。

## 前提として知っておくこと: 何がグローバルで、何がプロジェクトごとに必要か

このユーザーの `~/.claude/` 配下の設定(`CLAUDE.md`・`settings.json`のHook群・`~/.git-hooks/`経由のgit hook)は**マシン全体に効く**ため、新規プロジェクトでも何もしなくてもすでに有効:

- mainブランチ直push/commitのブロック(`~/.git-hooks/pre-commit`・`pre-push`)
- 承認ログ・状態マーカー強制・改善チェックなどの `Stop`/`PreToolUse` hook群
- `CLAUDE.md` のワークフロー原則(TDD・タスクディレクトリ・DAレビュー等)

**プロジェクトごとに個別に用意しないと効かないもの**がこのスキルの対象:

1. 作業ブランチ(mainguardに引っかからないよう、最初の commit 前に切っておく)
2. `docs/tasks/BACKLOG.md`(`UserPromptSubmit` hookが自動注入する対象。ファイル自体は各プロジェクトに置く必要がある)
3. このプロジェクトで実際に使う `dod-*` Skill/Agent(`apm install` で materialize するまでは存在しない)
4. そのプロジェクトのREADMEに「DoD駆動で運用する」ことを明記すること(CLAUDE.md「運用方式はトップレベルREADMEに書く」はdot-claude自身だけでなく全プロジェクトに課す原則)

## 手順

### Step 0: 対象ディレクトリの確認

`git status` 等で既存リポジトリの状態を確認する。真っ白な新規プロジェクトか、既存プロジェクトへの後付けかで一部スキップする(例: 既に `BACKLOG.md` があれば上書きしない)。

### Step 1: git初期化 + 作業ブランチ

```bash
git init   # 既にリポジトリなら不要
git checkout -b chore/bootstrap-factory
```

**mainブランチのまま最初のcommitをしない。** まだ `origin` が無い/許可リスト外のリポジトリでは、グローバル `pre-commit` hook (mainguard) がmainへの直接commitをブロックする。最初から作業ブランチに乗ってから以下を進める。

### Step 2: `docs/tasks/BACKLOG.md` を作成

無ければ作成する(既にあれば触らない)。最小テンプレート:

```markdown
# Backlog

- `[ ]` 未着手 / `[~]` 進行中 / `[x]` 完了

## タスク

- [ ] 初期セットアップの続き(READMEの肉付け、CIの追加など)
```

### Step 3: `apm.yml` に DoD Skill の依存を書く

既存の `apm.yml` があれば `dependencies.apm` 配列に追記、無ければ新規作成する。`ref` は必ず固定コミットにpinする(省略すると apm が "unpinned" 警告を出す)。

```yaml
dependencies:
  apm:
    - git: makinzm/dot-claude
      ref: b09ae35b2abc92a62d8c989e8dd05d618a67529f   # 実行時点のHEAD。古くなっていたら最新commitに更新してよい
      skills:
        - dod-adr-structure
        - dod-ambiguous-acronym-confirm
        - dod-no-edit-timeline-narration
        - dod-rubric-completeness
        - dod-source-accuracy
        - dod-primary-source-verification
        - dod-score-anchor-consistency
```

全7項目をデフォルトで列挙しているが、このプロジェクトに関係ない項目(例: コードしか書かないリポジトリに文章系DoDは不要、等)はユーザー判断で削ってよい。削除はユーザーに確認してから行う(このスキル自身が代わりに判断しない)。

### Step 4: `apm install` を実行

```bash
apm --version   # 入っているか確認。無ければユーザーに案内し、勝手にインストールしない
apm install
```

成功したら `.claude/skills/dod-*/SKILL.md` が生成されていることを確認する。

### Step 5: README.mdに運用方式を一言書く

既存READMEの末尾あたりに短い節を追加する(詳細を複製しない。要点のみ):

```markdown
## 開発運用方式

このプロジェクトはDoD駆動(Definition of Done)で運用する。成果物のDoDは
[makinzm/dot-claude](https://github.com/makinzm/dot-claude) から `apm install` で
取り込んだ `dod-*` Skill/Agent(`apm.yml` 参照)で確認する。
```

### Step 6: ここまでをcommit

Step 1〜5 の内容を作業ブランチ上でcommitする(mainへのマージ・PR化はユーザー判断に委ねる。このスキルはスキャフォールディングのみで完了する)。

## 完了条件(このスキル自身のDoD)

- [ ] 作業ブランチ上にいる(mainではない)
- [ ] `docs/tasks/BACKLOG.md` が存在する
- [ ] `apm.yml` に最低1つの `dod-*` Skill依存が `ref` pin付きで書かれている
- [ ] `apm install` 済みで `.claude/skills/dod-*` が存在する(apmが使えない環境なら、その旨とTODOを明記)
- [ ] README.mdに運用方式の一言がある
- [ ] 上記すべてが作業ブランチ上でcommit済み

---

## 会社・他組織のDoDを取り込む

個人用の `makinzm/dot-claude` 以外に、会社や他組織が持っているDoD(品質基準・チェックリスト)をこのプロジェクトに取り込みたい場合、状況によって手順が異なる。**どの案を選ぶかはユーザー判断に委ね、このスキルが独断で決めない**(CLAUDE.md「設計合意の義務」と同じ原則: 複数の選択肢を必ず列挙してから選んでもらう)。

### パターンA: 組織側がすでに「DoD Factory」と同じ構造を持っている

組織のリポジトリが `dod/deliverables-dod.json`(id/title/checkの配列)+ `sync-dod-skills.py` 相当の生成器を持ち、`skills/dod-<id>/SKILL.md` をapm配布可能な形(1階層フラット)で公開しているなら、`apm.yml` に並べてエントリを追加するだけで済む:

```yaml
dependencies:
  apm:
    - git: makinzm/dot-claude
      ref: <pin>
      skills: [dod-adr-structure, ...]
    - git: <org>/<org-dod-repo>
      ref: <pin>
      skills: [dod-<org-item-1>, dod-<org-item-2>]
```

**注意(id衝突)**: `dod-*` のSkill/Agentはこのプロジェクト内でフラットに並ぶため、個人用と組織用でidが衝突しないか事前に確認する。衝突しそうなら、組織側に `dod-<company>-<name>` のような接頭辞を付けてもらうよう依頼する(こちら側だけでリネームして取り込むのは避ける。idは組織側のJSONが正本のため)。

### パターンB: 組織のDoDがまだ構造化されていない(Wiki/Confluence/PDFのチェックリストのみ)

機械的に取り込めないので、2つの選択肢をユーザーに提示して選んでもらう:

- **B-1(再利用性重視)**: 組織側のリポジトリに `dod/deliverables-dod.json` + 生成器パターンを新設することを提案する。一度作れば他のプロジェクトからも `apm install <org>/<repo> --skill dod-<id>` で取り込めるようになる。組織側の協力が必要なので実現までに時間がかかる。
- **B-2(このプロジェクト限定)**: このプロジェクトのローカルに最小構成( `dod/deliverables-dod.json` + `scripts/sync-dod-skills.py` のコピーを `.claude/skills` / `.claude/agents` 向けに実行)を置く。apm配布はしない。即座に使えるが、他プロジェクトへの再利用性はない。

### パターンC: 個人用(makinzm/dot-claude)のDoDに、このプロジェクト固有の項目を追加したい

既存の `makinzm/dot-claude` README「運用」節の方針どおり: プロジェクト固有の `.claude/` に、1項目=1レビューAgent/Skillの発想で追加する(すべてを1つの汎用レビューAgentに担わせない)。`makinzm/dot-claude` 本体を会社の基準に汚染させない(個人用と組織用は別リポジトリ・別idで管理する)。
