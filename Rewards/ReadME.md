# Nexis Network Reward Program

An advanced, multi-dimensional reward system designed for Nexis Network, a next‑generation layer‑1 blockchain. This program incentivizes on‑chain activity, long‑term staking, and liquidity provision using the native token **NZT**. Out of a total supply of 1 Billion NZT, 3% (i.e. 30 million NZT) is allocated to a reward pool dedicated to network adoption.

---

## Table of Contents

- [Overview](#overview)
- [Reward Calculations](#reward-calculations)
- [Implementation Details](#implementation-details)
  - [Key Modules](#key-modules)
  - [Smart Contract Features](#smart-contract-features)
  - [Code Example](#code-example)
- [Deployment & Integration](#deployment--integration)
- [Governance & Future Enhancements](#governance--future-enhancements)
- [Citations & References](#citations--references)

---

## Overview

The Nexis Network Reward Program is built to accelerate mainnet adoption by rewarding users who:

- **Stake NZT:** Earn rewards based on the amount held and the duration of staking. A time-based loyalty multiplier increases rewards over time.
- **Provide Liquidity:** Gain additional incentives for contributing to liquidity pools on the network.
- **Engage in On‑Chain Activity:** Accumulate activity points by interacting with dApps, sending transactions, and participating in governance.

All reward distributions are sourced from the pre-allocated 30 million NZT in the reward pool, ensuring that users are continually incentivized while maintaining scarcity.

---

## Reward Calculations

Rewards are calculated based on three core components:

1. **Staking Rewards**  
   Users earn rewards proportional to:
   - **Staked Amount**
   - **Duration of Stake** (Δt)
   - **Loyalty Multiplier (M_time):** Increases linearly over a predefined bonus period (e.g., 30 days) to incentivize long-term holding.

   **Formula:**
