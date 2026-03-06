Review all staged changes (`git diff --cached`) and generate a commit message.
## Rules
- Conventional Commits format: `<type>(<scope>): <subject>`
- Allowed types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- First line MUST be under 72 characters
- Subject uses imperative mood, lowercase, no trailing period
- Scope = affected module or directory (e.g. i2c, mipi, qemu, docs)
- If changes span multiple scopes, omit scope or use the dominant one
- Never include AI-attribution text
- Never append Signed-off-by or Co-authored-by lines
- Output the commit message only, no preamble
## Steps
1. Run `git diff --cached --stat` to identify changed files
2. Run `git diff --cached` to read the actual diff
3. Determine the best `type` and `scope` from the diff
4. Write a concise subject summarizing the intent (not the mechanics)
5. If the change is non-trivial, add a blank line then a body:
   - Wrap body lines at 72 characters
   - Explain *what* and *why*, not *how*
   - Use bullet points for multiple logical changes
6. Run `git commit -m "<message>"` to commit
If no files are staged, run `git status` and report what's available to stage.
