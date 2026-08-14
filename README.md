# Raft Consensus Algorithm in Ada

## Project Overview
This project implements the core logic and state machine of the **Raft consensus algorithm** natively in Ada. Raft is designed as a distributed consensus protocol providing leader election, log replication, and safety. This implementation focuses heavily on single-node logical responses to remote procedure calls (RPCs) and internal timeouts, maintaining strict deterministic state transitions.

## Features
- **Leader Election Mechanism:** Implements the state transitions from Follower -> Candidate -> Leader based on election timeouts.
- **Log Replication:** Correctly evaluates `PrevLogIndex` and `PrevLogTerm` for consistency before allowing `AppendEntries` success.
- **RPC Handlers:**
  - `Handle_Request_Vote`: Manages term checking, log up-to-date validation, and preventing double voting.
  - `Handle_Append_Entries`: Validates leader heartbeat, advances commit indices, and manages replication.
- **Strong Typing Integration:** Employs Ada's native bounds checking and type safety for Node IDs, Term IDs, and Log Arrays.

## Testing
This repository adopts a rigorous Verification and Validation (V&V) philosophy. The tests in `tests.adb` operate strictly under the assumption that the codebase is fundamentally broken until actively disproven by the test assertions.

### What the tests verify:
- **Functional Correctness (State Transitions):** Tests 1, 2, 3, 8 verify that `Tick()` advances elections and majorities elect leaders.
- **Edge Cases & Rule Validation:** Tests 5, 6, 7 prevent duplicate voting, force rejection of stale terms, and ensure stepping down when confronted with higher terms.
- **Log Consistency (Error Handling):** Tests 11, 12, 13 verify that logs correctly handle missing gaps by rejecting mismatched `PrevLogIndex` inputs and safely replicating valid sequential chains.

### Why these tests matter:
In critical systems (where Ada is most often utilized), consensus errors lead to split-brains, data loss, or cascading system faults. By verifying exact compliance with the Raft paper specification, we validate that the node behaves reliably in faulty network environments, establishing safety guarantees.

### How tests prove the code works:
We inject intentional "worst-case" inputs (e.g., mismatched logs, older leader terms, election timeouts triggering multiple times) expecting system failure. A `PASS` explicitly disproves the initial pessimistic assumption by proving the code successfully mitigated the bad inputs and transitioned to the appropriate resilient state.

## Usage

### Compilation
The project requires a standard GNAT Ada compiler (`gnatmake`). A Makefile is provided to streamline the build process. All source files reside in the root directory.

To compile:
```bash
make
