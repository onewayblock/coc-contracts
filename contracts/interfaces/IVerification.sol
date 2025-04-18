// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IVerification
 * @dev Interface for the Verification contract.
 */
interface IVerification {
    /// @notice Tracks user verification statuses
    struct UserVerification {
        bool baseKyc;
        bool advancedKyc;
        uint256 baseAMLScore;
        uint256 advancedAMLScore;
    }

    /// @notice Struct to store spending history
    struct SpendingRecord {
        uint256 amount;
        uint256 timestamp;
        address contractAddress;
    }

    /// @notice Reverts when the caller is not an allowed contract
    error NotAllowedContract();

    /// @notice Reverts when the signer of the message is invalid or unauthorized
    error InvalidSigner();

    /// @notice Reverts when the provided address is invalid (e.g., zero address)
    error InvalidAddress();

    /// @notice Reverts when AML/KYC requirements are not met
    error AMLKYCCheckFailed();

    /// @notice Reverts when configuration is invalid
    error InvalidConfiguration();

    /// @notice Reverts when hash was already used
    error InvalidMessageHash();

    /// @notice Event emitted when base KYC is updated
    event BaseKycUpdated(address indexed user, bool baseKyc);

    /// @notice Event emitted when advanced KYC is updated
    event AdvancedKycUpdated(address indexed user, bool advancedKyc);

    /// @notice Event emitted when base AML score is updated
    event BaseAMLScoreUpdated(address indexed user, uint256 baseAMLScore);

    /// @notice Event emitted when advanced AML score is updated
    event AdvancedAMLScoreUpdated(
        address indexed user,
        uint256 advancedAMLScore
    );

    /// @notice Event emitted when the backend signer address is updated
    event BackendSignerChanged(address newBackendSigner);

    /// @notice Event emitted when spending is recorded
    event SpendingRecorded(
        address indexed user,
        uint256 amount,
        address indexed contractAddress
    );

    /// @notice Event emitted when spending limits are updated
    event SpendingLimitsUpdated(
        uint256 baseAmlLimit,
        uint256 advancedAmlLimit,
        uint256 baseKycLimit,
        uint256 advancedKycLimit
    );

    /// @notice Event emitted when AML score limits are updated
    event AMLScoreLimitsUpdated(
        uint256 baseAmlScoreLimit,
        uint256 advancedAmlScoreLimit
    );

    /// @notice Event emitted when treasure config is updated
    event TreasureConfigurationUpdated(
        address treasureFirstAddress,
        address treasureSecondAddress,
        uint256 treasureFirstPercentage,
        uint256 treasureSecondPercentage
    );

    /**
     * @dev Updates the base KYC status for the user.
     * @param _user The user address
     * @param _baseKyc The new base KYC status
     * @param _timestamp Timestamp of request to make hash unique
     * @param _signature The signature generated by the backend signer
     */
    function setBaseKyc(
        address _user,
        bool _baseKyc,
        uint256 _timestamp,
        bytes memory _signature
    ) external;

    /**
     * @dev Updates the advanced KYC status for the user.
     * @param _user The user address
     * @param _advancedKyc The new advanced KYC status
     * @param _timestamp Timestamp of request to make hash unique
     * @param _signature The signature generated by the backend signer
     */
    function setAdvancedKyc(
        address _user,
        bool _advancedKyc,
        uint256 _timestamp,
        bytes memory _signature
    ) external;

    /**
     * @dev Updates the base AML score for the user.
     * @param _user The user address
     * @param _baseAMLScore The new base AML score
     * @param _timestamp Timestamp of request to make hash unique
     * @param _signature The signature generated by the backend signer
     */
    function setBaseAMLScore(
        address _user,
        uint256 _baseAMLScore,
        uint256 _timestamp,
        bytes memory _signature
    ) external;

    /**
     * @dev Updates the advanced AML score for the user.
     * @param _user The user address
     * @param _advancedAMLScore The new advanced AML score
     * @param _timestamp Timestamp of request to make hash unique
     * @param _signature The signature generated by the backend signer
     */
    function setAdvancedAMLScore(
        address _user,
        uint256 _advancedAMLScore,
        uint256 _timestamp,
        bytes memory _signature
    ) external;

    /**
     * @dev Retrieves the verification status for a user.
     * @param _user The address of the user
     * @return The verification data of the user
     */
    function getVerification(
        address _user
    ) external view returns (UserVerification memory);

    /**
     * @dev Records user spending
     * @param _user Address of the user
     * @param _amount Amount of USD spent
     */
    function recordSpending(address _user, uint256 _amount) external;

    /**
     * @dev Returns the total spending of a user in USD
     * @param _user Address of the user
     * @return Total spending in USD
     */
    function getTotalSpending(address _user) external view returns (uint256);

    /**
     * @dev Returns the spending history of a user
     * @param _user Address of the user
     * @return Array of SpendingRecord structs
     */
    function getSpendingHistory(
        address _user
    ) external view returns (SpendingRecord[] memory);

    /**
     * @dev Adds a contract to the list of allowed contracts
     * @param _contractAddress Address of the contract to add
     */
    function addAllowedContract(address _contractAddress) external;

    /**
     * @dev Removes a contract from the list of allowed contracts
     * @param _contractAddress Address of the contract to remove
     */
    function removeAllowedContract(address _contractAddress) external;

    /**
     * @dev Updates the backend signer address. Only the contract owner can call this function.
     * @param _newSigner The new backend signer address
     */
    function setBackendSigner(address _newSigner) external;

    /**
     * @dev Performs AML/KYC checks for a user based on the specified amount
     * @param _user Address of the user
     * @param _amount Amount of USD spent
     */
    function validateSpending(address _user, uint256 _amount) external view;

    /**
     * @dev Updates the spending limits for AML/KYC checks
     * @param _baseAmlLimit New limit for base AML
     * @param _advancedAmlLimit New limit for advanced AML
     * @param _baseKycLimit New limit for base KYC
     * @param _advancedKycLimit New limit for advanced KYC
     */
    function updateSpendingLimits(
        uint256 _baseAmlLimit,
        uint256 _advancedAmlLimit,
        uint256 _baseKycLimit,
        uint256 _advancedKycLimit
    ) external;

    /**
     * @dev Updates the AML score limits for AML checks
     * @param _baseAmlScoreLimit New limit for base AML
     * @param _advancedAmlScoreLimit New limit for advanced AML
     */
    function updateAMLScoreLimits(
        uint256 _baseAmlScoreLimit,
        uint256 _advancedAmlScoreLimit
    ) external;

    /**
     * @dev Verifies the validity of a signature against a message hash.
     * @param _messageHash The encoded data being verified
     * @param _signature The signature to verify
     */
    function verifySignaturePublic(
        bytes32 _messageHash,
        bytes memory _signature
    ) external;

    /**
     * @notice Sets the treasure addresses and their respective percentages.
     * @param _treasureFirstAddress Address of the first treasure
     * @param _treasureSecondAddress Address of the second treasure
     * @param _treasureFirstPercentage Percentage allocated to the first treasure
     * @param _treasureSecondPercentage Percentage allocated to the second treasure
     */
    function setTreasureConfiguration(
        address _treasureFirstAddress,
        address _treasureSecondAddress,
        uint256 _treasureFirstPercentage,
        uint256 _treasureSecondPercentage
    ) external;

    /**
     * @notice Returns the treasure configuration.
     * @return firstTreasure Address of the first treasure
     * @return secondTreasure Address of the second treasure
     * @return firstTreasurePercentage Percentage of funds allocated to the first treasure (in basis points)
     * @return secondTreasurePercentage Percentage of funds allocated to the second treasure (in basis points)
     */
    function getTreasureConfiguration()
        external
        view
        returns (
            address firstTreasure,
            address secondTreasure,
            uint256 firstTreasurePercentage,
            uint256 secondTreasurePercentage
        );
}
