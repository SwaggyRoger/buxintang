# 卜心堂 · Buxintang

> A six-line coin oracle, read by a fortune-teller who has seen it all.

An R Shiny divination app. You cast three coins six times by hand to build a
hexagram; the app resolves it against the *I Ching* and hands the result to
Claude, playing an old temple fortune-teller, for the reading.

**Live:** https://rogerchen.shinyapps.io/buxintang/ · **中文說明：** [README.zh-TW.md](README.zh-TW.md)

The interface is in Traditional Chinese.

---

## What it actually does

Most "I Ching apps" hand an LLM six numbers and hope it works out the hexagram.
It won't reliably — that step is mechanical, and models are bad at mechanical.
Here R does the divination and the model only does the reading.

### Casting — three-coin method (金錢卦)

Three coins, six throws, built bottom-up from the first line to the sixth.
Heads (字) count 3, tails (背) count 2:

| Sum | Line | | Moving? | Probability |
|---|---|---|---|---|
| 6 | old yin 老陰 | `▬▬ ▬▬ ✕` | yes → becomes yang | 1/8 |
| 7 | young yang 少陽 | `▬▬▬▬▬` | no | 3/8 |
| 8 | young yin 少陰 | `▬▬ ▬▬` | no | 3/8 |
| 9 | old yang 老陽 | `▬▬▬▬▬ ○` | yes → becomes yin | 1/8 |

All six throws are required. There is no button to leave once the casting
has begun.

### Resolving

From the six lines the app computes:

- **本卦** the primary hexagram (one of 64, with its name and Judgment text)
- **之卦** the resulting hexagram, after every moving line flips
- **互卦** the nuclear hexagram (lines 2‑3‑4 and 3‑4‑5) — the hidden middle of the matter
- **Line titles** in the traditional form: 初九, 六二, 九三 …
- **Which text to read from.** The rule set follows a reading of the Spring
  and Autumn divination records in the *Zuo Zhuan* and *Guoyu*. It is close to
  Zhu Xi's rules in *易學啟蒙* but differs at two, four and five moving lines:

  | Moving lines | Read | vs. Zhu Xi |
  |---|---|---|
  | 0 | the Judgment of the primary hexagram | same |
  | 1 | that line's text; **the resulting hexagram is not consulted** | same |
  | 2 | both line texts — the **lower** is 貞 (governing), the upper 悔 | Zhu Xi lets the *upper* govern |
  | 3 | both Judgments, primary 貞, resulting 悔 | same |
  | 4 | lines no longer apply — the **resulting** hexagram is 貞, the primary 悔 | Zhu Xi reads the two unchanged lines |
  | 5 | same as four | Zhu Xi reads the one unchanged line |
  | 6 | 用九 for Qian, 用六 for Kun, otherwise the resulting hexagram's Judgment | same |

  Where the rule says the resulting hexagram does not govern, the casting sheet
  says so explicitly, so the model does not over-weight it.

### Asking three times (卜不過三)

From the Judgment of hexagram 4, 蒙: *"The first consultation I answer. Ask
twice, three times — that is pestering, and to pestering I give no answer."*

Ask the same thing twice and the app says so. Ask a third time and the
fortune-teller declines. Questions are normalised (whitespace, full/half-width
punctuation) before comparison, and a question is only counted once the
hexagram is actually complete — walking away mid-cast costs you nothing.

---

## The fortune-teller

The computed hexagram is formatted into a *casting sheet* — name, Judgment,
moving lines with their titles, resulting hexagram, nuclear hexagram, which rule
applies, **and the verbatim text of the passages that rule selects** — and sent
to `claude-opus-5`. The model never has to derive the hexagram, and never has to
recall the classical text from memory. The prompt tells it to quote those
passages unchanged and not to supply others from memory.

The persona: **a fortune-teller who understands how people actually work.**
Thirty years in a small temple with unremarkable incense. He knows the person
kneeling in front of him is asking about the hexagram but wants a sentence —
one that will let them keep going, or let them give up.

Readings run 600–900 characters in four parts:

| Section | |
|---|---|
| 【籤解】 *The reading* | What this hexagram is, where the moving line sits, what that means for the question |
| 【打個比方】 *For instance* | A concrete scene from the asker's actual situation — not a parable |
| 【所以呢】 *So* | What to do and not do, specific enough to act on, with an observable signal to watch for |
| 【啟】 *One line* | Something short enough to carry away |

The prompt carries an explicit **anti-formula list**. Without it, every reading
opened its example with "你大概⋯" (5/5 in testing) and every hexagram
description with "上卦X是⋯，下卦Y是⋯" (5/5), which makes several readings feel
like one reading. The list names those openings and bans them, and requires a
different entry point each time — the character in the hexagram's name, the
position of the moving line, one word from the Judgment, or the asker's own
situation first.

`CLAUDE_EFFORT` at the top of [`R/03_interpreter.R`](R/03_interpreter.R)
defaults to `"medium"` (35–55 s per reading). `"high"` costs about 30% more
time for little measured difference; `"low"` is faster but noticeably thinner.

Without an API key the app still runs and falls back to an **offline reading**
generated from the Judgment text. The hexagram is real; the voice is not.

---

## Architecture

```
buxintang/
│
├── app.R                    entry point — stage machine + per-stage views
│                            threshold → asking → casting → formed → pondering → read
│                            PONDERING_LINES: 42 lines, whole deck shuffled and played in order
│
├── R/                       auto-sourced by Shiny (>= 1.5), no source() needed
│   ├── 01_hexagrams.R       eight trigrams · 64 hexagrams (name / Judgment /
│   │                        gist) · lookup by lines · line titles
│   │                        validates its own table at load
│   ├── 01_yaoci.R           the 384 line texts, plus 用九 and 用六 —
│   │                        generated by tools/, not edited by hand
│   ├── 02_casting.R         coin throws · moving lines · resulting & nuclear
│   │                        hexagrams · the rule set · 十二時辰 · 卜不過三
│   ├── 03_interpreter.R     fortune-teller persona · casting sheet ·
│   │                        Claude Messages API (httr2) · offline fallback
│   └── 04_ui.R              bslib theme · hexagram & coin HTML · reading layout
│
├── www/
│   ├── styles.css           the entire visual design
│   └── ritual.js            rotates the waiting-screen narration
│
├── tests/
│   ├── test-divination.R    64-hexagram table, 8×8 reverse lookup, known
│   │                        hexagrams, moving lines, the rules at 0–6, the
│   │                        line-text table, nuclear hexagram, coin distribution, 時辰,
│   │                        卜不過三, every stage's UI render
│   └── test-claude-payload.R  request shape only — sends nothing, costs nothing
│
├── tools/                   one-off pipeline that builds R/01_yaoci.R from two
│                            public-domain sources and diffs them; not deployed
├── deploy.R                 bundle and push to shinyapps.io
├── .Renviron.example        copy to .Renviron, add your key
└── _archive/                the pre-rewrite version, kept for reference
```

### Request flow

```
   user                app.R                R/02_casting.R        R/03_interpreter.R
    │                    │                        │                       │
    │  ── throw ×6 ───▶  │                        │                       │
    │                    │ ── build_divination ─▶ │                       │
    │                    │                        │ 本卦 / 之卦 / 互卦     │
    │                    │ ◀── + rule & texts ─── │                       │
    │                    │                                                │
    │  ── ask ────────▶  │ ── format_hexagram_brief ────────────────────▶ │
    │                    │      (casting sheet, not raw numbers)          │
    │                    │                                                │ ──▶ api.anthropic.com
    │  ◀── reading ───── │ ◀────────────────────── call_claude ────────── │ ◀──
```

The Claude call is synchronous, wrapped in `session$onFlushed` so the waiting
screen reaches the browser first. Verified on shinyapps.io: a 44 s blocking
call did not drop the websocket.

---

## Where the text comes from

The *Zhouyi* itself is roughly three thousand years old and in the public
domain. What can carry copyright is a modern translation, commentary or
collation — none of which is used here. Only the classical text is stored.

`R/01_yaoci.R` is built by `tools/` from **two independent public-domain
sources**, compared character by character:

- 318 of the 386 entries could be checked against both. **91.8% agreed**
  outright; the rest differed only in variant characters.
- Where they differed, the second source wins. It is consistently traditional
  (the first leaks simplified forms — 系/云/几/觌/涂), and it caught a
  transposition in the first: 復 initial line reads 不遠復, not 不復遠.
- 11 hexagrams (乾坤屯蒙需訟師比小畜大畜困) had only one witness. They are
  named in the file header.

The 64 Judgments in `R/01_hexagrams.R` were also checked against the first
source: **hexagram numbers and trigram pairs matched all 64**, and the two
substantive text differences both turned out to be defects in that source —
a truncated 坤 Judgment and a mispunctuated 剝.

Re-run the pipeline with `python tools/1_fetch_wikisource.py` and the numbered
scripts that follow. It caches what it fetches, so re-parsing costs no requests.

---

## Running it

```bash
Rscript -e "shiny::runApp('.', port = 7788, launch.browser = TRUE)"
```

Three dependencies: `shiny`, `bslib`, `httr2`.

### API key

Copy `.Renviron.example` to `.Renviron`, fill it in, restart the R session:

```
ANTHROPIC_API_KEY=sk-ant-...
```

`.Renviron` is gitignored and never reaches this repository. Nothing is
hard-coded in the source.

### Tests

```bash
Rscript tests/test-divination.R
Rscript tests/test-claude-payload.R
```

Neither calls the API.

---

## Deploying to shinyapps.io

```bash
Rscript deploy.R
```

Run `rsconnect::setAccountInfo(...)` once first — see the comments in
[`deploy.R`](deploy.R).

**How the key gets there.** shinyapps.io does **not** support `rsconnect`'s
`envVars` argument — that is a Posit Connect feature, and passing it here fails
with `shinyapps.io does not support setting envVars`. The working approach is
to ship `.Renviron` inside the bundle; R reads it at startup on the server.

> The key therefore lives in the deployed bundle. It is not publicly reachable
> — bundles are not served, only the app runs — but anyone who can sign in to
> the shinyapps.io account can retrieve it. Fine for a personal project; use
> Posit Connect if you need better.
>
> `.Renviron` still never enters git. It goes into the bundle only.

There is no second process. An earlier version ran a separate plumber API on
`localhost:8000`, which cannot work on shinyapps.io — that platform runs the
Shiny process and nothing else. The API call now lives inside the Shiny server.

Timestamps are pinned to `Asia/Taipei` (`DIVINATION_TZ` in
[`R/02_casting.R`](R/02_casting.R)). shinyapps.io servers run UTC, which would
otherwise record a Taipei morning as the hour of the Ox.

---

## Design notes

The visual key is *night temple, candlelight*: dark, warm, quiet. Gold is
incense-light. Cinnabar is reserved for moving lines and the seal. Paper appears
exactly once in the whole app — the reading itself, which arrives as a warm page
out of the dark. Functional chrome is pushed back so that pacing, empty space,
and the waiting become the content.

Type is Noto Serif TC. Every animation respects `prefers-reduced-motion`, and
entrance animations are decoration rather than load-bearing: an element's
default style is the visible one, so a stalled animation timeline (a
backgrounded tab, a throttled browser) can never leave the hexagram invisible.

---

## Disclaimer

The fortune-teller is Claude in costume. It is for interest, not advice.

*卦以決疑，不以代決* — a hexagram is for resolving doubt, not for deciding on
your behalf.
