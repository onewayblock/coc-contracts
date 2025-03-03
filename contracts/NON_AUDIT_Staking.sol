// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import "./interfaces/IClaim.sol";
import "./interfaces/IVesting.sol";

/**
 * @title ITokenShop
 * @dev Interface for the Purchase contract.
 * This contract is used to purchase items from the Shop using staked tokens.
 */
interface ITokenShop {
    function purchaseFromStake(
        address purchaser,
        uint256[] calldata skuEntities,
        uint256[] calldata quantities
    ) external returns (uint256 purchaseId, uint256 total);
}

/// @notice Error emitted when a user tries to withdraw more tokens than they have staked
error InsufficientBalance();

/// @notice Error emitted when a user tries to deposit 0 tokens or withdraw 0 tokens
error IncorrectAmount();

/// @notice Error emitted when an owner is trying to set an invalid multiplier
error InvalidMultiplier();

/// @notice Error emitted when the purchase contract is not set
error InvalidPurchaseContract();

/// @notice Error emitted when the purchase contract returns an invalid purchase
error InvalidPurchase();

/// @notice When trying to claim or set an invalid season.
error InvalidSeason();

/// @notice Invalid maximum growth multiplier
error InvalidMaxGrowthMultiplier();

/// @notice Invalid Week Multiplier Increment
error InvalidWeeklyMultiplierIncrement();

/**
 * @title A contract for staking ERC20 tokens
 * @notice This contract allows users to stake ERC20 tokens and earn points based on the amount of tokens staked and the time they have been staked
 */
contract Staking is
    Initializable,
    ContextUpgradeable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardTransient
{
    using SafeERC20 for IERC20;

    /**
     * @notice UserStakeInfo struct to store user's staking information
     * @param erc20balance The amount of ERC20 tokens staked by the user
     * @param erc20initial The initial amount of ERC20 tokens staked by the user
     * @param accumulatedPoints The total points earned by the user over time
     * @param lastUpdatedTime The timestamp of the last update
     * @param multiplier The multiplier applied to the user's points
     */
    struct UserStakeInfo {
        uint256 erc20balance;
        uint256 erc20initial;
        uint256 accumulatedPoints;
        uint64 lastUpdatedTime;
        uint16 multiplier;
    }

    /// @notice Season 1 Added variables

    /// @notice the user's staking information. Deprecated (Used only for S1)
    mapping(address => UserStakeInfo) public users;

    /// @notice The ERC20 token that can be staked
    IERC20 public token;

    /// @notice The vesting contract
    IVesting public vesting;

    /// @notice The packed value of the start date and the maximum multiplier. Deprecated (used only for S1)
    uint256 public packedStartDateAndMaxMultiplier;

    /// @notice The bonus multiplier to apply to the user's points. Deprecated (used only for S1)
    uint256 public bonusMultiplier;

    /// @notice The address of the approved purchase contract
    ITokenShop public shopContract;

    /// @notice Season 2 Added variables

    /// @notice The current season set by admin
    uint256 public currentSeason;

    /// @notice The season info for each season
    struct Season {
        // The start date of the season
        uint256 startDate;
        // The end date of a season
        uint256 endDate;
        // The multiplier given at the start of a season (decays 10% per day down to 100%)
        uint256 startingMultiplier;
        // Season Absolute Max, the maximum multiplier they can get through any means
        uint256 seasonAbsoluteMax;
        // The maximum multiplier a user can reach by holding
        uint256 maximumGrowthMultiplier;
        // The multiplier bonus given to a user when claiming
        uint256 claimMultiplier;
        // The % increase in multiplier each week for holding
        uint256 weeklyMultiplierIncrement;
        // The contract address for claiming.
        IClaim claimContract;
    }

    /// @notice The end date of the season - points will no longer accrue after this date.
    mapping(uint256 seasonId => Season seasonInfo) public seasonInfo;

    /// @notice Mapping of season IDs to users to their stake information
    mapping(uint256 seasonId => mapping(address userWallet => UserStakeInfo stakeInfo))
        public seasonIdToUserToStakeInfo;

    /// @notice Event emitted when a user deposits tokens
    event Deposit(address indexed user, uint256 amount, uint256 multiplier);

    /// @notice Event emitted when a user withdraws tokens
    event Withdraw(address indexed user, uint256 amount, uint256 multiplier);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract with the ERC20 token and the claim contract
     * @param _token The address of the ERC20 token
     * @param _vesting The address of the vesting contract
     */
    function initialize(address _token, address _vesting) public initializer {
        __Ownable_init(_msgSender());
        __Ownable2Step_init();
        __Pausable_init();
        __Context_init();
        token = IERC20(_token);
        vesting = IVesting(_vesting);
        packedStartDateAndMaxMultiplier = (block.timestamp << 192) | 500; // two decimals in max multiplier
        bonusMultiplier = 50;
        currentSeason = 1;
        _pause();
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Set the start date and maximum multiplier
     * @param _startDate The start date of the staking program
     * @param _maxMultiplier The maximum multiplier that can be applied to the points
     */
    function setStartDateAndMaxMultiplier(
        uint64 _startDate,
        uint192 _maxMultiplier
    ) external onlyOwner {
        //todo: revert deprecated;

        // no reason to have a multiplier more than 100x
        if (_maxMultiplier > 10_000) {
            revert InvalidMultiplier();
        }
        packedStartDateAndMaxMultiplier =
            (uint256(_startDate) << 192) |
            _maxMultiplier;
    }

    /**
     * @notice Set the Shop Contract
     * @param _shopContract The address of the Shop Contract
     */
    function setShopContract(address _shopContract) external onlyOwner {
        if (address(shopContract) != address(0)) {
            // Revoke the approval of the old contract
            token.approve(address(shopContract), 0);
        }
        shopContract = ITokenShop(_shopContract);
        //ensure we don't need to approve every tx
        token.approve(address(shopContract), type(uint256).max);
    }

    /**
     * @notice setBonusMultiplier
     * @param _bonusMultiplier The bonus multiplier to apply to the user's points (Cannot be more than 1000)
     */
    function setBonusMultiplier(uint256 _bonusMultiplier) external onlyOwner {
        if (_bonusMultiplier > 1000) {
            revert InvalidMultiplier();
        }
        bonusMultiplier = _bonusMultiplier;
    }

    /**
     * @notice Set the current season
     * @param season The season ID
     */
    function setCurrentSeason(uint256 season) external onlyOwner {
        if (season == 0) {
            revert InvalidSeason();
        }
        currentSeason = season;
    }

    /**
     * @notice Set the season information
     * @param season The season ID
     * @param startDate The start date of the season
     * @param endDate The end date of the season
     * @param startingMultiplier The starting multiplier for the season
     * @param maximumGrowthMultiplier The maximum multiplier for the season one can earn by waiting
     * @param claimMultiplier The bonus multiplier for claiming
     * @param weeklyMultiplierIncrement The amount the multiplier increases by each week up until the maximum limit
     * @param claimContract The address of the claim contract
     */
    function setSeasonInfo(
        uint256 season,
        uint256 startDate,
        uint256 endDate,
        uint256 startingMultiplier,
        uint256 seasonAbsoluteMax,
        uint256 maximumGrowthMultiplier,
        uint256 claimMultiplier,
        uint256 weeklyMultiplierIncrement,
        address claimContract
    ) external onlyOwner {
        if (endDate < startDate && startDate != 0 && endDate != 0) {
            revert InvalidSeason();
        }
        if (seasonAbsoluteMax < maximumGrowthMultiplier) {
            revert InvalidSeason();
        }
        if (weeklyMultiplierIncrement > maximumGrowthMultiplier) {
            revert InvalidSeason();
        }

        seasonInfo[season] = Season({
            startDate: startDate,
            endDate: endDate,
            startingMultiplier: startingMultiplier,
            seasonAbsoluteMax: seasonAbsoluteMax,
            maximumGrowthMultiplier: maximumGrowthMultiplier,
            claimMultiplier: claimMultiplier,
            weeklyMultiplierIncrement: weeklyMultiplierIncrement,
            claimContract: IClaim(claimContract)
        });
    }

    /**
     * @notice Update the maximum growth multiplier for a season
     * @param season The season ID
     * @param newMax The new maximum growth multiplier
     */
    function updateMaxGrowthMultiplier(
        uint256 season,
        uint256 newMax
    ) external onlyOwner {
        if (newMax == 0) {
            revert InvalidMaxGrowthMultiplier();
        }
        seasonInfo[season].maximumGrowthMultiplier = newMax;
    }

    /**
     * @notice Fix the user point calculation for a season
     * @param seasons The season IDs
     * @param usersSet The addresses of the user
     * @param newPoints The new points to set for the users
     */
    function fixUserPointCalculation(
        uint256[] calldata seasons,
        address[] calldata usersSet,
        uint256[] calldata newPoints
    ) external onlyOwner {
        if (
            seasons.length != usersSet.length ||
            seasons.length != newPoints.length
        ) {
            revert InvalidSeason();
        }
        for (uint256 i = 0; i < seasons.length; i++) {
            seasonIdToUserToStakeInfo[seasons[i]][usersSet[i]]
                .accumulatedPoints = newPoints[i];
        }
    }

    /**
     * @notice Update the Weekly Multiplier Increment for a season
     * @param season The season ID
     * @param newIncrement The new weekly multiplier increment
     */
    function updateWeeklyMultiplierIncrement(
        uint256 season,
        uint256 newIncrement
    ) external onlyOwner {
        if (newIncrement == 0) {
            revert InvalidWeeklyMultiplierIncrement();
        }
        seasonInfo[season].weeklyMultiplierIncrement = newIncrement;
    }

    /**
     * @notice Claim from Claim Contract and deposit for an increased multiplier
     * @param season The season ID
     * @param amount The amount of tokens to deposit
     * @param permitAmount The amount of tokens to deposit
     * @param merkleProof The Merkle proof for the claim
     * @param deadline The timestamp until which the permit is valid
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function claimAndDepositSeasonPermit(
        uint256 season,
        uint256 amount,
        uint256 permitAmount,
        bytes32[] calldata merkleProof,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused {
        IERC20Permit(address(token)).permit(
            _msgSender(),
            address(this),
            permitAmount,
            deadline,
            v,
            r,
            s
        );
        _claimAndDeposit(season, amount, merkleProof);
    }

    /**
     * @notice Claim from Claim Contract and deposit for an increased multiplier
     * @param season The season ID
     * @param amount The amount of tokens to deposit
     * @param merkleProof The Merkle proof for the claim
     */
    function claimAndDeposit(
        uint256 season,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant whenNotPaused {
        _claimAndDeposit(season, amount, merkleProof);
    }

    /**
     * @notice Claim from Claim Contract and deposit for an increased multiplier
     * @param amount The amount of tokens to deposit
     * @param permitAmount The amount of tokens to deposit
     * @param merkleProof The Merkle proof for the claim
     * @param deadline The timestamp until which the permit is valid
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function claimAndDepositPermit(
        uint256 amount,
        uint256 permitAmount,
        bytes32[] calldata merkleProof,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused {
        IERC20Permit(address(token)).permit(
            _msgSender(),
            address(this),
            permitAmount,
            deadline,
            v,
            r,
            s
        );

        _claimAndDeposit(currentSeason, amount, merkleProof);
    }

    /**
     * @notice Claim from Claim Contract and deposit for an increased multiplier
     * @param amount The amount of tokens to deposit
     * @param merkleProof The Merkle proof for the claim
     */
    function claimAndDeposit(
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant whenNotPaused {
        _claimAndDeposit(currentSeason, amount, merkleProof);
    }

    /**
     * @notice Release from vesting contract and deposit in same transaction
     * @param vestingScheduleId the vesting schedule identifier
     */
    function releaseAndDeposit(
        bytes32 vestingScheduleId
    ) external nonReentrant whenNotPaused {
        _releaseAndDeposit(currentSeason, vestingScheduleId);
    }

    /**
     * @notice Deposit ERC20 tokens into the contract
     * @param amount The amount of tokens to deposit
     * @param permitAmount The amount of tokens to deposit
     * @param deadline The timestamp until which the permit is valid
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function depositPermit(
        uint256 amount,
        uint256 permitAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused {
        IERC20Permit(address(token)).permit(
            _msgSender(),
            address(this),
            permitAmount,
            deadline,
            v,
            r,
            s
        );
        _deposit(amount, 0);
    }

    /**
     * @notice Deposit ERC20 tokens into the contract
     * @dev The user must approve the contract to spend the tokens before calling this function
     * @param amount The amount of tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        _deposit(amount, 0);
    }

    /**
     * @notice Withdraw ERC20 tokens from the contract
     * @dev The user must have enough tokens staked to withdraw the specified amount
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) {
            revert IncorrectAmount();
        }

        UserStakeInfo storage userStakeInfo = _seasonStakeInfo(
            currentSeason,
            _msgSender()
        );

        userStakeInfo.accumulatedPoints = _accumulatedPoints(_msgSender());

        if (userStakeInfo.erc20balance < amount) {
            if (userStakeInfo.erc20initial == 0 && currentSeason > 1) {
                UserStakeInfo memory lastSeasonStakeInfo = _lastSeasonStakeInfo(
                    _msgSender()
                );
                userStakeInfo.erc20balance = lastSeasonStakeInfo.erc20balance;
                userStakeInfo.erc20initial = lastSeasonStakeInfo.erc20initial;
            }

            if (userStakeInfo.erc20balance < amount) {
                revert InsufficientBalance();
            }
        }

        userStakeInfo.erc20balance = userStakeInfo.erc20balance - amount;
        userStakeInfo.lastUpdatedTime = uint64(block.timestamp);
        userStakeInfo.multiplier = uint16(currentMultiplier());

        token.safeTransfer(_msgSender(), amount);
        emit Withdraw(_msgSender(), amount, userStakeInfo.multiplier);
    }

    /**
     * @notice Purchase items from Shop using Staked tokens without losing multiplier
     * @param skuEntities listingId
     * @param quantities amount per listing id
     */
    function purchase(
        uint256[] calldata skuEntities,
        uint256[] calldata quantities
    ) external nonReentrant whenNotPaused {
        if (skuEntities.length != quantities.length) {
            revert InvalidPurchase();
        }

        if (shopContract == ITokenShop(address(0))) {
            revert InvalidPurchaseContract();
        }

        UserStakeInfo storage userStakeInfo = _seasonStakeInfo(
            currentSeason,
            _msgSender()
        );
        userStakeInfo.accumulatedPoints = _accumulatedPoints(_msgSender());
        // Season 1 staker-only, fallback to last season
        if (userStakeInfo.erc20initial == 0 && currentSeason > 1) {
            UserStakeInfo memory lastSeasonStakeInfo = _lastSeasonStakeInfo(
                _msgSender()
            );
            // Port over their S1 ERC20 balance, ERC20 initial, and multiplier
            userStakeInfo.erc20balance = lastSeasonStakeInfo.erc20balance;
            userStakeInfo.erc20initial = lastSeasonStakeInfo.erc20initial;
            userStakeInfo.multiplier = lastSeasonStakeInfo.multiplier;
        }

        if (userStakeInfo.lastUpdatedTime != 0) {
            userStakeInfo.multiplier = uint16(
                _getMultiplier(currentSeason, userStakeInfo)
            );
        }
        userStakeInfo.lastUpdatedTime = uint64(block.timestamp);

        (uint256 purchaseId, uint256 total) = shopContract.purchaseFromStake(
            _msgSender(),
            skuEntities,
            quantities
        );

        if (userStakeInfo.erc20balance < total) {
            revert InsufficientBalance();
        }

        if (purchaseId == 0) {
            revert InvalidPurchase();
        }

        userStakeInfo.erc20balance = userStakeInfo.erc20balance - total;
        emit Withdraw(_msgSender(), total, userStakeInfo.multiplier);
    }

    /**
     * @notice Returns the current global multiplier value
     * @dev The multiplier decays linearly over time from the start date to 100
     */
    function currentMultiplier() public view returns (uint256 multiplier) {
        uint256 startDate;
        uint cachedCurrentSeason = currentSeason;

        if (cachedCurrentSeason <= 1) {
            uint256 packedValue = packedStartDateAndMaxMultiplier;
            startDate = packedValue >> 192;
            multiplier = packedValue & 0xFFFFFFFFFFFFFFFFFFFFFFFF;
        } else {
            startDate = seasonInfo[cachedCurrentSeason].startDate;
            multiplier = seasonInfo[cachedCurrentSeason].startingMultiplier;
        }

        uint256 daysPassed = (block.timestamp - startDate) / 1 days; // Number of days passed since the start date
        unchecked {
            uint256 decay = daysPassed * 10; // Calculate the total decay

            if (decay < multiplier) {
                multiplier -= decay;
                if (multiplier < 100) {
                    multiplier = 100;
                }
            } else {
                multiplier = 100;
            }
        }

        return multiplier;
    }

    /**
     * Getters
     */

    function getMultiplier(address user) external view returns (uint256) {
        return getMultiplier(currentSeason, user);
    }

    /**
     * @notice Returns the multiplier for a specific user
     * @param season The season ID
     * @param user The address of the user
     * @return The multiplier for the user
     */
    function getMultiplier(
        uint256 season,
        address user
    ) public view returns (uint256) {
        return _getMultiplier(season, _seasonStakeInfo(season, user));
    }

    /**
     * @notice Returns the ERC20 balance of a user
     * @param user The address of the user
     * @return The ERC20 balance of the user
     */
    function getErc20Balance(address user) external view returns (uint256) {
        // TODO: Upgrade logic for S3, and iterate recursively
        if (
            _seasonStakeInfo(currentSeason, user).erc20initial == 0 &&
            currentSeason > 1
        ) {
            return _lastSeasonStakeInfo(user).erc20balance;
        }
        return _seasonStakeInfo(currentSeason, user).erc20balance;
    }

    /**
     * @notice Returns the ERC20 balance of a user
     * @param season The season ID
     * @param user The address of the user
     * @return The ERC20 balance of the user
     */
    function getErc20Balance(
        uint256 season,
        address user
    ) public view returns (uint256) {
        return _seasonStakeInfo(season, user).erc20balance;
    }

    /**
     * @notice Returns the total points earned by a user
     * @param user The address of the user
     * @return The total points earned by the user
     */
    function getPointsBalance(address user) external view returns (uint256) {
        return getPointsBalance(currentSeason, user);
    }

    /**
     * @notice Returns the total points earned by a user
     * @param season The season ID
     * @param user The address of the user
     * @return The total points earned by the user
     */
    function getPointsBalance(
        uint256 season,
        address user
    ) public view returns (uint256) {
        if (season <= 1) {
            return _totalPoints(season, users[user]);
        }

        if (
            seasonIdToUserToStakeInfo[season][user].erc20initial > 0 ||
            currentSeason != season
        ) {
            return
                _totalPoints(season, seasonIdToUserToStakeInfo[season][user]);
        }

        UserStakeInfo memory intermittentStakeInfo = UserStakeInfo({
            erc20balance: _lastSeasonStakeInfo(user).erc20balance,
            erc20initial: 0,
            accumulatedPoints: 0,
            multiplier: _lastSeasonStakeInfo(user).multiplier,
            lastUpdatedTime: uint64(seasonInfo[currentSeason].startDate)
        });

        return _totalPoints(season, intermittentStakeInfo);
    }

    /**
     * @notice Returns the base points earned by a user
     * @param user The address of the user
     * @return The base points earned by the user
     */
    function getBasePoints(
        uint256 season,
        address user
    ) public view returns (uint256) {
        if (season <= 1) {
            return _basePoints(season, _seasonStakeInfo(season, user));
        }

        UserStakeInfo memory userStakeInfo = _seasonStakeInfo(season, user);
        //If user has deposited this season OR we are not returning current season.
        if (userStakeInfo.erc20initial > 0 || currentSeason != season) {
            return _basePoints(season, userStakeInfo);
        }

        //calculate delta between last seasons stake and current season
        UserStakeInfo memory intermittentStakeInfo = UserStakeInfo({
            erc20balance: _lastSeasonStakeInfo(user).erc20balance,
            erc20initial: 0,
            accumulatedPoints: 0,
            multiplier: _lastSeasonStakeInfo(user).multiplier,
            lastUpdatedTime: uint64(seasonInfo[currentSeason].startDate)
        });

        return _basePoints(season, intermittentStakeInfo);
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual override onlyOwner {
        revert("Cannot renounce ownership");
    }

    /**
     * Private
     */

    /**
     * @notice Get the multiplier for a user
     * @param season The season ID
     * @param userStakeInfo The user's staking information
     */
    function _getMultiplier(
        uint256 season,
        UserStakeInfo memory userStakeInfo
    ) private view returns (uint256) {
        if (season <= 1) {
            return userStakeInfo.multiplier;
        }

        if (
            userStakeInfo.multiplier >=
            seasonInfo[season].maximumGrowthMultiplier ||
            userStakeInfo.erc20balance == 0
        ) {
            return userStakeInfo.multiplier;
        }

        uint256 multiplierCapLeft = seasonInfo[season].maximumGrowthMultiplier -
            userStakeInfo.multiplier;
        uint256 endDate = seasonInfo[season].endDate;

        if (endDate == 0) {
            endDate = block.timestamp;
        }
        uint256 additionalMultiplier = ((endDate -
            userStakeInfo.lastUpdatedTime) / 1 weeks) *
            seasonInfo[season].weeklyMultiplierIncrement;

        if (additionalMultiplier >= multiplierCapLeft) {
            return userStakeInfo.multiplier + multiplierCapLeft;
        }

        return userStakeInfo.multiplier + additionalMultiplier;
    }

    /**
     * @notice Claim from Claim Contract and deposit for an increased multiplier
     * @param season The season ID
     * @param amount The amount of tokens to deposit
     * @param merkleProof The Merkle proof for the claim
     */
    function _claimAndDeposit(
        uint256 season,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) private {
        if (season > currentSeason) {
            revert InvalidSeason();
        }

        seasonInfo[season].claimContract.claimTokens(
            _msgSender(),
            amount,
            merkleProof
        );

        if (currentSeason == season) {
            _deposit(amount, seasonInfo[season].claimMultiplier);
        } else {
            _deposit(amount, 0);
        }
    }

    /**
     * @notice Release from vesting contract and deposit in same transaction
     * @param season The season ID
     * @param vestingScheduleId the vesting schedule identifier
     */
    function _releaseAndDeposit(
        uint256 season,
        bytes32 vestingScheduleId
    ) private {
        if (season > currentSeason) {
            revert InvalidSeason();
        }

        uint256 vestedAmount = vesting.releaseAndStake(
            vestingScheduleId,
            msg.sender
        );

        if (currentSeason == season) {
            _deposit(vestedAmount, seasonInfo[season].claimMultiplier);
        } else {
            _deposit(vestedAmount, 0);
        }
    }

    /**
     * @notice Deposit ERC20 tokens into the contract
     * @param amount The amount of tokens to deposit
     * @param bonus The bonus multiplier to apply to the user's points
     * @dev The user must approve the contract to spend the tokens before calling this function
     */
    function _deposit(uint256 amount, uint256 bonus) private {
        if (amount == 0) {
            revert IncorrectAmount();
        }
        token.safeTransferFrom(_msgSender(), address(this), amount);
        uint cachedCurrentSeason = currentSeason;

        UserStakeInfo storage userStakeInfo = _seasonStakeInfo(
            cachedCurrentSeason,
            _msgSender()
        );

        userStakeInfo.accumulatedPoints = _accumulatedPoints(_msgSender());
        userStakeInfo.erc20balance = userStakeInfo.erc20balance + amount;
        if (userStakeInfo.lastUpdatedTime != 0) {
            userStakeInfo.multiplier = uint16(
                _getMultiplier(cachedCurrentSeason, userStakeInfo)
            );
        }
        userStakeInfo.lastUpdatedTime = uint64(block.timestamp);

        // If they have deposited then set bonus to zero.
        if (userStakeInfo.erc20initial != 0) {
            bonus = 0;
        }

        if (userStakeInfo.erc20initial == 0) {
            if (cachedCurrentSeason > 1) {
                // Note: This loop will be an issue if we have a large amount of seasons,
                // However, since the contract is upgradeable we will refactor this before we get to this issue.
                for (uint256 i = cachedCurrentSeason - 1; i > 0; i--) {
                    //read their previous season value from storage.
                    UserStakeInfo
                        storage previousSeasonStakeInfo = _seasonStakeInfo(
                            i,
                            _msgSender()
                        );
                    // if the user ever was involved that season we take their initial (even if 0).
                    if (previousSeasonStakeInfo.erc20initial > 0) {
                        userStakeInfo.erc20initial =
                            previousSeasonStakeInfo.erc20balance +
                            amount;
                        userStakeInfo.erc20balance =
                            previousSeasonStakeInfo.erc20balance +
                            amount;
                        break;
                    }
                }
            }
            // If User still has no balance, we set to amount
            if (userStakeInfo.erc20initial == 0) {
                userStakeInfo.erc20initial = amount;
            }
        }

        if (userStakeInfo.multiplier == 0) {
            // get the higher of their previous season multiplier or current season multiplier
            uint256 userMultiplier = 0;
            if (cachedCurrentSeason > 1) {
                userMultiplier = _lastSeasonStakeInfo(_msgSender()).multiplier;
            }

            userStakeInfo.multiplier = uint16(
                (
                    userMultiplier > currentMultiplier()
                        ? userMultiplier
                        : currentMultiplier()
                )
            );
        }

        // If the user has a bonus, apply it.
        if (bonus != 0) {
            userStakeInfo.multiplier = userStakeInfo.multiplier + uint16(bonus);
        }

        if (
            seasonInfo[cachedCurrentSeason].seasonAbsoluteMax != 0 &&
            userStakeInfo.multiplier >
            seasonInfo[cachedCurrentSeason].seasonAbsoluteMax
        ) {
            userStakeInfo.multiplier = uint16(
                seasonInfo[cachedCurrentSeason].seasonAbsoluteMax
            );
        }

        emit Deposit(_msgSender(), amount, userStakeInfo.multiplier);
    }

    /**
     * @notice Calculate the base points earned by a user
     * @param season The season ID
     * @param userStakeInfo The user's staking information
     * @return The base points earned by the user
     */
    function _basePoints(
        uint256 season,
        UserStakeInfo memory userStakeInfo
    ) private view returns (uint256) {
        uint256 endTime;
        uint256 seasonEndDate = seasonInfo[season].endDate;
        if (seasonEndDate == 0) {
            endTime = block.timestamp;
        } else {
            endTime = block.timestamp < seasonEndDate
                ? block.timestamp
                : seasonEndDate;
        }
        uint256 timeDifference = endTime > userStakeInfo.lastUpdatedTime
            ? endTime - userStakeInfo.lastUpdatedTime
            : 0;
        if (season <= 1) {
            return (userStakeInfo.erc20balance * timeDifference) / 1 hours;
        } else {
            return
                ((userStakeInfo.erc20balance * timeDifference) / 1 hours) +
                userStakeInfo.accumulatedPoints;
        }
    }

    /**
     * @notice Calculate the total points earned by a user
     * @param season The season ID
     * @param userStakeInfo The user's staking information
     * @return The total points earned by the user
     */
    function _totalPoints(
        uint256 season,
        UserStakeInfo memory userStakeInfo
    ) private view returns (uint256) {
        if (season <= 1) {
            unchecked {
                // This is a max multiplier value is maxMultiplier * token max ~ 100 bits for a token capped at 10M 1e18 decimal tokens multiplied by a 64 bit number, so 164 bits, no overflow
                return
                    ((_basePoints(season, userStakeInfo) *
                        _getMultiplier(season, userStakeInfo)) / 100) +
                    userStakeInfo.accumulatedPoints;
            }
        } else {
            return
                (_basePoints(season, userStakeInfo) *
                    _getMultiplier(season, userStakeInfo)) / 100;
        }
    }

    /**
     * @notice Calculate the accumulated points earned by a user
     * @param who The address of the user
     * @return The accumulated points earned by the user
     */
    function _accumulatedPoints(address who) private view returns (uint256) {
        if (currentSeason <= 1) {
            return getPointsBalance(currentSeason, who);
        } else {
            return getBasePoints(currentSeason, who);
        }
    }

    /**
     * @notice Get the user's staking information for a specific season
     * @param season The season ID
     * @param user The address of the user
     * @return The user's staking information
     */
    function _seasonStakeInfo(
        uint256 season,
        address user
    ) private view returns (UserStakeInfo storage) {
        if (season <= 1) {
            return users[user];
        }
        return seasonIdToUserToStakeInfo[season][user];
    }

    /**
     * @notice Get the user's staking information for the last season
     * @param user The address of the user
     * @return The user's staking information
     */
    function _lastSeasonStakeInfo(
        address user
    ) private view returns (UserStakeInfo storage) {
        if (currentSeason == 2) {
            return users[user];
        }
        return seasonIdToUserToStakeInfo[currentSeason - 1][user];
    }
}
