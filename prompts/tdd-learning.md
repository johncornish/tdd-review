# TDD Review Feedback Integration

You are receiving feedback from a human review of your TDD commits.

## Feedback Format

The feedback follows this structure:

```
# TDD Review Feedback

## Commit: abc123 - [TPP] (nil->constant): Return empty list
**Flag**: TPP violation: should have used (unconditional->if)

## Commit: def456 - [TPP] (if->while): Add loop
**Flag**: commit too large: combined two transformations
```

## How to Process Feedback

### 1. Acknowledge Each Issue

For each flagged commit, explain:
- What you did
- Why it was flagged
- What you should have done instead

### 2. Identify Patterns

Look for recurring issues:
- Skipping transformation priorities?
- Commits too large?
- Tests in wrong order?

### 3. Adjust Approach

Based on feedback, state what you will do differently:
- Smaller steps?
- Different test ordering?
- Stricter adherence to priority list?

## Common Flags and Corrections

### "TPP violation"
You used a lower-priority transformation when a higher one was available.
- Review the priority list
- Consider if test order forced a complex transformation

### "commit too large"
Multiple transformations in one commit.
- Each transformation = one commit
- If refactoring, that's a separate commit

### "test unclear"
Test name or assertion doesn't communicate intent.
- Test names should describe behavior, not implementation
- One clear assertion per test

### "missing test"
Behavior added without corresponding test.
- Never write production code without a failing test first
- Each behavior needs its own test

## Recovery Actions

After processing feedback:

1. **If commits need rework**: Propose how to redo the sequence
2. **If approach was wrong**: Suggest revised test order
3. **If continuing**: Apply lessons to remaining work

## Example Response

```
## Feedback Received

### Commit abc123 - TPP violation
I used (statement->recursion) but should have used (if->while).
The test was checking iteration behavior, and since this is JavaScript,
iteration is preferred over recursion.

### Commit def456 - commit too large
I added both the loop AND array handling in one commit.
These should have been:
1. (if->while) - add the loop
2. (scalar->array) - handle multiple items

## Adjustments

For remaining work, I will:
- Check if iteration can solve the problem before reaching for recursion
- Commit after each single transformation
- Review the priority list before choosing a transformation
```
