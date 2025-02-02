// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// ================================================================
// IMPORTS
// ================================================================
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NexisStablecoin
 * @notice A basic ERC20 stablecoin token.
 * @dev Only the NexisStablecoinProtocol (set as the protocol address) may mint and burn tokens.
 */
contract NexisStablecoin is ERC20, Ownable {
    /// @notice The protocol address allowed to mint/burn stablecoins.
    address public protocol;

    modifier onlyProtocol() {
        require(msg.sender == protocol, "NexisStablecoin: caller is not protocol");
        _;
    }

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        protocol = msg.sender;
    }

    /// @notice Mint stablecoins to a given address.
    function mint(address to, uint256 amount) external onlyProtocol {
        _mint(to, amount);
    }

    /// @notice Burn stablecoins from a given address.
    function burn(address from, uint256 amount) external onlyProtocol {
        _burn(from, amount);
    }

    /// @notice In case the protocol needs to be updated.
    function setProtocol(address _protocol) external onlyOwner {
        protocol = _protocol;
    }
}

/**
 * @title NexisStablecoinProtocol
 * @notice An asset‐backed stablecoin protocol for Nexis Network.
 *
 * Users may:
 *  - Deposit approved collateral (an ERC20 token) to open a position.
 *  - Mint nUSD stablecoins up to a defined collateralization ratio.
 *  - Repay stablecoins to reduce their debt.
 *  - Withdraw collateral if their position remains safely collateralized.
 *  - Have their positions liquidated by third parties if undercollateralized.
 *  - Claim rewards accumulated from fees (which are distributed proportionally to deposited collateral).
 *
 * Note: For simplicity, this example assumes a 1:1 collateral price (i.e. collateralPrice = 1)
 * and uses basis point (BP) calculations. In production, a robust price oracle should be integrated.
 */
contract NexisStablecoinProtocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ================================================================
    // TOKEN & COLLATERAL DEFINITIONS
    // ================================================================
    /// @notice The stablecoin token.
    NexisStablecoin public stablecoin;

    /// @notice The ERC20 token accepted as collateral.
    IERC20 public collateralToken;

    // ================================================================
    // PROTOCOL PARAMETERS
    // ================================================================
    /// @notice Collateralization ratio in basis points (e.g. 150% = 15000 BP).
    uint256 public constant COLLATERALIZATION_RATIO_BP = 15000;
    uint256 public constant BP_DENOMINATOR = 10000;

    /// @notice Fee percentages (in basis points) for minting and redemption.
    uint256 public mintingFeeBP;      // e.g., 50 BP = 0.5%
    uint256 public redemptionFeeBP;   // e.g., 50 BP = 0.5%

    // ================================================================
    // POSITION STRUCTURE & REWARD VARIABLES
    // ================================================================
    struct Position {
        uint256 collateralAmount;  // Amount of collateral deposited
        uint256 debtAmount;        // Amount of stablecoins minted (plus fee)
        uint256 rewardDebt;        // For reward distribution
    }
    mapping(address => Position) public positions;

    /// @notice Total fees collected (in collateral equivalent) to be distributed as rewards.
    uint256 public totalFeesCollected;

    /// @notice Accumulated rewards per unit of collateral (scaled by REWARD_PRECISION).
    uint256 public accRewardPerCollateral;
    uint256 public constant REWARD_PRECISION = 1e18;

    // ================================================================
    // EVENTS
    // ================================================================
    event CollateralDeposited(address indexed user, uint256 amount);
    event StablecoinMinted(address indexed user, uint256 stablecoinAmount, uint256 fee);
    event StablecoinRepaid(address indexed user, uint256 stablecoinAmount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event PositionLiquidated(address indexed liquidator, address indexed user, uint256 collateralSeized, uint256 debtRepaid);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);
    event FeesUpdated(uint256 mintingFeeBP, uint256 redemptionFeeBP);

    // ================================================================
    // CONSTRUCTOR
    // ================================================================
    /**
     * @notice Initializes the stablecoin protocol.
     * @param _collateralToken The ERC20 token accepted as collateral.
     * @param _mintingFeeBP Minting fee (in basis points).
     * @param _redemptionFeeBP Redemption fee (in basis points).
     */
    constructor(IERC20 _collateralToken, uint256 _mintingFeeBP, uint256 _redemptionFeeBP) {
        collateralToken = _collateralToken;
        mintingFeeBP = _mintingFeeBP;
        redemptionFeeBP = _redemptionFeeBP;

        // Deploy and initialize the stablecoin.
        stablecoin = new NexisStablecoin("Nexis Stablecoin", "nUSD");
        stablecoin.setProtocol(address(this));
    }

    // ================================================================
    // INTERNAL REWARD FUNCTIONS
    // ================================================================
    /**
     * @dev Internal function to update reward variables.
     * It distributes the collected fees among all collateral deposits.
     */
    function _updateRewards() internal {
        // Use the total collateral held by the protocol.
        uint256 totalCollateral = collateralToken.balanceOf(address(this));
        if (totalCollateral > 0 && totalFeesCollected > 0) {
            accRewardPerCollateral = accRewardPerCollateral + ((totalFeesCollected * REWARD_PRECISION) / totalCollateral);
            totalFeesCollected = 0; // Reset fees after distribution.
        }
    }

    // ================================================================
    // USER FUNCTIONS
    // ================================================================

    /**
     * @notice Deposit collateral into your position.
     * @param amount The amount of collateral to deposit.
     */
    function depositCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Deposit amount must be > 0");
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update rewards before modifying the position.
        _updateRewards();

        Position storage pos = positions[msg.sender];
        pos.collateralAmount += amount;
        // Update reward debt.
        pos.rewardDebt = (pos.collateralAmount * accRewardPerCollateral) / REWARD_PRECISION;
        emit CollateralDeposited(msg.sender, amount);
    }

    /**
     * @notice Mint stablecoins (nUSD) using your deposited collateral.
     * @param stablecoinAmount The amount of stablecoins you wish to mint.
     *
     * Requirements:
     * - The new total debt (minted amount plus fee) must not exceed the maximum allowed by your collateral.
     * - The fee is added to the total fees (and later distributed as rewards).
     */
    function mintStablecoin(uint256 stablecoinAmount) external nonReentrant {
        require(stablecoinAmount > 0, "Mint amount must be > 0");

        // Update rewards before changing position.
        _updateRewards();

        // Calculate fee: fee = stablecoinAmount * mintingFeeBP / BP_DENOMINATOR.
        uint256 fee = (stablecoinAmount * mintingFeeBP) / BP_DENOMINATOR;
        uint256 totalDebtIncrease = stablecoinAmount + fee;

        Position storage pos = positions[msg.sender];

        // Calculate maximum debt allowed.
        // For simplicity, assume collateral price = 1; in production use an oracle.
        uint256 maxDebt = (pos.collateralAmount * BP_DENOMINATOR) / COLLATERALIZATION_RATIO_BP;
        require(pos.debtAmount + totalDebtIncrease <= maxDebt, "Exceeds collateral capacity");

        // Update user debt.
        pos.debtAmount += totalDebtIncrease;

        // Mint stablecoins to the user (the fee is retained as protocol revenue).
        stablecoin.mint(msg.sender, stablecoinAmount);

        // Accumulate fee for rewards (fees are conceptually in “stablecoin value”).
        totalFeesCollected += fee;

        emit StablecoinMinted(msg.sender, stablecoinAmount, fee);
    }

    /**
     * @notice Repay stablecoins to reduce your debt.
     * @param stablecoinAmount The amount of stablecoins to repay.
     * @dev The user must have approved the stablecoin for burning.
     */
    function repayStablecoin(uint256 stablecoinAmount) external nonReentrant {
        require(stablecoinAmount > 0, "Repay amount must be > 0");

        // Burn the repaid stablecoins from the user's balance.
        stablecoin.burn(msg.sender, stablecoinAmount);

        _updateRewards();

        Position storage pos = positions[msg.sender];
        require(pos.debtAmount >= stablecoinAmount, "Repay exceeds debt");
        pos.debtAmount -= stablecoinAmount;

        emit StablecoinRepaid(msg.sender, stablecoinAmount);
    }

    /**
     * @notice Withdraw collateral if your remaining collateral keeps you safely overcollateralized.
     * @param amount The amount of collateral to withdraw.
     */
    function withdrawCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Withdraw amount must be > 0");

        _updateRewards();

        Position storage pos = positions[msg.sender];
        require(pos.collateralAmount >= amount, "Not enough collateral");

        uint256 newCollateral = pos.collateralAmount - amount;
        uint256 maxDebt = (newCollateral * BP_DENOMINATOR) / COLLATERALIZATION_RATIO_BP;
        require(pos.debtAmount <= maxDebt, "Insufficient collateral after withdrawal");

        pos.collateralAmount = newCollateral;
        // Update reward debt.
        pos.rewardDebt = (newCollateral * accRewardPerCollateral) / REWARD_PRECISION;
        collateralToken.safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Liquidate an undercollateralized position.
     * @param user The address of the user to liquidate.
     * @param repayAmount The amount of debt to repay on behalf of the user.
     *
     * Requirements:
     * - The user's position must be undercollateralized.
     * - The liquidator burns stablecoins equal to repayAmount.
     * - The liquidator receives a discount on the collateral seized.
     */
    function liquidate(address user, uint256 repayAmount) external nonReentrant {
        require(user != address(0), "Invalid user");
        require(repayAmount > 0, "Repay amount must be > 0");

        Position storage pos = positions[user];
        // Check if position is undercollateralized.
        uint256 maxDebt = (pos.collateralAmount * BP_DENOMINATOR) / COLLATERALIZATION_RATIO_BP;
        require(pos.debtAmount > maxDebt, "Position is healthy");

        // Burn the liquidator's stablecoins to cover the repayAmount.
        stablecoin.burn(msg.sender, repayAmount);

        // Apply a discount for the liquidator (e.g., 5% discount).
        uint256 discountBP = 500; // 5% discount
        uint256 collateralSeized = (repayAmount * (BP_DENOMINATOR + discountBP)) / BP_DENOMINATOR;
        if (collateralSeized > pos.collateralAmount) {
            collateralSeized = pos.collateralAmount;
        }

        pos.debtAmount = pos.debtAmount > repayAmount ? pos.debtAmount - repayAmount : 0;
        pos.collateralAmount -= collateralSeized;

        collateralToken.safeTransfer(msg.sender, collateralSeized);
        emit PositionLiquidated(msg.sender, user, collateralSeized, repayAmount);
    }

    /**
     * @notice Claim your portion of rewards (collected fees) based on your collateral deposit.
     * @dev Rewards are calculated as: pending = (collateralAmount * accRewardPerCollateral) - rewardDebt.
     */
    function claimRewards() external nonReentrant {
        _updateRewards();

        Position storage pos = positions[msg.sender];
        uint256 accumulatedReward = (pos.collateralAmount * accRewardPerCollateral) / REWARD_PRECISION;
        uint256 pendingReward = accumulatedReward > pos.rewardDebt ? accumulatedReward - pos.rewardDebt : 0;
        require(pendingReward > 0, "No rewards available");

        pos.rewardDebt = (pos.collateralAmount * accRewardPerCollateral) / REWARD_PRECISION;
        collateralToken.safeTransfer(msg.sender, pendingReward);

        emit RewardsClaimed(msg.sender, pendingReward);
    }

    // ================================================================
    // ADMINISTRATIVE FUNCTIONS
    // ================================================================
    /**
     * @notice Update the minting and redemption fee parameters.
     * @param _mintingFeeBP New minting fee in basis points.
     * @param _redemptionFeeBP New redemption fee in basis points.
     */
    function updateFees(uint256 _mintingFeeBP, uint256 _redemptionFeeBP) external onlyOwner {
        mintingFeeBP = _mintingFeeBP;
        redemptionFeeBP = _redemptionFeeBP;
        emit FeesUpdated(_mintingFeeBP, _redemptionFeeBP);
    }
}
