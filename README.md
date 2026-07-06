# ⚽ IWinWorldCup2K26

A decentralized peer-to-peer football betting protocol built on Ethereum.

IWinWorldCup2K26 enables users to create prediction pools for football fixtures, place bets on outcomes, settle results through an authorized forwarder, and claim winnings in a transparent and trust-minimized manner.

---

## Features

* Fixture creation by contract owner
* Create prediction pools
* Place bets on:

  * Team A Win
  * Team B Win
  * Draw
* Betting deadlines
* Match result requests
* Authorized CRE result finalization
* Automatic payout distribution
* Match cancellation handling
* Refund mechanism
* Protocol fee collection
* Protocol fee withdrawal
* Betting deadline extensions
* Event emission support
* Fuzz testing
* Gas profiling

---

## Tech Stack

* Solidity `0.8.33`
* Foundry
* OpenZeppelin
* Forge Std
* Ethereum
* Sepolia Testnet

---

## Contract Overview

### Workflow

```text
Owner creates Fixture
        ↓
User creates Bet Pool
        ↓
Other users place Bets
        ↓
Betting closes
        ↓
Match ends
        ↓
Result requested
        ↓
CRE finalizes outcome
        ↓
Winners claim rewards
        ↓
Protocol fees collected
```

---

## Testing

The project currently includes:

### Unit Tests

* Fixture creation
* Ownership checks
* Betting validation
* Deadline validation
* Result requests
* Result finalization
* Winner claims
* Refunds
* Protocol fees
* Deadline extension logic
* Event emissions
* Access control

### Fuzz Tests

* Arbitrary bet amounts
* Multiple bettors
* Payout invariants

Current status:

```bash
43 tests passed
3 fuzz tests passed
0 failures
```

Run tests:

```bash
forge test
```

Run fuzz tests:

```bash
forge test --match-test testFuzz -vvv
```

Generate coverage:

```bash
forge coverage
```

Generate gas report:

```bash
forge test --gas-report
```

---

## Gas Analysis

Deployment:

```text
Deployment Cost : 1,720,987 gas
Deployment Size : 7,486 bytes
```

Average execution costs:

| Function             | Avg Gas |
| -------------------- | ------: |
| createBet            | 253,659 |
| placeBet             |  89,231 |
| claimWinnings        |  92,130 |
| refund               |  52,510 |
| requestMatchResult   |  56,854 |
| finalizeMatchResult  |  60,780 |
| withdrawProtocolFees |  30,409 |

---

## Security Considerations

Implemented protections:

* ReentrancyGuard
* Checks-Effects-Interactions pattern
* Access control modifiers
* Custom errors
* Protocol fee accounting
* Double claim protection
* Cancellation and refund logic

---
## Trust Model

IWinWorldCup2K26 integrates with Chainlink CRE.

Match results are accepted only when submitted through an authorized Keystone Forwarder and validated against:

- Expected Workflow ID
- Expected Workflow Author
- Expected Workflow Name
- Chain Selector
- Replay-protected Nonce

This design significantly reduces owner trust assumptions and mitigates malicious result injection attacks.

## Project Structure

```text
src/
 └── IWinWorldCup2K26.sol

test/
 └── IWinWorldCup2K26Test.t.sol

docs/
 └── IWinWorldCup2K26GasReport.md
```

---

## Future Improvements

* Chainlink integration
* Automated oracle settlement
* Frontend dashboard
* Betting statistics
* Tournament support
* Multi-match betting
* Deployment scripts
* Mainnet readiness review

---

## Author

Muyimbi

Built with Solidity, Foundry and a passion for decentralized sports prediction markets.

---

## License

MIT
