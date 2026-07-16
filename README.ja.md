<p align="center">
  <img src="assets/loopcraft-hero.jpg" alt="Loopcraft — 自己修正するループとセッションを越える記憶" width="880">
</p>

# Loopcraft

[English](README.md) | [한국어](README.ko.md) | **日本語** | [中文](README.zh-CN.md)

[Claude Code](https://claude.com/claude-code) 向けループエンジニアリング・プラグイン — 長くなる一方のプロンプトでモデルを操縦する代わりに、モデルが**環境からのフィードバックで自己修正**し、**セッションを越えて記憶を蓄積**するループを設計します。

Lance Martin の loop engineering と Andrej Karpathy の LLM Wiki パターンに着想を得ています: 自己改善はモデルではなく*システム*の性質です。Loopcraft はそのシステムをインストール可能なプラグインとして提供します。

## なぜ Loopcraft なのか？

Claude Code のセッションは毎回ゼロから始まります。前回積み上げた文脈 — そのテストがなぜ不安定だったか、すでに試して諦めたリファクタリング、このコードベースの癖 — は、セッションが終わるかコンテキストが圧縮された瞬間に消えます。よくある対応は、プロンプトに詰め込むことです：より長い `CLAUDE.md`、より多くの常設指示。しかし長くなる一方のプロンプトでモデルを操縦するやり方はスケールせず、昨日の作業を忘れることも、自分の産出物を甘く採点することも止められません。

ループエンジニアリングは異なる立場を取ります：**自己改善はモデルではなくシステムの性質である。** より大きなプロンプトの代わりに、ループを作ります — モデルが動き、*環境*が押し返し（テスト、独立した採点者）、モデルが修正し、学んだことは次のセッションが何かをする前にまず読む永続的な記憶へ書き込まれます。モデルが賢くなる必要はありません — モデルを取り巻くシステムが記憶し、検証すればよいのです。

Loopcraft はまさにそのシステムを、インストール可能なプラグインにしたものです。次のようなときに使ってください：

- 実際のプロジェクトを**複数のセッションにまたがって**進め、同じ文脈を毎回説明し直しているとき；
- モデルの「よさそう」を信じる代わりに、**明示的な基準で検証された**作業がほしいとき；
- Claude を**無人で**走らせ、すべての結果が `main` に届く前にゲートを通過し監査可能であってほしいとき；
- モデルが先週すでに直面し解決した**ミスをまた繰り返す**のに疲れたとき。

## 動作の仕組み

<p align="center">
  <img src="assets/loopcraft-how-it-works.svg" alt="Loopcraft の動作の仕組み — メモリ vault が SessionStart で注入され、loop-task → verifier → gate → commit のサイクルが始まる。検証失敗時は再試行し、蒸留された失敗は vault へ戻り、Stop ゲートと PreCompact フックがセッションを守る" width="900">
</p>

ループは 2 つの時間軸で閉じます：

- **タスクの中で** — `loop-task` はあなたの作業を独立した `verifier` に渡します。verifier はルーブリックに従って産出物と基準だけを見て採点します — maker の推論は決して見ないため、説得して合格させることはできません。失敗すれば maker が判定を受け取り、`maxRetries` まで再試行します。合格すれば実際のゲート（テスト・型チェック）を通過し、`Loop-Verified: n/m` が刻まれたコミットとして残ります。
- **セッションを越えて** — `.loop/memory` vault はリポジトリと一緒に移動します。`SessionStart` がそれを注入するので、Claude は過去のセッションが学んだことを知った状態で始まり、何かが失敗すれば `distill` がそれを*検証済み*の再利用可能な規則に変え、Stop ゲートと PreCompact フックが、セッションが終わるかコンテキストが要約で消える前に進捗を必ず書き残させます。何もゼロから学び直しません。

## 提供機能

| コンポーネント | 役割 |
|-----------|--------------|
| **SessionStart フック** | 新しいセッションごとにプロジェクトの記憶（`INDEX.md` + `STATE.md`）を自動注入し、台帳の未解決の失敗をリマインドします。Claude は過去のセッションが学んだことを知った状態で始まります。 |
| **Stop ゲートフック** | *Write before walking away*: コードが変更されたのに `STATE.md` が更新されていない場合、セッション終了を一度だけブロックして記録を促します。ループタスクのマーカーが残っている（検証未完了の）場合もブロック。ブロックはセッションごとに最大 1 回 — 閉じ込められることはありません。 |
| **PreCompact フック** | コンテキスト要約の直前に、進捗を `STATE.md` へ先に記録するようリマインドし、要約による情報損失を防ぎます。 |
| **`/loopcraft:distill` スキル** | 失敗を知識に変える 5 段階プロトコル: **Fail → Investigate → Verify → Distill → Consult**。失敗が*検証済み*の一般規則として vault に残ります — 既存ノートの更新を優先し、重複は生じません。 |
| **Obsidian 互換 vault** | `.loop/memory/` は YAML frontmatter と `[[ウィキリンク]]` を使う純粋な Markdown です。Obsidian の vault として開けば、知識グラフが育つ様子を観察できます。アプリ依存なし — ループに必要なのはファイルだけです。 |
| **`verifier` サブエージェント** | あなたのルーブリックに基づいて、成果物を独立して採点する評価者です。maker の推論は見ず、産出物と基準だけを見ます。maker のバイアスを完全に遮断します。 |
| **`/loopcraft:loop-task` スキル** | Maker → verifier → 再試行 → ゲート → コミットの循環：タスクの説明を提出すると、verifier の判定サマリを受け取り、合格時はコミット trailerに `Loop-Verified: n/m` を自動記録します。監査証跡が残る作業です。 |
| **`/loopcraft:loop-init` スキル** | リポジトリをスキャンし、あなたにインタビューして `.loop/` を設定済みゲートとルーブリック初案でスキャフォールドします。1 つのコマンドでプロジェクトオンボーディング完了。 |
| **`/loopcraft:loop-run` スキル** | バックログを無人で巡回 — 項目の選別、loop-task サイクルの実行、ゲート通過、コミットをすべて自動化します。すべてのコミットは worktree まで、main へのマージは常にあなたの判断です — システムは実行するだけで、絶対にリポジトリにはプッシュしません。 |

ランタイム依存ゼロ: `bash + git + grep/sed/awk`。エスケープハッチ: `LOOP_DISABLE=1` で全フックを無効化。

## インストール

**方法 A — マーケットプレイス（推奨）:**

```
/plugin marketplace add hiphapis/loopcraft
/plugin install loopcraft@loopcraft
```

**方法 B — ローカルクローン（開発用）:**

```bash
git clone https://github.com/hiphapis/loopcraft.git
claude --plugin-dir ./loopcraft
```

## プロジェクトのセットアップ

**推奨：`/loopcraft:loop-init` を使用**

リポジトリのルートで以下を実行します:

```
/loopcraft:loop-init
```

スキルがプロジェクト構造をスキャンし、ゲートとルーブリックについてインタビューした後、設定済みのゲートとルーブリック初案を含む `.loop/config.json` と `.loop/rubrics/` を自動生成します。手動編集は不要です。

### 手動セットアップ（オプション）

手動で `.loop/` をスキャフォールドする場合は、リポジトリのルートで 1 回実行:

```bash
mkdir -p .loop/memory/notes .loop/rubrics
cat > .loop/config.json <<'EOF'
{
  "gates": ["npm run typecheck", "npm run lint", "npm test"],
  "backlog": { "file": "docs/backlog.md", "section": "Ready to Execute" },
  "rubrics": [],
  "maxRetries": 3,
  "autonomy": { "commit": true, "mainMerge": false, "maxConsecutiveFails": 2 }
}
EOF
printf '# Memory Index\n\n> notes 0 · verified 0%% · updated: YYYY-MM-DD\n\n## debugging\n\n## pattern\n\n## environment\n\n## decision\n' > .loop/memory/INDEX.md
printf '# STATE — session handoff\n\n## Working on\n- (none)\n\n## Next steps\n- (none)\n\n## Open questions\n- (none)\n' > .loop/memory/STATE.md
printf '# LEDGER — failure ledger\n\n> stages: fail → investigate → verify → distilled\n\n| date | symptom | stage | note |\n|------|---------|-------|------|\n' > .loop/memory/LEDGER.md
printf '.loop/journal/\n.loop/state/\n' >> .gitignore
```

`gates` はプロジェクトの実際のコマンドに合わせて調整してください。`.loop/` はコミットします — vault はリポジトリと一緒に移動する設計で、worktree や別マシンでもそのまま引き継がれます。

## 使い方

**普段のセッション** — 何もする必要はありません。SessionStart フックが `INDEX.md` と `STATE.md` を自動注入し、Claude は蓄積された知識を参照してから作業を始めます。

**何かが失敗したとき**（テスト、ビルド、誤った仮定）:

```
/loopcraft:distill ffmpeg の焼き込み字幕が Homebrew ビルドで表示されない（libass 未搭載）
```

スキルが、台帳への記録 → 原因調査 → **再現・反証による診断の検証** → 一般規則への蒸留（frontmatter の `verified: true/false` が仮説と事実を区別）→ vault への接続まで導きます。

**監査証跡が必要な作業** — loop-task で verifier とゲートを通します:

```
/loopcraft:loop-task SQL インジェクション脆弱性を排除するため migration sanitization をリファクタリング
```

スキルがタスクを提出し、verifier の判定サマリを待ち、合格時はコミット trailer に `Loop-Verified: n/m` を記録します。ルーブリックは `.loop/rubrics/` で管理され、各ルーブリックは検証方法と通過条件を明記する必要があります。

**セッションを終えるとき** — コードを変更したのに `STATE.md` を更新していなければ、Stop ゲートが一度ブロックし、何を書き残すべきか教えてくれます。STATE を更新してきれいに終えれば、次のセッションはちょうどその地点から再開します。

**自律バックログ巡回** — システムに夜間の仕事を任せます：

```
/loopcraft:loop-run 3
```

バックグラウンドセッションでバックログアイテムを自動選別し、loop-task サイクルを実行、ゲート通過後に worktree にコミットします。朝に実行ジャーナル（`.loop/journal/run-*.md`）と Loop-Verified コミットをレビューし、気に入ったものだけ main に cherry-pick するか、残りは破棄します。システムは絶対にマージしない — すべての人間による門番の役割は完全に保持されます。

**成長の観察** — Obsidian で `.loop/memory/` を開いてグラフビューを見るか:

```bash
git log --oneline -- .loop/memory/   # ループがいつ何を学んだか
```

## Vault フォーマット

```
.loop/
├── config.json          # ゲート・バックログ・リトライ上限・自律権限
├── memory/              # リポジトリにコミット
│   ├── INDEX.md         # 目次（MOC）+ 統計（ノート数、verified 比率）
│   ├── STATE.md         # セッション引き継ぎ: 作業中 / 次のステップ / 未解決の疑問
│   ├── LEDGER.md        # 失敗台帳: fail → investigate → verify → distilled
│   └── notes/*.md       # 蒸留された規則（YAML frontmatter + [[ウィキリンク]]）
├── journal/             # 実行ログ — gitignore
└── state/               # 揮発性セッションマーカー — gitignore
```

ノートの frontmatter: `title / tags / category (debugging|pattern|environment|decision) / confidence / verified / created / updated / sources`。

## ロードマップ

- **Phase 1 — Memory** ✅: フック、蒸留プロトコル、vault。
- **Phase 2 — Self-correction** ✅: 検証可能なルーブリック、maker の推論を見ずに成果物だけを採点する独立 verifier サブエージェント、`/loop-task` 自己修正サイクル、`/loop-init` オンボーディング・インタビュー。
- **Phase 3 — 自律ランナー**（本リリース）: `/loop-run` がバックログを無人で巡回 — 作業 → 検証 → ゲート → コミット → 蒸留。コミットは worktree まで、main へのマージは常に人間が決定します。

## 要件

- プラグイン対応の Claude Code
- `bash`、`git`（macOS / Linux）

## テスト

```bash
./tests/run.sh   # 26 ケース: フック契約・サニタイズ・エッジケース
```

## ライセンス

MIT
