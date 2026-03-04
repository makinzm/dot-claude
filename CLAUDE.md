## Workflow Design

### 1. Plan Mode as Default
- Always start in Plan mode for tasks with 3+ steps or architectural decisions
- If things go sideways, stop immediately and re-plan rather than pushing through
- Use Plan mode not just for building, but also for validation steps
- Write detailed specs before implementation to reduce ambiguity

### 2. Self-Improvement Loop
- After receiving a correction, always log the pattern in `tasks/lessons.md`
- Write rules for yourself to avoid repeating the same mistakes
- Keep refining the rules until the error rate drops
- At the start of each session, review lessons relevant to the current project

### 3. Pursue Elegance (in balance)
- Before making significant changes, pause and ask: "Is there a more elegant approach?"
- If a fix feels hacky, think: "Given everything I now know, implement an elegant solution"
- Skip this process for simple, obvious fixes — don't over-engineer
- Self-critique your work before presenting it

### 4. Autonomous Bug Fixing
- When you receive a bug report, fix it directly — don't wait to be walked through it
- Diagnose from logs, errors, and failing tests on your own
- Zero context-switching for the user
- Proactively fix failing CI tests without being asked

### 5. Test-First Development

When writing code, you should check the skill about `writing-code` for best practices on how to write code effectively. Always write tests before writing the implementation code. This test-first approach ensures that you have a clear specification to work towards and helps catch issues early.

## Process Principles

1. Always create a new branch if it is main. Don't work directly on main to avoid breaking the build and to keep the history clean. Use descriptive branch names that reflect the task or feature you're working on.
2. Always create log timeline for reviewer to check `tasks/YYYYMMDD-<title>/timeline.md`. This helps reviewers understand the context and the steps you took to arrive at your solution. It also provides a record of your thought process and any challenges you encountered along the way.
3. Always write a test code first before writing the implementation code. This test-first approach ensures that you have a clear specification to work towards and helps catch issues early. It also promotes better design and helps you think through the requirements before diving into coding. Then, you should add a error log to timeline for reviewers to check if you implement tests first and what error you encounter before writing implementation code.
4. Write codes.
5. Refactor and optimize your code after you have a working implementation. Don't worry about making it perfect on the first try — focus on getting something that works, then iterate to improve it. This allows you to get feedback early and make adjustments as needed without getting stuck on trying to write perfect code from the start.
6. Always create a process for your tests or something similar to run automatically on CI.


## Core Principles

- **Simplicity first**: Make every change as simple as possible. Minimize the code affected.
- **No shortcuts**: Find the root cause. Avoid temporary fixes. Hold yourself to a senior engineer's standard.
- **Minimize blast radius**: Change only what needs to change. Don't introduce new bugs.

