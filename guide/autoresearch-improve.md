# /autoresearch:improve — Product Improvement Engine

Research what to build next. Discovers ICP challenges via deep multi-source web research, scores and ranks improvements, generates per-feature PRDs with evidence chains.

---

## When to Use

- Product company evaluating what to build next
- Solo founder deciding feature priorities with data
- PM needing evidence-backed PRDs instead of gut-feel roadmaps
- Engineering lead aligning technical improvements with ICP needs

**Not for:** Code quality improvements (use `/autoresearch`), bug hunting (use `:debug`), security hardening (use `:security`), architecture decisions (use `:reason`).

---

## Quick Start

```
/autoresearch:improve
Goal: Improve onboarding conversion for our invoicing SaaS
ICP: Freelancers and small agencies billing $5K-50K/month
```

The agent:
1. Resolves product context from existing docs (learn summary, README, package.json) or auto-discovers
2. Researches across 5 categories via WebSearch with triangulation
3. Saturates when net-new insights drop below threshold
4. Ranks improvements: ICP gate → Must-have / Nice-to-have / Moonshot
5. Asks you to select which features become PRDs
6. Generates per-feature PRDs with evidence chains

---

## Flags

| Flag | Purpose | Default |
|------|---------|---------|
| `Goal:` | Product area to improve | required (or interactive) |
| `--icp "<text>"` | Ideal customer profile | required (or interactive) |
| `--discover` | Force codebase scan even with existing context | conditional |
| `--no-discover` | Skip auto-discover, warn instead | off |
| `--depth <level>` | shallow (5), standard (15), deep (30+) | standard |
| `Iterations: N` | Research loop iteration count | 15 |
| `--seeds <categories>` | Override research category seeds | auto from chain source |
| `--evals` | Enable mid-loop checkpoints | off |

---

## 5 Research Categories

| # | Category | What it researches |
|---|----------|--------------------|
| 1 | ICP challenges | Pain points, jobs-to-be-done, unmet needs |
| 2 | Competitor gaps | Weaknesses, missing features, technical differentiators |
| 3 | Market trends | Timing signals, emerging patterns, regulatory shifts |
| 4 | UX & experience | Interaction models, onboarding, retention mechanics |
| 5 | Revenue & growth | Pricing, acquisition, monetization, upsell/expansion |

Each category gets 1 reserved iteration (forced breadth). Remaining iterations deepen high-signal categories. Saturation: net-new < 2 for 3 consecutive non-reserved iterations → stop.

---

## Product Context Resolution

Improve resolves product context automatically:

1. **Learn summary** (`autoresearch/learn-*/summary.md`) — best source, zero cost
2. **README.md** (≥500 chars, non-boilerplate) — extract description
3. **Package manifest** (package.json, pyproject.toml, Cargo.toml) — description field
4. **Auto-discover** — scans 10 key files when ALL above are absent

Use `--discover` to force a scan. Use `--no-discover` to skip it.

**Tip:** Run `/autoresearch:learn --mode summarize` first for best results.

---

## Feature Ranking

Improve uses tiered ranking, not numeric scores:

1. **ICP binary gate** — does this serve the stated ICP? yes/no
2. **3-tier bucketing** — Must-have / Nice-to-have / Moonshot
3. **Pairwise ranking** — within Must-have tier only (cap 7-10 items)
4. **2-sentence rationale** — citing research evidence
5. **Confidence indicator** — HIGH / MEDIUM / LOW per item

After ranking, you select which features become PRDs via multi-select.

---

## PRD Output

Each PRD includes:
- Problem statement with evidence chain
- User stories from ICP + persona data
- Requirements (MoSCoW prioritization)
- Acceptance criteria
- Technical approach (suggested starting points from codebase)
- Risks + confidence levels
- `DECISION NEEDED` markers for unresolvable tradeoffs
- `Open Questions` section

---

## Chain Integration

### Into improve (upstream)

```
/autoresearch:probe --improve       # constraints → ICP challenges + UX research
/autoresearch:predict --improve     # predictions → competitor gaps + revenue research
/autoresearch:debug --improve       # bug findings → competitor gaps research
/autoresearch:security --improve    # vulnerabilities → competitor gaps + ICP research
```

### From improve (terminal)

Improve is a **terminal emitter** — no downstream autoresearch chain. PRDs are consumed by external tools:

```
# After improve generates PRDs:
/ck:plan path/to/prd-feature.md     # plan implementation
/ck:cook path/to/plan.md            # implement the plan
```

---

## Output Structure

```
autoresearch/improve-{YYMMDD}-{HHMM}/
├── product-context.md           ← codebase evaluation (if --discover)
├── research-findings.md         ← all insights with citations + confidence
├── improvement-plan.md          ← tiered ranking with rationale
├── prd-{feature-1-slug}.md     ← individual PRD per selected feature
├── prd-{feature-2-slug}.md
├── summary.md                   ← overview + research stats
├── improve-results.tsv          ← iteration log
└── handoff.json                 ← chain integration (terminal)
```

---

## Examples

### Shallow scan for quick ideas

```
/autoresearch:improve
Goal: Quick improvement ideas for our dashboard
ICP: Data analysts at mid-market companies
--depth shallow
```

### Deep research with explicit ICP

```
/autoresearch:improve
Goal: Improve retention for our project management tool
--icp "Engineering managers at 100-500 person companies struggling with cross-team visibility"
--depth deep
Iterations: 30
```

### Chain from probe

```
/autoresearch:probe --improve
Topic: Improve checkout flow for enterprise B2B SaaS
--depth standard
```

probe interrogates requirements → improve researches improvements → generates PRDs.

---

## Tips

- **Run learn first** for best results: `/autoresearch:learn --mode summarize` gives improve rich product context at zero iteration cost.
- **Start with standard depth** (15 iterations). Shallow (5) misses categories; deep (30+) hits diminishing returns.
- **Use --seeds with chains** to override default category mapping when upstream findings don't match defaults.
- **LOW-confidence items** in PRDs are labeled "hypothesis" — verify independently before implementation.

---

## Related

- [/autoresearch:probe](autoresearch-probe.md) — surface requirements before improvement research
- [/autoresearch:learn](autoresearch-learn.md) — generate product context docs
- [/autoresearch:predict](autoresearch-predict.md) — expert analysis before improvement research
- [Chains & Combinations](chains-and-combinations.md) — multi-command pipelines
