# Nexis Stablecoin Protocol

An asset-backed, over-collateralized stablecoin protocol built on Nexis Network. The protocol allows users to deposit approved collateral tokens, mint the stablecoin (nUSD), repay debt, withdraw collateral, and even have their undercollateralized positions liquidated. It also rewards active participation by distributing a portion of collected fees back to collateral providers, thereby promoting volume and liquidity on-chain.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [Contracts](#contracts)
  - [Collateral & Minting](#collateral--minting)
  - [Fees, Rewards & Distribution](#fees-rewards--distribution)
  - [Liquidation Mechanism](#liquidation-mechanism)
- [Functionality](#functionality)
  - [User Functions](#user-functions)
  - [Administrative Functions](#administrative-functions)
- [Security & Gas Optimizations](#security--gas-optimizations)
- [Deployment & Testing](#deployment--testing)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

---

## Overview

The Nexis Stablecoin Protocol is designed to be a secure, incentive-driven asset-backed stablecoin system on Nexis Network. Users can deposit collateral (an approved ERC20 token) to mint nUSD at a defined collateralization ratio (e.g., 150%). The system charges fees on minting and redemption, and these fees are redistributed as rewards to collateral providers—helping to boost on-chain liquidity and volume.

Key features include:

- **Over-Collateralization:** Ensures stability by requiring deposits to exceed the minted amount.
- **Fee Collection & Reward Distribution:** Minting fees are collected and later distributed as rewards to users providing collateral.
- **Liquidation Mechanism:** Under-collateralized positions can be liquidated by third parties.
- **Secure, Production-Ready Code:** Built using audited OpenZeppelin libraries and best practices.

---

## Architecture

### Contracts

The protocol comprises two main smart contracts:

1. **NexisStablecoin (nUSD):**
   - An ERC20 token that represents the stablecoin.
   - Only the protocol contract is allowed to mint or burn tokens.
   - Inherits standard ERC20 functionality and basic administrative controls.

2. **NexisStablecoinProtocol:**
   - The core contract that handles collateral deposits, stablecoin minting, debt management, rewards calculation, and liquidation.
   - Maintains user positions, enforces collateralization ratios, and manages fee accumulation and rewards distribution.

### Collateral & Minting

- **Collateral Deposit:**  
  Users deposit an approved ERC20 collateral token into the protocol. The deposited collateral increases the user’s “collateralAmount” and is used to determine how much stablecoin they can mint.
  
- **Minting Stablecoins:**  
  Users can mint nUSD by borrowing against their deposited collateral. The amount that can be minted is constrained by the collateralization ratio. A fee is charged on every minting operation, and the fee is added to the protocol’s fee pool for later distribution.

- **Repayment & Withdrawal:**  
  Users can repay their debt by burning nUSD, which in turn reduces their debt amount. Once debt is reduced, users may withdraw a portion of their collateral, provided their remaining collateral keeps them safely overcollateralized.

### Fees, Rewards & Distribution

- **Fee Mechanism:**  
  - A fee (specified in basis points) is charged on each stablecoin minting operation.
  - Collected fees are accumulated in a variable (`totalFeesCollected`).

- **Reward Distribution:**  
  - The protocol periodically updates the accumulated rewards per unit of collateral via the `_updateRewards()` function.
  - The rewards are calculated as:
  
    ```
    accRewardPerCollateral += (totalFeesCollected * REWARD_PRECISION) / totalCollateral
    ```
  
  - Each user’s pending rewards are determined by their deposited collateral relative to this cumulative reward metric.
  - Users can claim their rewards using the `claimRewards()` function, which transfers a proportional share of the rewards (in the form of collateral tokens) to the user.

### Liquidation Mechanism

- **Undercollateralization Check:**  
  If a user’s debt exceeds the maximum allowable debt for their deposited collateral (as determined by the collateralization ratio), their position becomes eligible for liquidation.

- **Liquidation Process:**  
  - A liquidator can repay a portion of the user’s debt by burning nUSD.
  - In exchange, the liquidator seizes a discounted portion of the user’s collateral (e.g., at a 5% discount).
  - This mechanism protects the protocol by incentivizing third parties to liquidate risky positions.

---

## Functionality

### User Functions

- **Deposit Collateral (`depositCollateral`):**  
  - Users can deposit a specified amount of the collateral token.
  - Updates the user’s collateral balance and reward debt.

- **Mint Stablecoin (`mintStablecoin`):**  
  - Allows users to mint nUSD up to their maximum borrowable amount based on their collateral.
  - Charges a fee that is added to the fee pool for rewards.

- **Repay Stablecoin (`repayStablecoin`):**  
  - Users can repay their debt by burning nUSD tokens.
  - Reduces their outstanding debt accordingly.

- **Withdraw Collateral (`withdrawCollateral`):**  
  - Once the debt is sufficiently repaid, users may withdraw a portion of their collateral.
  - Withdrawal is only permitted if the remaining collateral still supports the outstanding debt.

- **Liquidate Position (`liquidate`):**  
  - If a position is undercollateralized, any user (liquidator) can repay part of the debt and seize the corresponding collateral at a discount.
  - Helps to maintain the overall health of the protocol.

- **Claim Rewards (`claimRewards`):**  
  - Collateral providers can claim their share of the rewards accumulated from minting fees.
  - The rewards are distributed proportionally based on the amount of collateral deposited.

### Administrative Functions

- **Update Fees (`updateFees`):**  
  - Owner-only function to update the minting and redemption fee percentages.
  - Allows the protocol to adjust fees as market conditions change.

- **Internal Reward Update (`_updateRewards`):**  
  - An internal function that calculates the cumulative rewards per collateral unit.
  - Distributes the accumulated fees across all collateral deposits by updating the `accRewardPerCollateral`.

---

## Security & Gas Optimizations

- **Security Measures:**
  - Utilizes OpenZeppelin’s audited contracts: ERC20, SafeERC20, ReentrancyGuard, and Ownable.
  - Thorough input validations ensure that operations like deposit, minting, and withdrawal maintain system integrity.
  - Liquidation is controlled by collateralization checks to prevent abuse.
  - In a production system, integrate a robust price oracle (e.g., Chainlink) for real-time collateral valuations.

- **Gas Optimization Techniques:**
  - Minimal state writes and careful use of arithmetic operations.
  - Use of constants and scaled variables (e.g., REWARD_PRECISION) for accurate and gas-efficient reward calculations.
  - The protocol is designed to update rewards efficiently when user positions are modified.

---

## Deployment & Testing

1. **Prerequisites:**
   - Ensure that the collateral token is deployed and its address is known.
   - Deploy the NexisStablecoin contract.
   - Deploy the NexisStablecoinProtocol contract, passing the collateral token address and fee parameters.
   - Fund the protocol with collateral tokens if necessary (for rewards distribution).

2. **Testing:**
   - Thoroughly test on testnets (e.g., Rinkeby, BSC Testnet) to simulate deposits, minting, repayments, withdrawals, liquidations, and reward claims.
   - Integrate with a price oracle for realistic collateral valuation before mainnet deployment.
   - Ensure that all functions behave as expected under various market scenarios.

3. **Auditing:**
   - Have the protocol and stablecoin contracts professionally audited.
   - Address any potential vulnerabilities or gas inefficiencies before mainnet launch.

---

## Contributing

Contributions to improve the protocol are welcome. To contribute:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Write tests to cover your changes.
4. Submit a pull request with a detailed description of your improvements.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Contact

For questions, support, or further information, please contact:

- **Email:** [support@nexisnetwork.io](mailto:support@nexis.foundation)
- **GitHub:** [NexisNetwork](https://github.com/Nexis-AI)
- **Website:** [https://nexisnetwork.io](https://nexis.network)

---

*This documentation is intended for developers, auditors, and community members interested in understanding, deploying, and contributing to the Nexis Stablecoin Protocol. Always perform thorough testing and professional audits before deploying on mainnet.*
