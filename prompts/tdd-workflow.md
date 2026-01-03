# TDD Workflow with Transformation Priority Premise

You are implementing code using Test-Driven Development following the Transformation Priority Premise (TPP).

## Phase 1: Planning

Before writing any code, create a human-readable plan:

1. **Identify the goal** - What behavior are we implementing?
2. **List test cases** - Order them from simplest to most complex
3. **Map transformations** - For each test, identify the likely transformation needed

### Transformation Priority List (prefer higher over lower)

1. `({}->nil)` - No code to code returning nil/null/empty
2. `(nil->constant)` - Nil to a constant value
3. `(constant->constant+)` - Simple constant to more complex constant
4. `(constant->scalar)` - Constant to variable/argument
5. `(statement->statements)` - Add unconditional statements
6. `(unconditional->if)` - Split execution path
7. `(scalar->array)` - Single value to collection
8. `(array->container)` - Array to more complex container
9. `(statement->tail-recursion)` - Add tail-recursive call
10. `(if->while)` - Conditional to loop
11. `(statement->recursion)` - Add general recursion
12. `(expression->function)` - Replace expression with function
13. `(variable->assignment)` - Mutate a variable
14. `(case)` - Add case/else-if (LAST RESORT)

## Phase 2: Implementation

For each test case:

### Red
Write ONE failing test. Run it. Confirm it fails.

### Green
Make the test pass using the SIMPLEST transformation from the priority list.
- Prefer higher-priority transformations
- If stuck, you may have chosen wrong test order - backtrack

### Refactor
Clean up duplication without changing behavior.

### Commit
After each green phase, commit with this format:

```
[TPP] (transformation-name): Brief description

Tests:
[PASS] existing_test_1
[PASS] existing_test_2
[FAIL->PASS] new_test_name

Transformation: (nil->constant)
```

## Key Principles

1. **As tests get more specific, code gets more generic**
2. **One test, one transformation, one commit**
3. **Never skip ahead** - resist the urge to write the "final" solution
4. **Backtrack when stuck** - if a transformation seems too complex, reconsider test order
5. **Avoid (case)** - switch/case or else-if chains indicate wrong approach

## Language-Specific Notes

For languages that don't optimize recursion (Java, Python, JavaScript):
- Prefer `(if->while)` over `(statement->tail-recursion)`
- Prefer `(variable->assignment)` over parameter passing

For functional languages (Clojure, Haskell, Elixir):
- Prefer recursion over iteration
- Prefer immutable transformations
