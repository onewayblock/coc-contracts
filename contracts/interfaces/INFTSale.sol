// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title INFTSale
 * @dev Interface for the NFTSale contract.
 */
interface INFTSale {
    /// @notice Stores details of an NFT sale
    struct NFTSale {
        address NFTContract;
        string tokenMetadata;
        uint256 quantity;
        uint256 soldQuantity;
        bool isActive;
        uint256 USDPrice;
        uint256 totalLimitPerUser;
        uint256 onetimeLimitPerUser;
    }

    /// @dev Error when a token is already supported
    error TokenAlreadySupported();

    /// @dev Error when a token is not supported
    error TokenNotSupported();

    /// @dev Error when a sender address is invalid
    error InvalidSender();

    /// @dev Error when a provided address is invalid
    error InvalidAddress();

    /// @notice Reverts when the provided quantity is zero
    error InvalidQuantity();

    /// @dev Reverts when the provided price is zero
    error InvalidPrice();

    /// @notice Reverts when trying to interact with a non-existent sale
    error SaleDoesNotExist();

    /// @notice Reverts when trying to renew a sale that is already active
    error SaleAlreadyActive();

    /// @notice Reverts when trying to stop a sale that is already stopped
    error SaleAlreadyStopped();

    /// @dev Error when insufflient ETH sent
    error InsufflientETHSent();

    /// @dev Error when user setted invalid slippage tolerance
    error InvalidSlippage();

    /// @dev Error when  provided invalid expected amount of tokens
    error InvalidExpectedAmount();

    /// @dev Error when we're sending ethereum to address
    error ETHSendFailed();

    /// @dev Error when provided duplicated address
    error DuplicateAddress();

    /// @dev Error when user send ETH while payment token is different
    error ETHNotAllowedWithTokenPayment();

    /// @dev Error when we want to send ETH to empty contract
    error ContractCannotReceiveETH();

    /// @dev Error when expected token amount exceeds deviation
    error expectedTokenAmountExceedsDeviation();

    /// @dev Error when trying to delist NFT where at least 1 NFT was sold
    error SaleAlreadyStarted();

    /// @dev Event emitted when a token is added to the payment list
    event PaymentTokenAdded(address token);

    /// @dev Event emitted when a token is removed from the payment list
    event PaymentTokenRemoved(address token);

    /// @dev Event emitted when the Verification address is updated
    event VerificationAddressUpdated(address newKYCAMLVerification);

    /// @dev Event emitted when user bought NFT
    event NFTBought(
        uint256 saleId,
        address buyer,
        uint256 USDAmount,
        address paymentToken,
        uint256 paymentTokenAmount,
        address NFTContract,
        uint256 quantity
    );

    /// @dev Event emitted when user bought NFT
    event NFTBoughtFromCrossmint(
        uint256 saleId,
        address buyer,
        uint256 USDAmount,
        address paymentToken,
        uint256 paymentTokenAmount,
        address NFTContract,
        uint256 quantity
    );

    /// @notice Event emitted when an NFT is listed for sale
    event NFTListedForSale(
        uint256 indexed saleId,
        address indexed NFTContract,
        string tokenMetadata,
        uint256 quantity,
        bool status,
        uint256 USDPrice,
        uint256 totalLimitPerUser,
        uint256 onetimeLimitPerUser
    );

    /// @notice Event emitted when an NFT sale is delisted
    event NFTDelisted(uint256 indexed saleId);

    /// @notice Event emitted when an NFT sale is stopped
    event NFTSaleStopped(uint256 indexed saleId);

    /// @notice Event emitted when an NFT sale is renewed
    event NFTSaleRenewed(uint256 indexed saleId);

    /// @notice Event emitted when NFTs are minted
    event NFTsMinted(
        address indexed nftContract,
        address indexed to,
        uint256 quantity,
        string metadata
    );

    /**
     * @dev Adds a payment token to the list.
     * @param _token Address of the token to add
     */
    function addPaymentToken(address _token) external;

    /**
     * @dev Removes a payment token from the list.
     * @param _token Address of the token to remove
     */
    function removePaymentToken(address _token) external;

    /**
     * @dev Updates the Verification contract address.
     * @param _newVerification New Verification contract address
     */
    function updateVerificationContractAddress(
        address _newVerification
    ) external;

    /**
     * @notice Lists an NFT for sale
     * @param _NFTContract Address of the NFT contract
     * @param _tokenMetadata Metadata associated with the NFT
     * @param _quantity Number of NFTs available for sale
     * @param _status Initial status of the sale (active or not)
     */
    function listNFTForSale(
        address _NFTContract,
        string memory _tokenMetadata,
        uint256 _quantity,
        bool _status,
        uint256 _USDPrice,
        uint256 _totalLimitPerUser,
        uint256 _onetimeLimitPerUser
    ) external;

    /**
     * @notice Delists an NFT sale by its sale ID
     * @param _saleId ID of the sale to delist (only if no NFT's sold)
     */
    function delistNFTFromSale(uint256 _saleId) external;

    /**
     * @notice Stops an ongoing NFT sale (pauses the sale without deleting it)
     * @param _saleId ID of the sale to stop
     */
    function stopNFTSale(uint256 _saleId) external;

    /**
     * @notice Renews (reactivates) a stopped NFT sale
     * @param _saleId ID of the sale to renew
     */
    function renewNFTSale(uint256 _saleId) external;

    /**
     * @notice Fetches the details of an NFT sale by its ID
     * @param _saleId ID of the sale to fetch
     * @return NFTSale Details of the NFT sale
     */
    function getNFTSaleDetails(
        uint256 _saleId
    ) external view returns (NFTSale memory);

    /**
     * @notice Mints NFTs to a specified address in a given contract.
     * @param _nftContract Address of the NFT contract
     * @param _to Address to receive the NFTs
     * @param _quantity Number of NFTs to mint
     * @param _metadata Metadata to assign to the minted NFTs
     * @param _timestamp Timestamp of request to make hash unique
     * @param _signature Signature of backend for action
     */
    function mintNFTs(
        address _nftContract,
        address _to,
        uint256 _quantity,
        string memory _metadata,
        uint256 _timestamp,
        bytes memory _signature
    ) external;

    /**
     * @dev Returns the list of supported payment tokens.
     * @return Array of supported token addresses.
     */
    function getSupportedTokens() external view returns (address[] memory);
}
