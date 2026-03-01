---
name: writing-code
description: Code writing best practices and strategies for effective development
---

1. First things first: always start with a clear plan. Write out the steps you intend to take in `tasks/YYYYMMDD-<title>/todo.md` before you write any code. This helps you stay organized and focused.
2. Second thing: You should write tests before you write the implementation code. This test-first approach ensures that you have a clear specification to work towards and helps catch issues early.
    - Rust: Use `#[test]` functions in your modules to define tests. Run them with `cargo test`.
    - Python: Use `unittest` or `pytest` to write test cases. File Directory should be structured with a `tests/<module_name>/test_<file_name>.py` pattern about `src/<module_name>/<file_name>.py`. Basecally, run script with `uv run` not `python` or `python3` directly.
    - Typescript: Use `jest` or `mocha` for testing. Place tests in a `__tests__` directory or alongside the implementation files with a `.test.ts` suffix.
3. Always verify your work before marking a task as complete. Run your tests, check logs, and ensure that your code behaves as expected. If you can prove it works, then you can confidently mark it as done.
4. Don't be afraid to ask yourself if there's a more elegant solution before you implement a fix. If a solution feels hacky, take a moment to think about how you can implement it in a cleaner way. However, don't over-engineer simple fixes — balance elegance with practicality.
5. When you receive a bug report, take the initiative to fix it directly. Diagnose the issue using logs, errors, and failing tests on your own. This proactive approach minimizes context-switching for the user and helps you develop your debugging skills.
6. Always keep a self-improvement loop. After receiving a correction, log the pattern in `tasks/lessons.md` and write rules for yourself to avoid repeating the same mistakes. Review these lessons at the start of each session to keep them fresh in your mind.
7. Setting lefthook and CI hooks can help you maintain code quality and consistency. Use pre-commit hooks to run linters, formatters, and tests before allowing commits. This ensures that your codebase remains clean and that issues are caught early in the development process.
