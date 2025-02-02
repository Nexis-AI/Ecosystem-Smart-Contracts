// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import OpenZeppelin interfaces for ERC20 and Ownable functionality
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NexisLiquidityIncentiveProgram (NLIP)
 * @notice This contract incentivizes liquidity providers to lock their LP tokens
 *         by distributing NZT rewards over time. Bonuses are awarded for longer lock durations.
 *
 * Key features:
 *  - Users deposit LP tokens and choose a lock duration.
 *  - Three preset lock durations are available:
 *      • 3 Months (90 days)   => 1.2× bonus multiplier
 *      • 6 Months (180 days)  => 1.5× bonus multiplier
 *      • 12 Months (>=365 days) => 2.0× bonus multiplier
 *  - Rewards are distributed per block.
 *  - Users can claim rewards and withdraw their tokens after the lock period expires.
 *  - An emergency withdraw option allows users to exit early (forfeiting rewards).
 *
 * IMPORTANT: This is a simplified example. Production implementations should include:
 *  - Additional input validations
 *  - Better handling of multiple deposits per user (or a more robust struct)
 *  - Comprehensive testing and security audits.
 */
contract NexisLiquidityIncentiveProgram is Ownable {
    // ---------------------------
    // Configuration Constants
    // ---------------------------

    // Allowed lock durations in seconds and corresponding multipliers (multiplier values are scaled by 1e18)
    uint256 public constant LOCK_DURATION_3_MONTHS = 90 days;
    uint256 public constant LOCK_DURATION_6_MONTHS = 180 days;
    uint256 public constant LOCK_DURATION_12_MONTHS = 365 days; // Approximately 12 months

    uint256 public constant MULTIPLIER_3_MONTHS = 1.2e18;
    uint256 public constant MULTIPLIER_6_MONTHS = 1.5e18;
    uint256 public constant MULTIPLIER_12_MONTHS = 2.0e18;

    // Precision factor for reward calculations
    uint256 public constant ACC_REWARD_PRECISION = 1e12;

    // ---------------------------
    // State Variables
    // ---------------------------

    // The LP token that users deposit
    IERC20 public lpToken;
    // The reward token (NZT)
    IERC20 public rewardToken;

    // Reward rate in NZT tokens distributed per block
    uint256 public rewardPerBlock;

    // Block when reward distribution starts
    uint256 public startBlock;
    // Block of the last pool update
    uint256 public lastRewardBlock;
    // Accumulated rewards per share, scaled by ACC_REWARD_PRECISION
    uint256 public accRewardPerShare;

    // Total effective stake of all users (i.e. sum of each user's LP deposit * bonus multiplier)
    uint256 public totalEffectiveStake;

    // Structure to store information for each user
    struct UserInfo {
        uint256 amount;      // Amount of LP tokens deposited by the user
        uint256 rewardDebt;  // Reward debt (used for reward calculation)
        uint256 lockedUntil; // Timestamp until which the deposit is locked
        uint256 multiplier;  // Bonus multiplier for the deposit (scaled by 1e18)
    }

    // Mapping from user address to user info
    mapping(address => UserInfo) public userInfo;

    // ---------------------------
    // Events
    // ---------------------------
    event Deposit(address indexed user, uint256 amount, uint256 lockDuration, uint256 multiplier);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    // ---------------------------
    // Constructor
    // ---------------------------
    /**
     * @notice Initializes the NLIP contract.
     * @param _lpToken The address of the LP token contract.
     * @param _rewardToken The address of the NZT reward token contract.
     * @param _rewardPerBlock The number of reward tokens distributed per block.
     * @param _startBlock The block number when reward distribution begins.
     */
    constructor(
        IERC20 _lpToken,
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock
    ) {
        lpToken = _lpToken;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        lastRewardBlock = _startBlock;
    }

    // ---------------------------
    // Core Functions
    // ---------------------------

    /**
     * @notice Updates the reward variables of the pool to be up-to-date.
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        if (totalEffectiveStake == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 blocksElapsed = block.number - lastRewardBlock;
        uint256 reward = blocksElapsed * rewardPerBlock;
        accRewardPerShare = accRewardPerShare + (reward * ACC_REWARD_PRECISION) / totalEffectiveStake;
        lastRewardBlock = block.number;
    }

    /**
     * @notice Deposit LP tokens and lock them for a specified duration.
     * @param _amount The amount of LP tokens to deposit.
     * @param _lockDuration The lock duration (in seconds); must be one of the preset durations.
     */
    function deposit(uint256 _amount, uint256 _lockDuration) public {
        require(_amount > 0, "Deposit amount must be greater than 0");
        uint256 multiplier = getMultiplier(_lockDuration);
        require(multiplier > 0, "Invalid lock duration");

        updatePool();
        UserInfo storage user = userInfo[msg.sender];

        // If the user already has a deposit, claim pending rewards first.
        if (user.amount > 0) {
            uint256 pending = (userEffectiveStake(user) * accRewardPerShare) / ACC_REWARD_PRECISION - user.rewardDebt;
            if (pending > 0) {
                rewardToken.transfer(msg.sender, pending);
                emit Claim(msg.sender, pending);
            }
        }

        // Transfer LP tokens from the user to the contract.
        lpToken.transferFrom(msg.sender, address(this), _amount);

        // Update the user's deposit.
        user.amount = user.amount + _amount;

        // Set the new lock time if this deposit extends the lock period.
        uint256 newLockTime = block.timestamp + _lockDuration;
        if (newLockTime > user.lockedUntil) {
            user.lockedUntil = newLockTime;
            user.multiplier = multiplier; // For simplicity, each user maintains one multiplier.
        }

        // Increase the total effective stake.
        uint256 effectiveIncrease = (_amount * multiplier) / 1e18;
        totalEffectiveStake = totalEffectiveStake + effectiveIncrease;

        // Update reward debt.
        user.rewardDebt = (userEffectiveStake(user) * accRewardPerShare) / ACC_REWARD_PRECISION;
        emit Deposit(msg.sender, _amount, _lockDuration, multiplier);
    }

    /**
     * @notice Withdraw a specified amount of LP tokens (only allowed after the lock period).
     * @param _amount The amount of LP tokens to withdraw.
     */
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(block.timestamp >= user.lockedUntil, "Tokens are still locked");
        require(user.amount >= _amount, "Withdraw amount exceeds deposit");

        updatePool();

        // Calculate and transfer pending rewards.
        uint256 pending = (userEffectiveStake(user) * accRewardPerShare) / ACC_REWARD_PRECISION - user.rewardDebt;
        if (pending > 0) {
            rewardToken.transfer(msg.sender, pending);
            emit Claim(msg.sender, pending);
        }

        // Update the user's deposit and effective stake.
        user.amount = user.amount - _amount;
        uint256 effectiveDecrease = (_amount * user.multiplier) / 1e18;
        totalEffectiveStake = totalEffectiveStake - effectiveDecrease;

        // Update reward debt.
        user.rewardDebt = (userEffectiveStake(user) * accRewardPerShare) / ACC_REWARD_PRECISION;

        // Transfer LP tokens back to the user.
        lpToken.transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @notice Emergency withdraw allows users to retrieve their LP tokens immediately,
     *         forfeiting any pending rewards.
     */
    function emergencyWithdraw() public {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amountToWithdraw = user.amount;
        require(amountToWithdraw > 0, "Nothing to withdraw");

        // Update total effective stake.
        uint256 effectiveStake = (user.amount * user.multiplier) / 1e18;
        totalEffectiveStake = totalEffectiveStake - effectiveStake;

        // Reset the user's info.
        user.amount = 0;
        user.rewardDebt = 0;
        user.lockedUntil = 0;
        user.multiplier = 0;

        // Transfer LP tokens back to the user.
        lpToken.transfer(msg.sender, amountToWithdraw);
        emit EmergencyWithdraw(msg.sender, amountToWithdraw);
    }

    /**
     * @notice Returns the pending reward for a user.
     * @param _user The address of the user.
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accRewardPerShare = accRewardPerShare;
        if (block.number > lastRewardBlock && totalEffectiveStake != 0) {
            uint256 blocksElapsed = block.number - lastRewardBlock;
            uint256 reward = blocksElapsed * rewardPerBlock;
            _accRewardPerShare = _accRewardPerShare + (reward * ACC_REWARD_PRECISION) / totalEffectiveStake;
        }
        uint256 pending = (userEffectiveStake(user) * _accRewardPerShare) / ACC_REWARD_PRECISION - user.rewardDebt;
        return pending;
    }

    // ---------------------------
    // Helper & Admin Functions
    // ---------------------------

    /**
     * @dev Internal helper to compute a user's effective stake based on their deposit and multiplier.
     * @param user The user information.
     */
    function userEffectiveStake(UserInfo memory user) internal pure returns (uint256) {
        return (user.amount * user.multiplier) / 1e18;
    }

    /**
     * @notice Returns the bonus multiplier corresponding to a given lock duration.
     * @param _lockDuration The lock duration in seconds.
     * @return multiplier The multiplier (scaled by 1e18). Returns 0 if the duration is invalid.
     */
    function getMultiplier(uint256 _lockDuration) public pure returns (uint256) {
        if (_lockDuration == LOCK_DURATION_3_MONTHS) {
            return MULTIPLIER_3_MONTHS;
        } else if (_lockDuration == LOCK_DURATION_6_MONTHS) {
            return MULTIPLIER_6_MONTHS;
        } else if (_lockDuration >= LOCK_DURATION_12_MONTHS) {
            // Any lock duration equal to or above 12 months receives the maximum multiplier.
            return MULTIPLIER_12_MONTHS;
        } else {
            return 0; // Invalid lock duration
        }
    }

    /**
     * @notice Allows the owner to update the reward rate (tokens per block).
     * @param _rewardPerBlock The new reward rate.
     */
    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        updatePool();
        rewardPerBlock = _rewardPerBlock;
    }

    /**
     * @notice In case tokens (other than LP tokens) are accidentally sent to the contract, the owner can recover them.
     * @param _token The address of the token.
     * @param _amount The amount to recover.
     */
    function recoverToken(IERC20 _token, uint256 _amount) external onlyOwner {
        require(address(_token) != address(lpToken), "Cannot recover LP token");
        _token.transfer(owner(), _amount);
    }
}
