// contracts/TokenVesting.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

// OpenZeppelin dependencies
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IVesting.sol";

/**
 * @title TokenVesting
 */
contract Vesting is OwnableUpgradeable, ReentrancyGuardUpgradeable, IVesting {
    using SafeERC20 for IERC20;

    /**
     * @notice The token to be vested
     */
    IERC20 public _token;

    /// @notice Address of the staking contract
    address public _staking;

    bytes32[] private vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 private vestingSchedulesTotalAmount;
    mapping(address => uint256) private holdersVestingCount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     * @param owner_ address of the contract owner
     * @param staking_ address of staking contract
     */
    function initialize(
        address token_,
        address owner_,
        address staking_
    ) public initializer {
        if (
            token_ == address(0) ||
            staking_ == address(0) ||
            owner_ == address(0)
        ) {
            revert InvalidAddress();
        }

        __Ownable_init(owner_);
        __ReentrancyGuard_init();

        _token = IERC20(token_);
        _staking = staking_;
    }

    /**
     * @dev This function is called for plain Ether transfers, i.e. for every call with empty calldata.
     */
    receive() external payable {}

    /**
     * @dev Fallback function is executed if none of the other functions match the function
     * identifier or no data was provided with the function call.
     */
    fallback() external payable {}

    /**
     * @inheritdoc IVesting
     */
    function setStakingAddress(address staking_) external onlyOwner {
        if (staking_ == address(0)) {
            revert InvalidAddress();
        }

        _staking = staking_;
        emit StakingAddressUpdated(_staking);
    }

    /**
     * @inheritdoc IVesting
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        uint256 _amount
    ) external onlyOwner {
        if (getWithdrawableAmount() < _amount) {
            revert InsufficientTokens();
        }
        if (_duration <= 0) {
            revert InvalidDuration();
        }
        if (_amount <= 0) {
            revert InvalidAmount();
        }
        if (_slicePeriodSeconds < 1) {
            revert InvalidSlicePeriod();
        }
        if (_duration < _cliff) {
            revert InvalidCliff();
        }
        if (_beneficiary == address(0)) {
            revert InvalidAddress();
        }

        bytes32 vestingScheduleId = computeNextVestingScheduleIdForHolder(
            _beneficiary
        );
        uint256 cliff = _start + _cliff;
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            _beneficiary,
            cliff,
            _start,
            _duration,
            _slicePeriodSeconds,
            _amount,
            0
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount + _amount;
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount + 1;

        emit VestingScheduleCreated(
            vestingScheduleId,
            _beneficiary,
            _start,
            cliff,
            _duration,
            _slicePeriodSeconds,
            _amount
        );
    }

    /**
     * @inheritdoc IVesting
     */
    function withdraw(uint256 amount) external nonReentrant onlyOwner {
        if (getWithdrawableAmount() < amount) {
            revert InsufficientWithdrawableFunds();
        }
        SafeERC20.safeTransfer(_token, msg.sender, amount);

        emit FundsWithdrawn(msg.sender, amount);
    }

    /**
     * @inheritdoc IVesting
     */
    function release(
        bytes32 vestingScheduleId
    ) public nonReentrant returns (uint256) {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        if (
            msg.sender != vestingSchedule.beneficiary && msg.sender != owner()
        ) {
            revert Unauthorized();
        }

        return _release(vestingScheduleId, vestingSchedule.beneficiary);
    }

    /**
     * @inheritdoc IVesting
     */
    function releaseAndStake(
        bytes32 vestingScheduleId,
        address beneficiary
    ) public nonReentrant returns (uint256) {
        if (msg.sender != _staking) {
            revert Unauthorized();
        }

        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        if (beneficiary != vestingSchedule.beneficiary) {
            revert Unauthorized();
        }

        return _release(vestingScheduleId, beneficiary);
    }

    /**
     * @notice Release vested amount of tokens.
     * @param vestingScheduleId the vesting schedule identifier
     * @param beneficiary the address of the beneficiary
     * @return the amount of tokens released
     */
    function _release(
        bytes32 vestingScheduleId,
        address beneficiary
    ) internal returns (uint256) {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];

        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        vestingSchedule.released = vestingSchedule.released + vestedAmount;
        vestingSchedulesTotalAmount =
            vestingSchedulesTotalAmount -
            vestedAmount;

        SafeERC20.safeTransfer(_token, beneficiary, vestedAmount);

        emit TokensReleased(vestingScheduleId, vestedAmount);

        return vestedAmount;
    }

    /**
     * @inheritdoc IVesting
     */
    function getVestingSchedulesCountByBeneficiary(
        address _beneficiary
    ) external view returns (uint256) {
        return holdersVestingCount[_beneficiary];
    }

    /**
     * @inheritdoc IVesting
     */
    function getVestingIdAtIndex(
        uint256 index
    ) external view returns (bytes32) {
        if (index >= getVestingSchedulesCount()) {
            revert IndexOutOfBounds();
        }
        return vestingSchedulesIds[index];
    }

    /**
     * @inheritdoc IVesting
     */
    function getVestingScheduleByAddressAndIndex(
        address holder,
        uint256 index
    ) external view returns (VestingSchedule memory) {
        return
            getVestingSchedule(
                computeVestingScheduleIdForAddressAndIndex(holder, index)
            );
    }

    /**
     * @inheritdoc IVesting
     */
    function getVestingSchedulesTotalAmount() external view returns (uint256) {
        return vestingSchedulesTotalAmount;
    }

    /**
     * @inheritdoc IVesting
     */
    function getToken() external view returns (address) {
        return address(_token);
    }

    /**
     * @inheritdoc IVesting
     */
    function getVestingSchedulesCount() public view returns (uint256) {
        return vestingSchedulesIds.length;
    }

    /**
     * @inheritdoc IVesting
     */
    function computeReleasableAmount(
        bytes32 vestingScheduleId
    ) external view returns (uint256) {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(
        bytes32 vestingScheduleId
    ) public view returns (VestingSchedule memory) {
        return vestingSchedules[vestingScheduleId];
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return _token.balanceOf(address(this)) - vestingSchedulesTotalAmount;
    }

    /**
     * @dev Computes the next vesting schedule identifier for a given holder address.
     */
    function computeNextVestingScheduleIdForHolder(
        address holder
    ) public view returns (bytes32) {
        return
            computeVestingScheduleIdForAddressAndIndex(
                holder,
                holdersVestingCount[holder]
            );
    }

    /**
     * @inheritdoc IVesting
     */
    function getLastVestingScheduleForHolder(
        address holder
    ) external view returns (VestingSchedule memory) {
        if (holdersVestingCount[holder] == 0) {
            revert NoVestingSchedules();
        }

        return
            vestingSchedules[
                computeVestingScheduleIdForAddressAndIndex(
                    holder,
                    holdersVestingCount[holder] - 1
                )
            ];
    }

    /**
     * @dev Computes the vesting schedule identifier for an address and an index.
     */
    function computeVestingScheduleIdForAddressAndIndex(
        address holder,
        uint256 index
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @return the amount of releasable tokens
     */
    function _computeReleasableAmount(
        VestingSchedule memory vestingSchedule
    ) internal view returns (uint256) {
        // Retrieve the current time.
        uint256 currentTime = getCurrentTime();
        // If the current time is before the cliff, no tokens are releasable.
        if (currentTime < vestingSchedule.cliff) {
            return 0;
        }
        // If the current time is after the vesting period, all tokens are releasable,
        // minus the amount already released.
        else if (
            currentTime >= vestingSchedule.cliff + vestingSchedule.duration
        ) {
            return vestingSchedule.amountTotal - vestingSchedule.released;
        }
        // Otherwise, some tokens are releasable.
        else {
            // Compute the number of full vesting periods that have elapsed.
            uint256 timeFromStart = currentTime - vestingSchedule.cliff;
            uint256 secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart / secondsPerSlice;
            uint256 vestedSeconds = vestedSlicePeriods * secondsPerSlice;
            // Compute the amount of tokens that are vested.
            uint256 vestedAmount = (vestingSchedule.amountTotal *
                vestedSeconds) / vestingSchedule.duration;
            // Subtract the amount already released and return.
            return vestedAmount - vestingSchedule.released;
        }
    }

    /**
     * @dev Returns the current time.
     * @return the current timestamp in seconds.
     */
    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
