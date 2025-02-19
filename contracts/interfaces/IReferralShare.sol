// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IReferralShare
 * @dev Interface for the ReferralShare contract
 */
interface IReferralShare {
    /// @notice Reverts when an unsupported token is used
    error UnsupportedToken();

    /// @notice Reverts when an already supported token is trying to be added
    error AlreadySupportedToken();

    /// @notice Reverts when the caller is not whitelisted
    error NotWhitelisted();

    /// @notice Reverts when the caller is already whitelisted
    error AlreadyWhitelisted();

    /// @notice Reverts when the provided address is invalid (e.g., zero address)
    error InvalidAddress();

    /// @notice Event emitted when tokens or ether are deposited to a referral code
    event DepositRecorded(
        string indexed referralCode,
        address indexed token,
        uint256 amount
    );

    /// @notice Event emitted when tokens or ether are withdrawn for a referral code
    event WithdrawalRecorded(
        string indexed referralCode,
        address indexed token,
        uint256 amount
    );

    /// @notice Event emitted when a token is added to the supported list
    event TokenAdded(address token);

    /// @notice Event emitted when a token is removed from the supported list
    event TokenRemoved(address token);

    /// @notice Event emitted when a contract is added to the whitelist
    event ContractWhitelisted(address contractAddress);

    /// @notice Event emitted when a contract is removed from the whitelist
    event ContractRemovedFromWhitelist(address contractAddress);

    /// @dev Event emitted when the Verification address is updated
    event VerificationAddressUpdated(address newKYCAMLVerification);

    /**
     * @dev Records tokens or ether deposited to a referral code
     * @param _referralCode The referral code to credit
     * @param _token Address of the token being deposited (use address(0) for ether)
     * @param _amount Amount of tokens or ether to record
     */
    function recordDeposit(
        string memory _referralCode,
        address _token,
        uint256 _amount
    ) external;

    /**
     * @dev Withdraws all tokens and ether for a referral code
     * @param _referralCode The referral code to withdraw from
     * @param _timestamp The timestamp of request withdrawal
     * @param _signature Backend signer signature
     */
    function withdrawBalances(
        string memory _referralCode,
        uint256 _timestamp,
        bytes memory _signature
    ) external;

    /**
     * @dev Adds a token to the list of supported tokens. Only the owner can call this function.
     * @param _token Address of the token to add
     */
    function addSupportedToken(address _token) external;

    /**
     * @dev Removes a token from the list of supported tokens. Only the owner can call this function.
     * @param _token Address of the token to remove
     */
    function removeSupportedToken(address _token) external;

    /**
     * @dev Adds a contract to the whitelist. Only the owner can call this function.
     * @param _contractAddress Address of the contract to whitelist
     */
    function addWhitelistedContract(address _contractAddress) external;

    /**
     * @dev Removes a contract from the whitelist. Only the owner can call this function.
     * @param _contractAddress Address of the contract to remove
     */
    function removeWhitelistedContract(address _contractAddress) external;

    /**
     * @dev Updates the Verification contract address.
     * @param _newVerification New Verification contract address
     */
    function updateVerificationContractAddress(address _newVerification) external;

    /**
     * @dev Retrieves the balance of a referral code for a specific token
     * @param _referralCode The referral code to query
     * @param _token Address of the token
     * @return The balance of the token for the referral code
     */
    function getReferralBalance(
        string memory _referralCode,
        address _token
    ) external view returns (uint256);

    /**
     * @dev Returns the list of all supported token addresses.
     * @return An array of addresses representing the supported tokens, including the address(0) for native Ether.
     */
    function getSupportedTokens() external view returns (address[] memory);
}
