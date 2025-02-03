// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Interfaces for our NZT token (assumed ERC20 compliant)
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/// @title Nexis Network Reward Manager
/// @notice Implements multi-dimensional rewards for staking, liquidity provision, and activity
contract RewardManager {
    // --- Token and reward pool ---
    IERC20 public nztToken;    
    uint256 public rewardPool; // total NZT tokens allocated for rewards (initially 30 million)

    // --- Reward Rates (set in NZT wei per unit per second) ---
    uint256 public stakingRate;   // base rate for staking rewards (per token)
    uint256 public liquidityRate; // base rate for liquidity rewards (per liquidity unit)
    uint256 public activityRate;  // base rate for on-chain activity (per activity point)

    // --- Bonus parameters ---
    uint256 public bonusPeriod; // period (in seconds) over which time multiplier increases (e.g. 30 days)

    // --- User accounting structures ---
    struct UserInfo {
        uint256 stakedAmount;         // NZT tokens staked by user
        uint256 liquidityProvided;    // liquidity contribution (in token-equivalent units)
        uint256 activityPoints;       // accumulated on-chain activity points
        uint256 lastClaimTime;        // last time rewards were claimed
        uint256 accumulatedReward;    // rewards accrued but not claimed
        uint256 stakeTimestamp;       // time when current stake was initiated (for bonus multiplier)
    }

    mapping(address => UserInfo) public userInfo;

    // --- Authorized roles ---
    address public owner;
    address public activityOracle;  // only this address may update activity points

    // --- Reentrancy guard ---
    uint256 private unlocked = 1;
    modifier nonReentrant() {
        require(unlocked == 1, "ReentrancyGuard: reentrant call");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // --- Events ---
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event LiquidityProvided(address indexed user, uint256 amount, uint256 timestamp);
    event ActivityUpdated(address indexed user, uint256 points, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 reward, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event RewardPoolFunded(uint256 amount);

    // --- Governance events ---
    event RatesUpdated(uint256 stakingRate, uint256 liquidityRate, uint256 activityRate);
    event BonusPeriodUpdated(uint256 bonusPeriod);

    // --- Constructor ---
    constructor(address _nztToken, uint256 _rewardPool) {
        owner = msg.sender;
        nztToken = IERC20(_nztToken);
        rewardPool = _rewardPool; // e.g. 30 million * 1e18 if NZT has 18 decimals

        // Set initial rates (example values; these should be tuned)
        stakingRate = 1e8;      // 1e8 wei NZT per token per second (i.e. 0.0000001 NZT per token-second)
        liquidityRate = 2e8;    // liquidity rewards are higher
        activityRate = 5e8;     // activity rewards

        bonusPeriod = 30 days;
    }

    // --- Modifiers for ownership and authorized actions ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    modifier onlyOracle() {
        require(msg.sender == activityOracle, "Not authorized oracle");
        _;
    }

    /// @notice Set the address allowed to update activity points.
    function setActivityOracle(address _oracle) external onlyOwner {
        activityOracle = _oracle;
    }

    /// @notice Fund the reward pool (can be called by owner to top up rewards)
    function fundRewardPool(uint256 amount) external onlyOwner {
        require(nztToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        rewardPool += amount;
        emit RewardPoolFunded(amount);
    }

    // --- User actions ---

    /// @notice Stake NZT tokens to earn holding rewards.
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        // Transfer NZT tokens from user to this contract (tokens must be approved)
        require(nztToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        UserInfo storage user = userInfo[msg.sender];

        // Update rewards for pending accrual before changing stake
        _updateReward(msg.sender);

        user.stakedAmount += amount;
        // Reset stake timestamp if new stake (or choose to average it)
        if (user.stakedAmount == amount) {
            user.stakeTimestamp = block.timestamp;
        }
        emit Staked(msg.sender, amount, block.timestamp);
    }

    /// @notice (For liquidity providers) Record liquidity contribution.
    /// In a full implementation, this would be integrated with a DEX’s liquidity pool.
    function provideLiquidity(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        // Assume tokens are transferred to the contract externally or via a separate process.
        _updateReward(msg.sender);
        userInfo[msg.sender].liquidityProvided += amount;
        emit LiquidityProvided(msg.sender, amount, block.timestamp);
    }

    /// @notice Called by the authorized oracle to update a user’s activity points.
    function updateActivity(address userAddress, uint256 additionalPoints) external onlyOracle nonReentrant {
        require(additionalPoints > 0, "Points must be > 0");
        _updateReward(userAddress);
        userInfo[userAddress].activityPoints += additionalPoints;
        emit ActivityUpdated(userAddress, additionalPoints, block.timestamp);
    }

    /// @notice Claim all accrued rewards.
    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        UserInfo storage user = userInfo[msg.sender];
        uint256 reward = user.accumulatedReward;
        require(reward > 0, "No reward to claim");
        require(reward <= rewardPool, "Insufficient reward pool");

        // Reset accumulated rewards and update last claim time
        user.accumulatedReward = 0;
        user.lastClaimTime = block.timestamp;
        rewardPool -= reward;
        require(nztToken.transfer(msg.sender, reward), "Transfer failed");
        emit RewardClaimed(msg.sender, reward, block.timestamp);
    }

    /// @notice Unstake a specified amount. (Withdraw staked tokens.)
    function unstake(uint256 amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(amount > 0 && amount <= user.stakedAmount, "Invalid unstake amount");

        _updateReward(msg.sender);
        user.stakedAmount -= amount;
        // Transfer staked tokens back to user
        require(nztToken.transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawn(msg.sender, amount, block.timestamp);
    }

    // --- Reward calculation internal functions ---

    /// @dev Internal function to update a user’s accrued reward.
    function _updateReward(address userAddress) internal {
        UserInfo storage user = userInfo[userAddress];
        uint256 currentTime = block.timestamp;
        uint256 lastTime = user.lastClaimTime == 0 ? currentTime : user.lastClaimTime;
        uint256 deltaTime = currentTime > lastTime ? currentTime - lastTime : 0;
        if (deltaTime == 0) return; // nothing to do

        // Compute time multiplier for staking component:
        // For a continuously staked amount, bonus = 1 + (elapsed since stake) / bonusPeriod.
        uint256 timeElapsed = currentTime - user.stakeTimestamp;
        // Use fixed-point math with 1e18 precision.
        uint256 timeMultiplier = 1e18 + (timeElapsed * 1e18) / bonusPeriod; // e.g. 1e18 means multiplier 1.0

        // Calculate reward components over the elapsed period:
        uint256 stakingReward = (user.stakedAmount * deltaTime * stakingRate * timeMultiplier) / (1e18);
        uint256 liquidityReward = (user.liquidityProvided * deltaTime * liquidityRate);
        uint256 activityReward = (user.activityPoints * deltaTime * activityRate);

        uint256 totalReward = stakingReward + liquidityReward + activityReward;
        // Accumulate the reward for the user
        user.accumulatedReward += totalReward;
        // Reset lastClaimTime for reward accrual
        user.lastClaimTime = currentTime;
    }

    // --- Governance functions to update parameters ---
    function updateRates(
        uint256 _stakingRate,
        uint256 _liquidityRate,
        uint256 _activityRate
    ) external onlyOwner {
        stakingRate = _stakingRate;
        liquidityRate = _liquidityRate;
        activityRate = _activityRate;
        emit RatesUpdated(_stakingRate, _liquidityRate, _activityRate);
    }

    function updateBonusPeriod(uint256 _bonusPeriod) external onlyOwner {
        bonusPeriod = _bonusPeriod;
        emit BonusPeriodUpdated(_bonusPeriod);
    }
}
