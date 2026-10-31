# Fork-and-Flush

How a metric loop gets out of an idea basin. Sources: Cai et al., "Fork-and-Flush: Escaping Idea Basins in
Autoresearch Agents" ([arXiv:2610.07447](https://arxiv.org/abs/2610.07447)), for the random branches, and Zhang et
al., "Stateless Language Agents: Scaling Long-Horizon Automated Research"
([arXiv:2610.07625](https://arxiv.org/abs/2610.07625)), for the guided branches.

## Contents
- Why
- Random and guided branches
- When to run a round
- One round
- Advisor
- Orchestrator
- Cost
- Opt out

## Why

A single loop keeps improving inside one family of ideas (an idea basin) and plateaus there. Its own chat
context holds it there: every new idea is reasoned from the old ones. Compaction does not fix this.

Two moves get it out, and they work best together:

- **Flush**: start a new agent from the files only, with no chat history. It has to work out the intent again
  from the artifacts, which is what lets it land in a different basin.
- **Fork**: run several of those fresh agents from the same state and keep the best one.

Paper results, 13 tasks, matched budget (normalized score):

| Single run | Best-of-4 | Flush only | Fork only | Fork-and-flush |
|---|---|---|---|---|
| 0.47 | 0.54 | 0.55 | 0.57 | 0.78 |

The flush-only and fork-only numbers come from the ablation, which ran on 11 of the 13 tasks.

## Random and guided branches

A round splits its K branches into two kinds:

| Kind | Told | Brings |
|---|---|---|
| **Random** | Nothing beyond the task. Works out what to try from the files. | Randomness: each fresh agent can land in a basin nobody planned for (fork-and-flush). |
| **Guided** | One concrete experiment, chosen by a stateless Advisor from the results so far. | Coverage: no two branches spend their budget on the same idea, and none repeats a logged failure (stateless agents). |

`Guided: R` sets the guided fraction. Guided branches = `floor(K × R)`; the rest are random. Default R = 0.5.

| K | R = 0.5 | R = 0 | R = 1 |
|---|---|---|---|
| 4 | 2 random + 2 guided | 4 random (fork-and-flush as published) | 4 guided |
| 3 | 2 random + 1 guided | 3 random | 3 guided |
| 2 | 1 random + 1 guided | 2 random | 2 guided |

Keep at least one random branch unless you have a reason not to. Random branches are the only source of ideas
the Advisor would not think of.

## When to run a round

In a metric loop, run rounds on a **fixed schedule**, not when a plateau is detected. The paper tried plateau triggers and
dropped them: small gains keep resetting the stall clock, so a loop creeping upward inside one basin never
triggers, and 15 of 25 plateau-triggered runs used up their budget before the trigger fired.

| Mode | Rounds |
|---|---|
| Bounded, N ≥ 12 iterations | after 33% and 66% of N |
| Bounded, N < 12 | one round, at 50% of N |
| Unbounded | every 20 iterations |

The orchestrator has no fixed iteration budget, so it uses its plateau signal instead (see Orchestrator below).

**Early trigger:** also run a round when 5 iterations since the last `keep` or the last round produced no `keep`. Each early round replaces
the next scheduled one, so the total number of rounds does not grow.

## One round

1. **Protect the incumbent.** The incumbent is the commit with the best metric so far. Tag it
   (`git tag -f autoresearch/incumbent <sha>`). No branch may revert or overwrite it.
2. **Fork K branches.** Default K = 4, split into random and guided branches by `Guided: R`. Use K = 2 when one Verify run takes more than about 5 minutes, or when
   it needs a single shared resource such as one local stack or one test database. In that case run the
   branches one after another.
   - Each branch is a fresh-context sub-agent in its own git worktree, starting at the incumbent. In Claude
     Code: the `Agent` tool with `isolation: "worktree"`, one call per branch, all in one message when they can
     run in parallel. On other platforms: whatever starts a sub-agent with an empty conversation, on its own
     checkout.
   - Branch budget: `max(2, round(0.06 × N))` iterations, where N is the loop's total iterations. Unbounded
     loops use 2.
3. **Ask the Advisor** (skip when there are no guided branches). One stateless call returns one experiment per
   guided branch. See Advisor below.
4. **Flush: what a branch is told.**
   - Give it: Goal, Scope, Metric, Direction, Verify, Guard, its iteration budget, the path of the results TSV,
     and the rule that the incumbent tag is protected.
   - A guided branch also gets its assigned experiment. Its first iteration tests that experiment. If it is
     kept, later iterations build on it; if not, the branch continues freely for the rest of its budget.
   - Do not give it: the leader's hypotheses, plans, ranking of ideas, or a summary of the conversation. The
     results TSV and `git log` are artifacts, so the branch may read them. That is the "files" half of
     fork-and-flush.
   - Do not tell random branches to "try something completely different". In the paper that directive had no
     measurable effect on which branch won. A concrete assignment is a different thing: in the stateless-agents
     paper, explicit experiment assignments helped.
5. **Each branch runs the core loop** (Phases 1–7) on its own branch, and returns its best metric and its kept
   commits.
6. **Select.** The branch with the best metric wins. On a tie with the incumbent, the branch still wins,
   because its context is fresh.
   - Bring the winner's kept commits onto the loop branch (fast-forward or cherry-pick). Discard the other
     branches and remove their worktrees.
   - If no branch beat the incumbent, the loop branch stays at the incumbent, and the winner's context still
     becomes the leader.
7. **Hand over leadership.** The winning branch's agent continues as the leader until the next round. In Claude
   Code, resume it with `SendMessage` so its context carries on. If the platform can't resume it, the main agent
   continues, but only after re-reading the TSV and `git log`, and it treats its own earlier hypotheses as
   stale.
8. **Log.**
   - One TSV row per branch with status `fork-{k}`, carrying that branch's best metric. Start the description
     with `random:` or `guided: <experiment>`.
   - One row with status `fork-select`, naming the winner, its kind, and whether it beat the incumbent.

The loop's final result is the best metric any branch or the leader ever reached, not the leader's last value.

## Advisor

A fresh-context sub-agent, called once per round before the branches start. It plans; it never edits files.

- **Reads:** Goal, Scope, Metric, Direction, the results TSV, `git log`, and the incumbent's diff against the
  baseline. Not the leader's conversation, hypotheses, or plans: the Advisor is flushed too.
- **Returns:** exactly one experiment per guided branch. Each is one change, stated concretely enough to make in
  one iteration (what to change, where, and the expected effect on the metric).
- **Rules:** the experiments differ from each other, and none repeats a change the TSV already records as
  `discard`, `crash`, or `metric-error`. Prefer directions the TSV shows as untried or under-explored over more
  tuning of what already worked.

Over a run, compare wins by kind in the `fork-select` rows. If one kind never wins, move R toward the other.

## Orchestrator

The branch Metric is units remaining (lower is better) and Verify is the confirmed predicate command, so the round works for every archetype.

When `orchestrate.sh plateau` exits 0 (flat), run one round from the incumbent while
`fork_rounds_since_progress` is below 2, add 1 to it, and continue the loop. Reset it to 0 whenever units
improve. Once 2 rounds pass with no progress, stop and report `PLATEAU`. `orchestrate.sh verdict` follows
the same rule: it answers `FORK` while rounds remain and `PLATEAU` after. Under `--no-fork`, skip the rounds
and treat `FORK` as `PLATEAU`.

## Cost

A round costs about K × 6% of the budget. The Advisor adds one short call per round; in the stateless-agents
paper the Advisor used under 0.6% of all tokens. The paper spends roughly 72% of the budget on branches (an opening
round plus two scheduled rounds) and still beats a single run at the same total cost. When Verify is expensive,
use K = 2 rather than skipping rounds: flushing alone recovers about half of the gain.

## Opt out

Use `--no-fork` when the loop is a mechanical sweep with no ideas to get stuck on, for example a parameter grid
or a list of known fixes worked through in order.
