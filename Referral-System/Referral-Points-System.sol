// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin libraries for access control and ERC20 functionality.
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title NexisReferralPointsAdvanced
 * @notice Implements an advanced referral and points system for incentivizing
 *         testnet/mainnet adoption on Nexis Network.
 *
 * Features:
 *  - Multi‑tier referral system (up to 3 levels).
 *  - Early adopter bonus multiplier for registrations.
 *  - Automated task integration with time‑based bonus and streak multipliers.
 *  - Fixed redemption conversion (POINTS_PER_TOKEN points redeemed for 1 NZT).
 *
 * Note: This is an educational example. Production deployments should undergo
 *       extensive testing and third‑party audits.
 */
contract NexisReferralPointsAdvanced is Ownable {
    // ---------------------------
    // Data Structures & Variables
    // ---------------------------
    
    struct User {
        bool registered;
        address referrer;          // Immediate (Level 1) referrer
        uint256 points;            // Accumulated points
        uint256 referralsCount;    // Number of direct referrals
        uint256 registrationTimestamp;  // Used for early adopter bonus
        uint256 taskStreak;        // Number of consecutive tasks within a defined window
        uint256 lastTaskTimestamp; // Timestamp of the last task completion
    }
    
    mapping(address => User) public users;
    
    // Reference to the NZT reward token. The contract must be pre-funded with tokens from the 30M pool.
    IERC20 public rewardToken;
    
    // Redemption: POINTS_PER_TOKEN points can be exchanged for 1 NZT.
    uint256 public constant POINTS_PER_TOKEN = 100;
    
    // Base points and referral bonus constants (points).
    uint256 public constant BASE_REGISTRATION_POINTS = 50;
    uint256 public constant LEVEL1_BONUS = 25;
    uint256 public constant LEVEL2_BONUS = 10;
    uint256 public constant LEVEL3_BONUS = 5;
    
    // Early adopter parameters.
    // If a user registers before earlyAdopterDeadline, their base registration points are multiplied.
    uint256 public earlyAdopterDeadline;
    uint256 public earlyAdopterMultiplier;  // e.g. 150 means 1.5x (expressed as percent, base = 100)
    uint256 public constant MULTIPLIER_BASE = 100;  // Base value for percentage calculations
    
    // Task bonus parameters.
    // Tasks completed during the bonus period get extra points.
    uint256 public taskBonusStart;
    uint256 public taskBonusEnd;
    uint256 public taskBonusMultiplier;  // e.g., 200 means 2x bonus
    
    // Task streak parameters.
    // For every consecutive task within TASK_STREAK_WINDOW, add 5% bonus up to a max of 50%.
    uint256 public constant TASK_STREAK_BONUS_PER_TASK = 5; // 5% per consecutive task after the first.
    uint256 public constant MAX_TASK_STREAK_BONUS = 50;       // Maximum additional bonus of 50%.
    uint256 public constant TASK_STREAK_WINDOW = 1 days;      // Time window to maintain the streak.
    
    // ---------------------------
    // Events
    // ---------------------------
    event Registered(address indexed user, address indexed referrer);
    event PointsAwarded(address indexed user, uint256 points, string reason);
    event Redeemed(address indexed user, uint256 pointsRedeemed, uint256 tokensAwarded);
    
    // ---------------------------
    // Constructor
    // ---------------------------
    /**
     * @notice Initializes the contract.
     * @param _rewardToken Address of the NZT reward token.
     * @param _earlyAdopterDeadline Timestamp until which early adopter bonus applies.
     * @param _earlyAdopterMultiplier Multiplier for early registrations (e.g., 150 for 1.5x).
     * @param _taskBonusStart Start timestamp for task bonus period.
     * @param _taskBonusEnd End timestamp for task bonus period.
     * @param _taskBonusMultiplier Multiplier for tasks during the bonus period (e.g., 200 for 2x).
     */
    constructor(
        IERC20 _rewardToken,
        uint256 _earlyAdopterDeadline,
        uint256 _earlyAdopterMultiplier,
        uint256 _taskBonusStart,
        uint256 _taskBonusEnd,
        uint256 _taskBonusMultiplier
    ) {
        rewardToken = _rewardToken;
        earlyAdopterDeadline = _earlyAdopterDeadline;
        earlyAdopterMultiplier = _earlyAdopterMultiplier;
        taskBonusStart = _taskBonusStart;
        taskBonusEnd = _taskBonusEnd;
        taskBonusMultiplier = _taskBonusMultiplier;
    }
    
    // ---------------------------
    // Registration & Referral Functions
    // ---------------------------
    
    /**
     * @notice Register a new user with an optional referrer. Applies early adopter bonus if applicable.
     *         Awards multi‑tier referral bonuses (Levels 1–3).
     * @param _referrer The address of the direct referrer (or address(0) if none).
     */
    function register(address _referrer) external {
        require(!users[msg.sender].registered, "Already registered");
        require(_referrer != msg.sender, "Cannot refer self");
        if (_referrer != address(0)) {
            require(users[_referrer].registered, "Referrer not registered");
        }
        
        // Determine base registration points with potential early adopter bonus.
        uint256 regPoints = BASE_REGISTRATION_POINTS;
        if (block.timestamp < earlyAdopterDeadline) {
            regPoints = (regPoints * earlyAdopterMultiplier) / MULTIPLIER_BASE;
        }
        
        // Register the user.
        users[msg.sender] = User({
            registered: true,
            referrer: _referrer,
            points: regPoints,
            referralsCount: 0,
            registrationTimestamp: block.timestamp,
            taskStreak: 0,
            lastTaskTimestamp: 0
        });
        
        emit Registered(msg.sender, _referrer);
        emit PointsAwarded(msg.sender, regPoints, "Registration Base Points");
        
        // Multi-tier referral bonuses:
        if (_referrer != address(0)) {
            // Level 1 Bonus:
            users[_referrer].points += LEVEL1_BONUS;
            users[_referrer].referralsCount += 1;
            emit PointsAwarded(_referrer, LEVEL1_BONUS, "Level 1 Referral Bonus");
            
            // Level 2 Bonus:
            address level2 = users[_referrer].referrer;
            if (level2 != address(0)) {
                users[level2].points += LEVEL2_BONUS;
                emit PointsAwarded(level2, LEVEL2_BONUS, "Level 2 Referral Bonus");
                
                // Level 3 Bonus:
                address level3 = users[level2].referrer;
                if (level3 != address(0)) {
                    users[level3].points += LEVEL3_BONUS;
                    emit PointsAwarded(level3, LEVEL3_BONUS, "Level 3 Referral Bonus");
                }
            }
        }
    }
    
    // ---------------------------
    // Automated Task Integration Functions
    // ---------------------------
    
    /**
     * @notice Award points to a user for completing a specific task.
     *         Applies task bonus multiplier if within the bonus period and adds a streak bonus if tasks are consecutive.
     * @param _user Address of the user to award points.
     * @param _basePoints Base points for the task (before multipliers).
     * @param _taskDescription Description or identifier of the task.
     */
    function awardTaskPoints(address _user, uint256 _basePoints, string calldata _taskDescription) external onlyOwner {
        require(users[_user].registered, "User not registered");
        
        uint256 finalPoints = _basePoints;
        
        // Apply task bonus multiplier if current time is within the promotional period.
        if (block.timestamp >= taskBonusStart && block.timestamp <= taskBonusEnd) {
            finalPoints = (finalPoints * taskBonusMultiplier) / MULTIPLIER_BASE;
        }
        
        // Update task streak: if the user completed a task within the last 24 hours, increase the streak; otherwise, reset.
        if (block.timestamp <= users[_user].lastTaskTimestamp + TASK_STREAK_WINDOW) {
            users[_user].taskStreak += 1;
        } else {
            users[_user].taskStreak = 1;
        }
        
        // Calculate streak bonus: 5% per consecutive task after the first, capped at 50%.
        uint256 streakBonusPercent = TASK_STREAK_BONUS_PER_TASK * (users[_user].taskStreak > 0 ? users[_user].taskStreak - 1 : 0);
        if (streakBonusPercent > MAX_TASK_STREAK_BONUS) {
            streakBonusPercent = MAX_TASK_STREAK_BONUS;
        }
        finalPoints = (finalPoints * (MULTIPLIER_BASE + streakBonusPercent)) / MULTIPLIER_BASE;
        
        // Update the last task timestamp.
        users[_user].lastTaskTimestamp = block.timestamp;
        
        // Award the computed points.
        users[_user].points += finalPoints;
        emit PointsAwarded(_user, finalPoints, _taskDescription);
    }
    
    // ---------------------------
    // Redemption Functions
    // ---------------------------
    
    /**
     * @notice Redeem accumulated points for NZT tokens.
     *         For every POINTS_PER_TOKEN points, the user receives 1 NZT token.
     * @param _pointsToRedeem The number of points to redeem.
     */
    function redeemPoints(uint256 _pointsToRedeem) external {
        require(users[msg.sender].registered, "User not registered");
        require(users[msg.sender].points >= _pointsToRedeem, "Insufficient points");
        
        // Calculate how many NZT tokens to award.
        uint256 tokensToAward = _pointsToRedeem / POINTS_PER_TOKEN;
        require(tokensToAward > 0, "Not enough points to redeem for a token");
        
        // Deduct the redeemed points.
        users[msg.sender].points -= _pointsToRedeem;
        
        // Transfer the NZT tokens to the user. The contract must be pre-funded.
        require(rewardToken.transfer(msg.sender, tokensToAward), "Token transfer failed");
        
        emit Redeemed(msg.sender, _pointsToRedeem, tokensToAward);
    }
    
    // ---------------------------
    // Utility Functions
    // ---------------------------
    
    /**
     * @notice Retrieve the current point balance for a user.
     * @param _user The user's address.
     * @return The current point balance.
     */
    function getUserPoints(address _user) external view returns (uint256) {
        return users[_user].points;
    }
    
    // ---------------------------
    // Administrative Functions
    // ---------------------------
    
    /**
     * @notice Update early adopter parameters.
     * @param _deadline New deadline timestamp for early adopter bonus.
     * @param _multiplier New multiplier (e.g., 150 for 1.5x).
     */
    function updateEarlyAdopterParameters(uint256 _deadline, uint256 _multiplier) external onlyOwner {
        earlyAdopterDeadline = _deadline;
        earlyAdopterMultiplier = _multiplier;
    }
    
    /**
     * @notice Update task bonus parameters.
     * @param _start New start timestamp for task bonus period.
     * @param _end New end timestamp for task bonus period.
     * @param _multiplier New task bonus multiplier (e.g., 200 for 2x).
     */
    function updateTaskBonusParameters(uint256 _start, uint256 _end, uint256 _multiplier) external onlyOwner {
        taskBonusStart = _start;
        taskBonusEnd = _end;
        taskBonusMultiplier = _multiplier;
    }
}
