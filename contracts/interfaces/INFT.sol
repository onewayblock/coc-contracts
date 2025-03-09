// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title INFT
 * @dev Interface for the NFT contract with metadata management and whitelisting.
 */
interface INFT {
    /// @dev Error when the signer of the message is invalid or unauthorized
    error InvalidSigner();

    /// @dev Error when the provided address is invalid (e.g., zero address)
    error InvalidAddress();

    /// @dev Error when the caller is not whitelisted
    error NotWhitelisted();

    /// @dev Error when the caller is already whitelisted
    error AlreadyWhitelisted();

    /// @dev Error when the metadata count does not match the quantity of tokens minted
    error InvalidMetadataCount();

    /// @notice Reverts when hash was already used
    error InvalidMessageHash();

    /// @notice Reverts when token not exists
    error InvalidTokenId();

    /// @notice Reverts when transfers are locked
    error TransfersAreLocked();

    /// @dev Error thrown when invalid royalty basis points
    error InvalidRoyaltyBasisPoints();

    /// @dev Error when received invalid parameters length
    error InvalidParameters();

    /// @dev Error when duplicated tokens in the array
    error DuplicateTokenUpdate();

    /// @notice Event emitted when the backend signer address is updated
    event BackendSignerChanged(address newBackendSigner);

    /// @notice Event emitted when a contract is added to the whitelist
    event ContractWhitelisted(address contractAddress);

    /// @notice Event emitted when a contract is removed from the whitelist
    event ContractRemovedFromWhitelist(address contractAddress);

    /// @notice Emitted when royalty info is updated
    event RoyaltyInfoUpdated(
        address indexed receiver,
        uint96 royaltyBasisPoints
    );

    /// @notice Event emitted when transfers are unlocked
    event TransfersUnlocked();

    /// @notice Emitted when the metadata of a single token is updated.
    event MetadataUpdate(uint256 _tokenId);

    /// @notice Emitted when the metadata of a range of tokens is updated in batch.
    event BatchMetadataUpdate(
        uint256 indexed fromTokenId,
        uint256 indexed toTokenId
    );

    /// @notice Event emitted when contract URI changed
    event ContractURIUpdated();

    /**
     * @notice Updates the backend signer address. Only the contract owner can call this function.
     * @param _newSigner The new backend signer address
     */
    function setBackendSigner(address _newSigner) external;

    /**
     * @notice Adds a contract to the whitelist. Only the owner can call this function.
     * @param _contractAddress Address of the contract to whitelist
     */
    function addWhitelistedContract(address _contractAddress) external;

    /**
     * @notice Removes a contract from the whitelist. Only the owner can call this function.
     * @param _contractAddress Address of the contract to remove
     */
    function removeWhitelistedContract(address _contractAddress) external;

    /**
     * @notice Mints multiple tokens and assigns metadata to each.
     * @param _to Recipient of the tokens
     * @param _quantity Number of tokens to mint
     * @param _metadata Array of metadata strings for each token
     */
    function mint(
        address _to,
        uint256 _quantity,
        string[] memory _metadata
    ) external;

    /**
     * @notice Mints multiple tokens with the same metadata.
     * @param _to Recipient of the tokens
     * @param _quantity Number of tokens to mint
     * @param _metadata Metadata to assign to all minted tokens
     */
    function mintWithSameMetadata(
        address _to,
        uint256 _quantity,
        string memory _metadata
    ) external;

    /**
     * @notice Updates metadata for a specific token with a backend signature.
     * @param _tokenId Token ID to update
     * @param _newMetadata New metadata string
     * @param _timestamp Timestamp of request to make hash unique
     * @param _signature Backend signature
     */
    function updateMetadata(
        uint256 _tokenId,
        string memory _newMetadata,
        uint256 _timestamp,
        bytes memory _signature
    ) external;

    /**
     * @notice Updates metadata for a specific token with a backend signature.
     * @param _tokenIds Array of token IDs to update
     * @param _newMetadatas Array of new metadata strings
     * @param _timestamp Timestamp of request to make hash unique
     * @param _signatures Array of backend signature
     */
    function updateMetadataBatch(
        uint256[] memory _tokenIds,
        string[] memory _newMetadatas,
        uint256 _timestamp,
        bytes[] memory _signatures
    ) external;

    /**
     * @notice Returns the metadata for a contract.
     * @return string Metadata of the contract
     */
    function contractURI() external view returns (string memory);

    /**
     * @notice Set the metadata for a contract.
     */
    function setContractURI(string memory _contractURI) external;

    /**
     * @notice Checks if a contract is whitelisted.
     * @param _contractAddress Address of the contract to check
     * @return bool True if the contract is whitelisted, false otherwise
     */
    function isContractWhitelisted(
        address _contractAddress
    ) external view returns (bool);
}
