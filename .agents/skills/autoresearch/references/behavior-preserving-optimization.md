# Behavior-Preserving Performance Optimization

Load this reference when the objective is performance, latency, throughput,
runtime, CPU, memory, allocations, binary size, power, energy, bandwidth, or
compute cost and the system must keep doing the same useful job.

## Separate the Search Signal from Acceptance

The metric being optimized cannot also prove behavior preservation. A candidate
can become faster by skipping work, narrowing inputs, lowering quality, moving
cost elsewhere, or changing timing outside the benchmark's view.

Before the baseline, define:

- the performance objective, workload, measurement method, and smallest useful
  gain;
- user-visible, protocol, perceptual, or numerical behavior that must remain;
- independent behavior checks that reject at least one known-bad change;
- resource boundaries for memory, startup, energy, bandwidth, deadline misses,
  and tail latency where relevant;
- comparable artifact, configuration, hardware, and input provenance;
- representative inputs for search and separate held-out or adversarial inputs
  for confirmation;
- a rollback point.

If a guard was chosen mainly because it is easy to keep green, replace it.

## Run Two Loops

Use the normal autoresearch loop for exploration. Reversible batches may locate
promising directions, and the working metric may rank them. A `keep` decision
means only "better exploratory incumbent"; it does not establish causality or
readiness.

Confirm each promising direction before calling it behavior-preserving:

1. Rebuild it as an isolated, reviewable change.
2. Re-run the objective and independent behavior checks on representative plus
   held-out or adversarial workloads.
3. Compare end-to-end and tail costs, not only the edited function or average.
4. Reject the candidate when any behavior or resource boundary fails.
5. Preserve raw baseline/candidate evidence and comparable provenance.
6. Record unmeasured behavior and the rollback path.

## Resist Proxy Success

A green metric or guard proves only that the declared observations passed. It
does not prove that the observations represent the user's real objective, that
the measurements are truthful, or that no important behavior is missing.

Before final acceptance, a reviewer should be able to identify the causal
change, inspect the raw evidence, see an independent check reject a known-bad
case, and explain what remains unmeasured.

Reject these arguments:

- "The benchmark is much faster, so the change is good."
- "The outputs look close enough."
- "The guard passed, so behavior is preserved."
- "We can isolate the five tweaks after they land."
- "The benchmark input is representative by definition."
