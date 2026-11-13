# Rulesets

The repository rulesets, defined as JSON so that changes to them go through review.

GitHub doesn't apply these files by itself.
After a change merges, a maintainer applies it with the API.

## What `protect_main.json` enforces

- `main` can't be deleted or force-pushed.
- Commits must be signed.
- Changes arrive through a pull request, merged with a merge commit.
  Squash and rebase merges aren't allowed, because they break commit signatures.
- No approving review is required, because the repository has one maintainer.
- The CI jobs `Format`, `Lint`, `Evaluate flake` and `Build and test` must pass, and the branch must be up to date with `main` before merging.
  Each check is tied to the GitHub Actions app, so another app can't report a pass.
  Add a new job here only after it has reported on `main`, since a required check that never reports blocks every merge.

## Applying a change

The API call needs administration access to the repository, so CI doesn't do it.
Use a fine-grained personal access token limited to this repository, with:

- read access to metadata
- read and write access to administration

Create the ruleset the first time:

```sh
curl -L -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/huwd/immurok-nix/rulesets \
  -d @.github/rulesets/protect_main.json
```

Find the ruleset ID with `GET /repos/huwd/immurok-nix/rulesets`.
Update an existing ruleset with `PUT` to `/repos/huwd/immurok-nix/rulesets/{id}` and the same `-d @` argument.
Afterwards, compare the result in the repository's settings under Rules.
