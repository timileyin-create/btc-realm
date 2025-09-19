# BTCRealm - Decentralized Adventure Protocol

**Bitcoin-native gaming ecosystem on Stacks Layer 2 enabling immersive realm exploration with time-locked challenges and satoshi-backed reward distribution.**

---

## 📖 Overview

BTCRealm is a **decentralized adventure protocol** designed for the **Stacks Layer 2** ecosystem, leveraging Bitcoin’s finality and security.
Players engage in **time-gated dungeon challenges**, pay entry fees, and earn **provably fair satoshi-backed rewards**.

This contract introduces a **trustless game loop** where participation, cooldowns, and rewards are enforced entirely on-chain, without intermediaries.

---

## 🎮 System Overview

* **Realm Exploration**: Players enter dungeons, constrained by cooldowns, ensuring fairness.
* **Tokenized Economy**: Entry fees and rewards are managed in a Bitcoin-pegged fungible token (via Stacks SIP-010).
* **Provable Fairness**: All validations (entry, cooldown, completion, rewards) are enforced by Clarity smart contracts.
* **On-Chain Statistics**: Both player and global statistics are recorded and queryable for transparency.
* **Secure Ownership Controls**: Two-step contract ownership transfer and emergency reset functions.

---

## 🏗️ Contract Architecture

### **Traits**

* **`token-trait`** – Defines standard token interactions (`get-balance`, `transfer`). Ensures interoperability with SIP-010 compliant tokens.

### **Core Constants**

* `ENTRY-COST` – Fee to enter a dungeon.
* `REWARD-AMOUNT` – Reward for successful dungeon completion.
* `DUNGEON-COOLDOWN-BLOCKS` – Block interval between dungeon entries per player.
* `MAX-DUNGEONS-PER-PLAYER` – Cap on player participation.

### **State Variables**

* **Ownership & Control**: `contract-owner`, `pending-owner`, `game-active`.
* **Game Token**: `allowed-token` (only one fungible token allowed at a time).
* **Player State**: `player-dungeon-stats` stores per-player engagement and progress.
* **Global Stats**: `game-stats` tracks total entries, completions, rewards distributed.

### **Game Loop Functions**

* **`enter-dungeon`**

  * Validates token balance, cooldown, and active state.
  * Records dungeon entry and updates statistics.

* **`complete-dungeon`**

  * Validates entry, active dungeon state, and reward availability.
  * Transfers rewards to player and updates statistics.

### **Read-Only Queries**

* `get-player-stats` – Full history of player engagement.
* `can-enter-dungeon` – Checks cooldown and eligibility.
* `get-game-stats` – Returns aggregated global metrics.
* `get-game-config` – Exposes contract parameters.
* `get-ownership-info` – Displays current and pending owners.

### **Administrative Controls**

* `toggle-game-state` – Enables or pauses gameplay.
* `set-allowed-token` – Updates the fungible token for rewards.
* `emergency-reset-player` – Clears a specific player’s state.
* **Ownership Lifecycle**: `initiate-ownership-transfer`, `accept-ownership`, `cancel-ownership-transfer`.

---

## 🔄 Data Flow

1. **Entry Phase**

   * Player calls `enter-dungeon` with allowed token.
   * Contract validates token balance, cooldown, and active game state.
   * Player marked as *in dungeon*.

2. **Completion Phase**

   * Player calls `complete-dungeon`.
   * Contract validates player status.
   * Reward tokens are transferred.
   * Player stats updated, marking dungeon completed.

3. **Statistics Updates**

   * Global stats incremented on entry and completion.
   * Player stats persist across sessions for transparency.

---

## ⚙️ Example Usage

### Entering a Dungeon

```clarity
(contract-call? .btcrealm enter-dungeon .my-token tx-sender)
```

### Completing a Dungeon

```clarity
(contract-call? .btcrealm complete-dungeon .my-token tx-sender)
```

### Query Player Stats

```clarity
(contract-call? .btcrealm get-player-stats tx-sender)
```

### Admin: Toggle Game State

```clarity
(contract-call? .btcrealm toggle-game-state)
```

---

## ✅ Security Considerations

* **Cooldown Enforcement**: Prevents rapid farming and ensures fairness.
* **Authorized Token Binding**: Only one `allowed-token` can be used for rewards.
* **Two-Step Ownership Transfer**: Reduces risk of accidental or malicious transfers.
* **Emergency Controls**: Owner can reset misconfigured player states.

---

## 📊 Future Extensions

* Multi-realm support with distinct entry costs and rewards.
* On-chain loot mechanics and NFT-based dungeon artifacts.
* Cross-realm leaderboard and seasonal reward distribution.
