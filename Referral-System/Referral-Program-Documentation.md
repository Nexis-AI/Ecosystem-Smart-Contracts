# Nexis Referral & Points Program

An advanced referral and points system for incentivizing testnet and mainnet adoption on Nexis Network. This system allows users to register, refer others, earn points for completing tasks, and redeem these points for Nexis (NZT) tokens. Up to 3% of the total 1 Billion NZT supply (i.e., 30 million tokens) is allocated for rewards.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture & Flow](#architecture--flow)
- [Contract Functions](#contract-functions)
  - [Registration & Multi‑Tier Referrals](#registration--multi‑tier-referrals)
  - [Automated Task Integration & Time‑Based Multipliers](#automated-task-integration--time‑based-multipliers)
  - [Redemption](#redemption)
  - [Administrative Functions](#administrative-functions)
- [Deployment Instructions](#deployment-instructions)
- [Testing & Security Considerations](#testing--security-considerations)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

---

## Overview

The Nexis Referral & Points Program is designed to boost network adoption by rewarding users for participation. Users earn points by:

- **Registering** (with optional referrals),
- **Completing tasks** (such as bug reports, testnet interactions, and social media promotions),
- **Maintaining daily activity streaks.**

Accumulated points can later be redeemed for NZT tokens at a fixed conversion rate.

---

## Features

- **Multi‑Tier Referral System:**
  - **Level 1 Bonus:** Direct referrers earn bonus points.
  - **Level 2 & 3 Bonuses:** Indirect referrers also earn diminishing bonus points.

- **Early Adopter Bonus:**
  - Users registering before a preset deadline receive an increased bonus multiplier on their base registration points.

- **Automated Task Integration:**
  - Admin-awarded points for tasks completed during defined promotional periods.
  - **Task Bonus Multiplier:** Tasks completed during a bonus window receive extra points.
  - **Task Streak Bonus:** Consecutive tasks within 24 hours add an incremental bonus (5% per task, up to a maximum of 50%).

- **Redemption:**
  - Fixed conversion rate (e.g., 100 points per 1 NZT token).  
  - The contract must be pre-funded with NZT tokens from the allocated rewards pool.

- **Administrative Flexibility:**
  - Owner-only functions allow dynamic adjustment of bonus parameters and deadlines.

---

## Architecture & Flow

1. **User Registration:**
   - Users register via the `register()` function.
   - An optional referrer address can be provided.
   - Base registration points are awarded, with an extra multiplier for early adopters.
   - Multi‑tier referral bonuses (up to three levels) are automatically distributed.

2. **Task Completion & Points Awarding:**
   - The owner uses `awardTaskPoints()` to record task completions.
   - A task bonus multiplier is applied if the task is completed within the promotional period.
   - Task streaks are tracked to apply an incremental bonus for consecutive completions.

3. **Redemption:**
   - Users can convert their accumulated points to NZT tokens using `redeemPoints()`.
   - The conversion rate is fixed (e.g., 100 points = 1 NZT token).

4. **Administrative Control:**
   - Owner-only functions permit updates to early adopter and task bonus parameters, ensuring adaptability for various promotional events.

---

## Contract Functions

### Registration & Multi‑Tier Referrals

- **`register(address _referrer)`**
  - **Purpose:** Registers a new user. If a referrer is provided, it awards referral bonuses.
  - **Parameters:**
    - `_referrer`: The address of the direct referrer (use `address(0)` if none).
  - **Process:**
    - Checks that the caller is not already registered and that the referrer (if provided) is valid.
    - Awards the base registration points, applying the early adopter bonus multiplier if within the deadline.
    - Distributes referral bonuses:
      - **Level 1:** Direct referrer earns a bonus.
      - **Level 2:** The referrer’s referrer earns a bonus.
      - **Level 3:** The referrer of the Level 2 referrer earns a bonus.
  - **Events Emitted:**
    - `Registered`
    - `PointsAwarded` (for both registration and referral bonuses)

### Automated Task Integration & Time‑Based Multipliers

- **`awardTaskPoints(address _user, uint256 _basePoints, string calldata _taskDescription)`**
  - **Purpose:** Awards points for completing a task.
  - **Parameters:**
    - `_user`: The address of the user to award.
    - `_basePoints`: The base number of points for the task.
    - `_taskDescription`: A description or identifier of the task.
  - **Process:**
    - Verifies the user is registered.
    - Applies the task bonus multiplier if the current time is within the bonus period.
    - Checks for consecutive task completions (within a 24‑hour window) to update the task streak.
    - Calculates and applies the streak bonus (5% per consecutive task, capped at 50%).
  - **Events Emitted:**
    - `PointsAwarded` (with the task description)

### Redemption

- **`redeemPoints(uint256 _pointsToRedeem)`**
  - **Purpose:** Allows users to redeem accumulated points for NZT tokens.
  - **Parameters:**
    - `_pointsToRedeem`: The number of points the user wishes to convert.
  - **Process:**
    - Ensures the user is registered and has sufficient points.
    - Converts points to NZT tokens using the fixed conversion rate (`POINTS_PER_TOKEN`).
    - Deducts the redeemed points and transfers NZT tokens to the user.
  - **Events Emitted:**
    - `Redeemed`

### Administrative Functions

- **`updateEarlyAdopterParameters(uint256 _deadline, uint256 _multiplier)`**
  - **Purpose:** Updates parameters for the early adopter bonus.
  - **Parameters:**
    - `_deadline`: The new deadline timestamp.
    - `_multiplier`: The new bonus multiplier (e.g., 150 for 1.5× bonus).

- **`updateTaskBonusParameters(uint256 _start, uint256 _end, uint256 _multiplier)`**
  - **Purpose:** Updates the task bonus period and multiplier.
  - **Parameters:**
    - `_start`: The new start timestamp for the bonus period.
    - `_end`: The new end timestamp.
    - `_multiplier`: The new task bonus multiplier (e.g., 200 for 2× bonus).

---

## Deployment Instructions

1. **Prerequisites:**
   - Node.js and npm installed.
   - A development framework such as Hardhat or Truffle.
   - OpenZeppelin contracts library (`npm install @openzeppelin/contracts`).
   - An Ethereum wallet configured for deployment (e.g., MetaMask).

2. **Compilation:**
   - Compile the contract using your chosen framework.  
     _Example (using Hardhat):_
     ```bash
     npx hardhat compile
     ```

3. **Deployment:**
   - Configure your deployment script with the required parameters (addresses, deadlines, multipliers, etc.).
   - Deploy the contract to your target network.  
     _Example (using Hardhat):_
     ```bash
     npx hardhat run scripts/deploy.js --network <network_name>
     ```

4. **Funding the Reward Pool:**
   - Pre-fund the deployed contract with NZT tokens (from the allocated 3% pool, up to 30 million tokens) to ensure users can redeem points for tokens.

---

## Testing & Security Considerations

- **Automated Testing:**
  - Write unit and integration tests to cover all functions, including registration, task rewards, redemption, and administrative changes.
  
- **Security Auditing:**
  - Conduct a full security audit, preferably using third-party auditors, before mainnet deployment.
  
- **Best Practices:**
  - Use OpenZeppelin’s well-audited libraries.
  - Follow Solidity best practices to avoid common vulnerabilities.

---

## FAQ

**Q: How are referral bonuses distributed?**  
**A:**  
- Level 1 (direct referral) receives 25 bonus points.
- Level 2 (referrer of the direct referrer) receives 10 bonus points.
- Level 3 (referrer of Level 2) receives 5 bonus points.

**Q: What is the early adopter bonus?**  
**A:**  
- Users who register before the designated `earlyAdopterDeadline` receive a multiplier (e.g., 1.5×) on their base registration points.

**Q: How do task streak bonuses work?**  
**A:**  
- If a user completes tasks consecutively within a 24‑hour window, each subsequent task adds a 5% bonus, capped at 50%.

**Q: What is the conversion rate for redemption?**  
**A:**  
- The conversion rate is fixed at `POINTS_PER_TOKEN` (e.g., 100 points for 1 NZT token).

**Q: Who can update bonus parameters?**  
**A:**  
- Only the contract owner can update early adopter and task bonus parameters using the designated administrative functions.

---

## Contributing

Contributions to improve the referral program are welcome! To contribute:

1. **Fork the repository.**
2. **Create a new branch** for your feature or bug fix.
3. **Write tests** and ensure your code is well-documented.
4. **Submit a pull request** describing your changes and improvements.

---

## License

This project is licensed under the MIT License.

---

## Contact

For questions or support, please contact [Your Contact Information] or open an issue on GitHub.

---

*This documentation is intended for developers and community members looking to understand, deploy, or contribute to the Nexis Referral & Points Program. Always perform thorough testing and auditing before deploying on the mainnet.*
