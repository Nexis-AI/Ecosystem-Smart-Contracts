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
RS_stake = stakedAmount × Δt × r_stake × M_time M_time = 1 + (timeElapsed / bonusPeriod)


2. **Liquidity Rewards**  
Rewards for providing liquidity are calculated as:
RS_liq = liquidityProvided × Δt × r_liq


3. **Activity Rewards**  
Rewards based on on-chain interactions are given by:
RS_act = activityPoints × Δt × r_act


**Overall Reward:**  
The total reward accrued by a user is the sum of the three components:
Total Reward = RS_stake + RS_liq + RS_act


---

## Implementation Details

### Key Modules

- **RewardManager.sol**  
  The central hub that manages staking, liquidity provision, and activity tracking. It calculates and disburses rewards from the reward pool.

- **Staking Module:**  
  Handles deposits, withdrawals, and calculates rewards based on the staked NZT and time-based multipliers.

- **Liquidity Reward Module:**  
  Records liquidity contributions (from integrated oracles or DEX protocols) and computes corresponding rewards.

- **ActivityTracker Module:**  
  Updates users' activity points via an authorized oracle to reflect on-chain interactions.

- **Governance Functions:**  
  Allow the adjustment of base reward rates, bonus periods, and other parameters through on-chain proposals.

### Smart Contract Features

- **Continuous Reward Accrual:**  
  Rewards accrue continuously and users can claim their rewards at any time. The reward accrual clock resets with each claim.

- **Time-based Loyalty Multiplier:**  
  Encourages long-term staking by linearly increasing the multiplier over a set bonus period.

- **Modular & Upgradable Design:**  
  Designed with modularity in mind to integrate seamlessly with other network components. Future updates can be managed via upgradeable proxy contracts.

- **Security Measures:**  
  Includes non‑reentrancy guards and role-based access controls (e.g., owner and authorized oracle) to ensure secure operations.


Deployment & Integration
Pre-requisites:

Ensure the NZT token conforms to the ERC20 standard.
Users must approve the RewardManager contract to transfer NZT tokens on their behalf.
Integration with liquidity pools or oracle feeds is required to accurately measure liquidity contributions and activity.
Deployment:

Deploy the RewardManager.sol contract, funding it with the 30 million NZT reward pool.
Configure the authorized activityOracle address.
Set initial reward rates and bonus periods via governance functions.
Upgradability:

Consider using upgradeable proxy patterns (e.g., OpenZeppelin’s proxy contracts) for future modifications and enhancements.

Governance & Future Enhancements
On‑chain Governance:
Parameters such as reward rates, bonus periods, and other key variables can be adjusted through decentralized governance proposals.

Future Enhancements:

Integration with external oracles for automated liquidity and activity tracking.
Expansion to include cross-chain reward mechanisms.
Enhanced user interfaces for monitoring reward accrual and staking performance.


Citations & References
– Discussion on advanced Web3 reward systems.
– Insights on staking contract design and implementation.
– Analysis of Web3 loyalty programs.
– Ethereum community discussions on staking reward models.
For additional reading and in-depth analysis, please refer to the linked sources above.


