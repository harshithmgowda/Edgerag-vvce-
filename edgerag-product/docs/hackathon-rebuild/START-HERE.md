# Start here: sequential GitHub build

Use these NEW prompts instead of the earlier parallel-team prompts:
1. SEQUENTIAL-01-backend.md — Member 1 builds the backend/RAG, documents the API and package contract, tests and pushes.
2. SEQUENTIAL-02-web.md — Member 2 pulls Member 1's work, makes the AI read it, builds the website, verifies integration and pushes.
3. SEQUENTIAL-03-mobile.md — Member 3 pulls everything, makes the AI read both earlier handoffs and code, adds Android, tests the full workflow and pushes.

Give each member the entire appropriate prompt file. Member 1's contract lives in the repository; later members follow the actual implementation rather than independently guessing it.

Use a NEW rebuild repository/folder to preserve your current project. Use one agreed integration branch. Share the repository URL, branch and final commit SHA at each handoff. If using PRs, merge the preceding phase before the next person pulls.

First checkout:
git clone <REPOSITORY_URL>
cd <REPOSITORY_FOLDER>
git switch <AGREED_BRANCH>

Existing clean checkout:
git status
git switch <AGREED_BRANCH>
git pull --ff-only

Do not paste angle-bracket placeholders unchanged. If the checkout contains uncommitted work or the pull reports divergence, inspect it and preserve that work; do not reset or force-push.

Sequence:
Backend -> GitHub -> Website added to backend -> GitHub -> Android added to both -> Final demo.

Start model downloads and Android SDK installation early: those preparations do not require simultaneous coding. Keep image/audio/video tools as stretch features after the core workflow works.

These prompts rebuild the same core product and explicitly fix known prototype issues. They cannot guarantee the entire original feature set will fit into one day.
