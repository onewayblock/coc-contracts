// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IClaim {
    /// @notice Reverts when Merkle root not specified
    error NoMerkleRoot();

    /// @notice Reverts when the provided Merkle proof is invalid
    error InvalidProof();

    /// @notice Reverts when the provided tokens value is zero or invalid
    error InvalidTokens();

    /// @notice Reverts when the provided receiver is not msg.sender
    error InvalidReceiver();

    /// @notice Reverts when the provided address is invalid (e.g., zero address)
    error InvalidAddress();

    /// @notice Reverts when a user tries to claim tokens more than once
    error TokensAlreadyClaimed();

    /// @notice Reverts when contract does not have enough tokens
    error InsufficientBalance();

    /// @notice Reverts when the unlock time is in the past
    error InvalidUnlockTime();

    /// @notice Reverts when the withdraw function is called before the unlock time
    error WithdrawLocked();

    /// @notice Reverts when the amount to withdraw is zero
    error InvalidAmount();

    /// @notice Reverts when the contract has insufficient balance for withdrawal
    error InsufficientContractBalance();

    /// @notice Event emitted when the Merkle root is updated
    event MerkleRootUpdated(bytes32 newMerkleRoot);

    /// @notice Event emitted when the token address is updated
    event TokenAddressUpdated(address newTokenAddress);

    /// @notice Event emitted when the staking address is updated
    event StakingAddressUpdated(address newStakingAddress);

    /// @notice Event emitted when tokens are claimed
    event TokensClaimed(address indexed user, uint256 tokens);

    /**
     * @notice Event emitted when tokens are withdrawn by the owner.
     * @param owner The address of the owner who withdrew the tokens
     * @param amount The amount of tokens withdrawn
     */
    event TokensWithdrawn(address indexed owner, uint256 amount);

    /**
     * @notice Sets the Merkle root.
     * @dev Only callable by the owner.
     * @param _merkleRoot The new Merkle root
     */
    function setMerkleRoot(bytes32 _merkleRoot) external;

    /**
     * @notice Sets the token address.
     * @dev Only callable by the owner.
     * @param _token The new token address
     */
    function setTokenAddress(address _token) external;

    /**
     * @notice Sets the staking address.
     * @dev Only callable by the owner.
     * @param _staking The new staking address
     */
    function setStakingAddress(address _staking) external;

    /**
     * @notice Allows a user to claim tokens and optionally stake them.
     * @dev Reverts if the user has already claimed tokens, the proof is invalid, or the contract has insufficient balance.
     * @param receiver The receiver of the tokens
     * @param tokens The total number of tokens the user is eligible to claim
     * @param proof The Merkle proof verifying the user's eligibility
     */
    function claimTokens(
        address receiver,
        uint256 tokens,
        bytes32[] calldata proof
    ) external;

    /**
     * @notice Withdraws a specific amount of tokens from the contract.
     * @dev Only the owner can call this function, and it can only be called after the unlock time has passed.
     * @param amount The amount of tokens to withdraw
     */
    function withdrawTokens(uint256 amount) external;

    /**
     * @dev Checks if a user is part of the current Merkle tree.
     * @param user The address of the user to check
     * @param tokens The number of tokens the user is eligible to claim
     * @param proof The Merkle proof verifying the user's eligibility
     * @return bool True if the user is part of the Merkle tree, false otherwise
     */
    function isParticipating(
        address user,
        uint256 tokens,
        bytes32[] calldata proof
    ) external view returns (bool);
}
