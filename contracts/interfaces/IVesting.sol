// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

interface IVesting {
    struct VestingSchedule {
        // beneficiary of tokens after they are released
        address beneficiary;
        // cliff time of the vesting start in seconds since the UNIX epoch
        uint256 cliff;
        // start time of the vesting period in seconds since the UNIX epoch
        uint256 start;
        // duration of the vesting period in seconds
        uint256 duration;
        // duration of a slice period for the vesting in seconds
        uint256 slicePeriodSeconds;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        // amount of tokens released
        uint256 released;
    }

    /// @notice Error if the address is invalid (e.g., zero address).
    error InvalidAddress();

    /// @notice Error if there are not enough tokens to create a vesting schedule.
    error InsufficientTokens();

    /// @notice Error if the duration is not greater than zero.
    error InvalidDuration();

    /// @notice Error if the amount is not greater than zero.
    error InvalidAmount();

    /// @notice Error if the slice period is less than one second.
    error InvalidSlicePeriod();

    /// @notice Error if the duration is less than the cliff.
    error InvalidCliff();

    /// @notice Error if the index is out of bounds.
    error IndexOutOfBounds();

    /// @notice Error if the caller is not the beneficiary or owner.
    error Unauthorized();

    /// @notice Error if there are not enough withdrawable funds.
    error InsufficientWithdrawableFunds();

    /// @notice Error if there are no existing vesting schedules for user.
    error NoVestingSchedules();

    /// @notice Event emitted when a vesting schedule is created
    event VestingScheduleCreated(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 start,
        uint256 cliff,
        uint256 duration,
        uint256 slicePeriodSeconds,
        uint256 amount
    );

    /// @notice Event emitted when tokens are released
    event TokensReleased(bytes32 indexed vestingScheduleId, uint256 amount);

    /// @notice Event emitted when funds are withdrawn
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    /// @notice Event emitted when the staking address is updated
    event StakingAddressUpdated(address newStakingAddress);

    /**
     * @notice Sets the staking address.
     * @dev Only callable by the owner.
     * @param _staking The new staking address
     */
    function setStakingAddress(address _staking) external;

    /**
     * @notice Creates a new vesting schedule for a beneficiary.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _start start time of the vesting period
     * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration duration in seconds of the period in which the tokens will vest
     * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
     * @param _amount total amount of tokens to be released at the end of the vesting
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        uint256 _amount
    ) external;

    /**
     * @notice Withdraw the specified amount if possible.
     * @param amount the amount to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Release vested amount of tokens.
     * @param vestingScheduleId the vesting schedule identifier
     * @return the amount of tokens released
     */
    function release(bytes32 vestingScheduleId) external returns (uint256);

    /**
     * @notice Release vested amount of tokens and stake them.
     * @dev Only callable by the staking contract.
     * @param vestingScheduleId the vesting schedule identifier
     * @param beneficiary the address of the beneficiary
     * @return the amount of tokens released
     */
    function releaseAndStake(
        bytes32 vestingScheduleId,
        address beneficiary
    ) external returns (uint256);

    /**
     * @dev Returns the number of vesting schedules associated to a beneficiary.
     * @param _beneficiary address of the beneficiary
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCountByBeneficiary(
        address _beneficiary
    ) external view returns (uint256);

    /**
     * @dev Returns the vesting schedule id at the given index.
     * @param index index of the vesting schedule
     * @return the vesting id
     */
    function getVestingIdAtIndex(uint256 index) external view returns (bytes32);

    /**
     * @notice Returns the vesting schedule information for a given holder and index.
     * @param holder address of the holder
     * @param index index of the vesting schedule
     * @return the vesting schedule structure information
     */
    function getVestingScheduleByAddressAndIndex(
        address holder,
        uint256 index
    ) external view returns (VestingSchedule memory);

    /**
     * @notice Returns the total amount of vesting schedules.
     * @return the total amount of vesting schedules
     */
    function getVestingSchedulesTotalAmount() external view returns (uint256);

    /**
     * @dev Returns the address of the ERC20 token managed by the vesting contract.
     * @return the address of the ERC20 token
     */
    function getToken() external view returns (address);

    /**
     * @dev Returns the number of vesting schedules managed by this contract.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCount() external view returns (uint256);

    /**
     * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
     * @param vestingScheduleId the vesting schedule identifier
     * @return the vested amount
     */
    function computeReleasableAmount(
        bytes32 vestingScheduleId
    ) external view returns (uint256);

    /**
     * @dev Returns the last vesting schedule for a given holder address.
     * @param holder address of the holder
     * @return the last vesting schedule
     */
    function getLastVestingScheduleForHolder(
        address holder
    ) external view returns (VestingSchedule memory);
}
