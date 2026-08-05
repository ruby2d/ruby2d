# Preparing a release

Run `rake release`. It prints the release checklist, marks off every step it can verify for itself, and walks the rest with you in order:

```
  ◆ Ruby 2D 1.0.0 — release checklist

    ✓  1. Assets submodule carries every platform  3 platforms
    ○  2. On `main` with a clean working tree  on `sdl3`, 2 uncommitted files
    ○  3. Built, installed, and tested  no run recorded against this commit
    ○  4. Verified on every platform  1 of 4
    ○  5. Version set to a release version  1.0.0.dev
    ○  6. Tagged and announced as v1.0.0
    ○  7. Published to RubyGems
    ○  8. "Try Ruby 2D" synced to ruby2d.com
    ✓  9. Published examples synced to ruby2d.com
    ○ 10. Version back to a `.dev` version
```

The task does the reversible work itself: bumping the version, building and testing the gem, building the "Try Ruby 2D" page and refreshing the examples in the ruby2d.com checkout next door. For anything that leaves the machine — the GitHub release, `gem push`, committing the site — it prints the exact command and waits, so publishing stays a decision you make.

Stop any time with Ctrl-C. Nearly every ✓ is derived from the tree, from git, from origin, or from rubygems.org rather than remembered, so the next `rake release` picks up exactly where the last one left off. The two that can't be derived — a passing test run and a platform verified by hand — are recorded against the commit they were confirmed at, in a gitignored `.release-state`; a later commit retires them unless it touched nothing but `version.rb`.

Steps 5 and 10 are the two that end the run: both rewrite `lib/ruby2d/version.rb`, and the version this run was reasoning about is now stale, so they hand back with a commit to make and ask for a fresh `rake release`.

If the ruby2d.com repo isn't checked out alongside this one, point the task at it: `RUBY2D_COM=/path/to/ruby2d.com rake release`.

## Why the steps are in that order

Step 2 gates on being on `main` with nothing uncommitted. Both are the same question — is this repo in a state you can release from — and both matter for the same reason: the gem is packed from the working tree rather than from git, and the tag lands on whatever branch you're standing on. Prepare a release anywhere you like, but merge to `main` before step 2 will pass. (Releasing from somewhere else is a one-line change: `RELEASE_BRANCH` in the [`Rakefile`](Rakefile).)

Testing comes before the version bump, so a platform that fails costs a re-test rather than leaving a stray "Version 1.0.0" commit in the history. The bump is step 5 and the last commit before the tag.

Tag and announcement are one step because publishing a GitHub release is what creates the tag; the marker and the notes land together, and there's no separate `git tag` to forget. That's also why the checklist looks for the tag on `origin` rather than asking `gh`: the tag being there is the evidence, and it works whether or not `gh` is installed. It compares the tag's commit against the one checked out, not just its existence: a release published before the version-bump commit was pushed leaves a tag that doesn't contain the code the gem was built from.

The RubyGems push comes after both. It's the one step that can't be undone — a pushed version can be yanked, but the number is never reusable — so everything reversible happens above it, and the commit a release was built from is public before the artifact is.

The two ruby2d.com steps come last because the site follows the release, not the other way round.

## What the examples sync will and won't do

Step 9 refreshes the example sources ruby2d.com renders from, in `_includes/examples/`. It updates only the files already there. It never adds one and never deletes one.

That's deliberate: not every example behaves in a browser, so the site publishes a curated subset, and deciding what belongs in it is a judgement about the web that sits with the site rather than with a release task. Drop an example from the site because it misbehaves and the sync will leave it dropped.

The two kinds of drift it can't settle are reported rather than acted on: examples the site still carries that have been deleted from `examples/`, and examples here the site doesn't publish. Both are yours to resolve in the site repo; neither holds the release up.

## Why the version carries `.dev`

Between releases, `VERSION` is a `.dev` version (e.g. `1.0.0.dev`) so a copy installed from source is clearly distinct from a published gem. Step 5 takes it off; step 9 puts the next one on and closes the release out. `rake release` offers to make both edits for you.

The whole checklist is framed in terms of the version being *released*: `1.0.0.dev` prepares `1.0.0`, so the header, the tag, the gem filename, and the recorded ticks all say `1.0.0` from the first run. That's what lets the ticks from steps 3 and 4 survive step 5's bump instead of being stranded under the old number. A commit touching nothing but `version.rb` is the one commit that doesn't retire them.

## Test platforms

Step 4 is the one part of a release nothing on this machine can vouch for. On each platform, with the latest Ruby installed, run all four:

- `rake` — full build, install, and RSpec
- `rake test:all` — manually verify each interactive test (press Esc to advance)
- `rake test:all native` — the same, built as native executables
- `rake test:all web` — the same, served as web apps (press Enter in the terminal to advance)

The platforms themselves are listed in `RELEASE_TEST_PLATFORMS` in the [`Rakefile`](Rakefile), which is where the checklist reads them from. Windows on ARM counts once but needs both terminals: install RubyInstaller's Ruby+Devkit for `arm64` and for `x64`, and run the four commands in each.

Nothing aggregates these ticks across machines: `.release-state` is local, so you confirm all four on the machine you're releasing from, once you've actually run the tests on each box. The prompts default to no, and the release can't move past step 4 until every platform is ticked.

## Updating bundled dependencies

To bump the bundled SDL3 versions or refresh other vendored assets:

1. Update the [assets](https://github.com/ruby2d/assets) repo, following the instructions in its README
2. Run `rake update` from this repo to sync the submodule

Step 1 of the checklist guards this: the gem bundles prebuilt libraries per platform, and a platform directory missing from the submodule doesn't fail the build; it just quietly ships a gem without support for that target. It covers `wasm` alongside the three native platforms, since `assets/platform/wasm/lib` is what `ruby2d build --web` links against.
