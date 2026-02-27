## Workflow Design

### 1. Plan Mode as Default
- Always start in Plan mode for tasks with 3+ steps or architectural decisions
- If things go sideways, stop immediately and re-plan rather than pushing through
- Use Plan mode not just for building, but also for validation steps
- Write detailed specs before implementation to reduce ambiguity

### 2. Sub-Agent Strategy
- Actively use sub-agents to keep the main context window clean
- Delegate research, investigation, and parallel analysis to sub-agents
- Throw more compute at complex problems by spinning up sub-agents
- One task per sub-agent for focused execution

### 3. Self-Improvement Loop
- After receiving a correction, always log the pattern in `tasks/lessons.md`
- Write rules for yourself to avoid repeating the same mistakes
- Keep refining the rules until the error rate drops
- At the start of each session, review lessons relevant to the current project

### 4. Always Verify Before Closing
- Never mark a task complete until you can prove it works
- Diff against the main branch to confirm your changes when needed
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, and demonstrate correct behavior

### 5. Pursue Elegance (in balance)
- Before making significant changes, pause and ask: "Is there a more elegant approach?"
- If a fix feels hacky, think: "Given everything I now know, implement an elegant solution"
- Skip this process for simple, obvious fixes — don't over-engineer
- Self-critique your work before presenting it

### 6. Autonomous Bug Fixing
- When you receive a bug report, fix it directly — don't wait to be walked through it
- Diagnose from logs, errors, and failing tests on your own
- Zero context-switching for the user
- Proactively fix failing CI tests without being asked

### 7. Test-First Development
- **Write the test first, watch it fail, then implement** — never write implementation code before a failing test exists
- Treat a red test as a precise, executable specification; don't touch production code until you have one
- Keep the feedback loop tight: fail → implement the minimum code to pass → refactor
- One failing test at a time; resist the urge to batch multiple assertions before any pass
- If a test passes without any implementation changes, the test is wrong — fix the test
- Commit (or checkpoint) at each green state so regressions are immediately obvious
- Test names should read like plain-English requirements (e.g., `test_rejects_expired_token`)
- Mock at the boundary, not in the middle — fake external systems, not internal logic

---

## Task Management

1. **Plan first**: Write the plan in `tasks/todo.md` as checkable items
2. **Confirm the plan**: Review before starting implementation
3. **Track progress**: Check off items as they are completed
4. **Explain changes**: Provide a high-level summary at each step
5. **Document outcomes**: Add a review section to `tasks/todo.md`
6. **Capture learnings**: Update `tasks/lessons.md` after receiving corrections

---

## Core Principles

- **Simplicity first**: Make every change as simple as possible. Minimize the code affected.
- **No shortcuts**: Find the root cause. Avoid temporary fixes. Hold yourself to a senior engineer's standard.
- **Minimize blast radius**: Change only what needs to change. Don't introduce new bugs.

