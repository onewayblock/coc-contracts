// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {UniswapHelper} from "./UniswapHelper.sol";
import {INFTSale} from "./interfaces/INFTSale.sol";
import {INFT} from "./interfaces/INFT.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVerification} from "./interfaces/IVerification.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title NFTSale
 * @dev Contract for NFT sale with referral sharing.
 * @dev Implementation of the INFTSale interface
 */
abstract contract NFTSale is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    INFTSale
{
    using SafeERC20 for IERC20;

    using ECDSA for bytes32;

    /// @notice Supported payment tokens
    address[] private supportedTokens;

    /// @notice Mapping of sale ID to NFT sale details
    mapping(uint256 => NFTSale) public nftSales;

    /// @notice Mapping of bought tokens per user per sale
    mapping(address => mapping(uint256 => uint256)) public usersBoughtQuantity;

    /// @notice Counter to generate unique sale IDs
    uint256 public saleCounter;

    /// @notice Address of the Verification contract
    address public verification;

    /// @notice Address of the Uniswap Helper
    address public uniswapHelper;

    /// @notice Trusted forwarder address for meta-transactions
    address public trustedForwarder;

    /// @notice Crossmint address
    address public crossmintAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the necessary parameters.
     * @param _verification Address of the Verification contract
     * @param _uniswapHelper Address of the Uniswap Helper contract
     * @param _crossmintAddress Crossmint address
     * @param _paymentTokens Initial list of payment tokens
     * @param _owner Address of the contract owner
     */
    function __NFTSale_init(
        address _verification,
        address _uniswapHelper,
        address _crossmintAddress,
        address[] memory _paymentTokens,
        address _owner
    ) internal onlyInitializing {
        __NFTSale_init_unchained(
            _verification,
            _uniswapHelper,
            _crossmintAddress,
            _paymentTokens,
            _owner
        );
    }

    /**
     * @dev Initializes the contract with the necessary parameters.
     * @param _verification Address of the verification contract
     * @param _uniswapHelper Address of the Uniswap Helper contract
     * @param _crossmintAddress Crossmint address
     * @param _paymentTokens Initial list of payment tokens
     * @param _owner Address of the contract owner
     */
    function __NFTSale_init_unchained(
        address _verification,
        address _uniswapHelper,
        address _crossmintAddress,
        address[] memory _paymentTokens,
        address _owner
    ) internal onlyInitializing {
        if (
            _verification == address(0) ||
            _uniswapHelper == address(0) ||
            _crossmintAddress == address(0) ||
            _owner == address(0)
        ) {
            revert InvalidAddress();
        }

        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        verification = _verification;
        uniswapHelper = _uniswapHelper;
        crossmintAddress = _crossmintAddress;

        uint256 length = _paymentTokens.length;

        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = 0; j < i; j++) {
                if (_paymentTokens[i] == _paymentTokens[j]) {
                    revert DuplicateAddress();
                }
            }

            supportedTokens.push(_paymentTokens[i]);
        }
    }

    /**
     * @inheritdoc INFTSale
     */
    function getSupportedTokens()
        external
        view
        override
        returns (address[] memory)
    {
        return supportedTokens;
    }

    /**
     * @inheritdoc INFTSale
     */
    function addPaymentToken(address _token) external override onlyOwner {
        if (_isTokenSupported(_token)) {
            revert TokenAlreadySupported();
        }

        supportedTokens.push(_token);
        emit PaymentTokenAdded(_token);
    }

    /**
     * @notice change crossmint contract address
     * @param _crossmintAddress Address of the Crossmint contract
     */
    function changeCrossmintAddress(
        address _crossmintAddress
    ) external onlyOwner {
        if (_crossmintAddress == address(0)) {
            revert InvalidAddress();
        }

        crossmintAddress = _crossmintAddress;
    }

    /**
     * @inheritdoc INFTSale
     */
    function removePaymentToken(address _token) external override onlyOwner {
        if (!_removePaymentToken(_token)) {
            revert TokenNotSupported();
        }

        emit PaymentTokenRemoved(_token);
    }

    /**
     * @inheritdoc INFTSale
     */
    function updateVerificationContractAddress(
        address _newVerification
    ) external override onlyOwner {
        if (_newVerification == address(0)) {
            revert InvalidAddress();
        }

        verification = _newVerification;
        emit VerificationAddressUpdated(_newVerification);
    }

    /**
     * @inheritdoc INFTSale
     */
    function listNFTForSale(
        address _NFTContract,
        string memory _tokenMetadata,
        uint256 _quantity,
        bool _status,
        uint256 _USDPrice,
        uint256 _totalLimitPerUser,
        uint256 _onetimeLimitPerUser
    ) external override onlyOwner {
        if (_NFTContract == address(0)) {
            revert InvalidAddress();
        }
        if (
            _quantity == 0 ||
            _totalLimitPerUser == 0 ||
            _onetimeLimitPerUser == 0 ||
            _onetimeLimitPerUser > _totalLimitPerUser
        ) {
            revert InvalidQuantity();
        }
        if (_USDPrice == 0) {
            revert InvalidPrice();
        }

        saleCounter++;

        nftSales[saleCounter] = NFTSale({
            NFTContract: _NFTContract,
            tokenMetadata: _tokenMetadata,
            quantity: _quantity,
            soldQuantity: 0,
            isActive: _status,
            USDPrice: _USDPrice,
            totalLimitPerUser: _totalLimitPerUser,
            onetimeLimitPerUser: _onetimeLimitPerUser
        });

        emit NFTListedForSale(
            saleCounter,
            _NFTContract,
            _tokenMetadata,
            _quantity,
            _status,
            _USDPrice,
            _totalLimitPerUser,
            _onetimeLimitPerUser
        );
    }

    /**
     * @inheritdoc INFTSale
     */
    function delistNFTFromSale(uint256 _saleId) external override onlyOwner {
        if (nftSales[_saleId].quantity == 0) {
            revert SaleDoesNotExist();
        }

        if (nftSales[_saleId].soldQuantity > 0) {
            revert SaleAlreadyStarted();
        }

        delete nftSales[_saleId];

        emit NFTDelisted(_saleId);
    }

    /**
     * @inheritdoc INFTSale
     */
    function stopNFTSale(uint256 _saleId) external override onlyOwner {
        if (nftSales[_saleId].quantity == 0) {
            revert SaleDoesNotExist();
        }
        if (!nftSales[_saleId].isActive) {
            revert SaleAlreadyStopped();
        }

        nftSales[_saleId].isActive = false;

        emit NFTSaleStopped(_saleId);
    }

    /**
     * @inheritdoc INFTSale
     */
    function renewNFTSale(uint256 _saleId) external override onlyOwner {
        if (nftSales[_saleId].quantity == 0) {
            revert SaleDoesNotExist();
        }
        if (nftSales[_saleId].isActive) {
            revert SaleAlreadyActive();
        }

        nftSales[_saleId].isActive = true;

        emit NFTSaleRenewed(_saleId);
    }

    /**
     * @inheritdoc INFTSale
     */
    function getNFTSaleDetails(
        uint256 _saleId
    ) external view override returns (NFTSale memory) {
        if (nftSales[_saleId].quantity == 0) {
            revert SaleDoesNotExist();
        }
        return nftSales[_saleId];
    }

    /**
     * @notice Allows a user to purchase NFTs from a sale
     * @param _saleId ID of the sale to purchase from
     * @param _quantity Quantity of NFTs to purchase
     * @param _paymentToken Address of the token used for payment
     * @param _expectedTokenAmount Expected token amount by the user
     * @param _slippageTolerance Slippage tolerance in basis points (e.g., 300 for 3%)
     */
    function _buyNFT(
        uint256 _saleId,
        uint256 _quantity,
        address _paymentToken,
        uint256 _expectedTokenAmount,
        uint256 _slippageTolerance
    ) internal {
        address sender = _msgSender();

        if (!_isTokenSupported(_paymentToken)) {
            revert TokenNotSupported();
        }
        if (_slippageTolerance == 0 || _slippageTolerance > 3000) {
            revert InvalidSlippage();
        }
        if (_expectedTokenAmount == 0) {
            revert InvalidExpectedAmount();
        }
        if (_paymentToken != address(0) && msg.value > 0) {
            revert ETHNotAllowedWithTokenPayment();
        }

        NFTSale storage sale = nftSales[_saleId];
        if (sale.quantity == 0) {
            revert SaleDoesNotExist();
        }

        if (!sale.isActive) {
            revert SaleAlreadyStopped();
        }

        if (
            _quantity == 0 ||
            _quantity > (sale.quantity - sale.soldQuantity) ||
            _quantity > sale.onetimeLimitPerUser ||
            _quantity + usersBoughtQuantity[sender][_saleId] >
            sale.totalLimitPerUser
        ) {
            revert InvalidQuantity();
        }

        uint256 totalUSDAmount = sale.USDPrice * _quantity;

        uint256 tokenAmount = totalUSDAmount;

        IVerification(verification).validateSpending(sender, totalUSDAmount);

        if (_paymentToken != UniswapHelper(uniswapHelper).getUSDCAddress()) {
            UniswapHelper(uniswapHelper).checkPrice(
                _paymentToken,
                totalUSDAmount,
                _expectedTokenAmount,
                _slippageTolerance,
                1800 //30 min
            );

            tokenAmount = UniswapHelper(uniswapHelper).getTokenAmount(
                totalUSDAmount,
                _paymentToken,
                _expectedTokenAmount,
                _slippageTolerance
            );
        }

        _handlePayment(_paymentToken, tokenAmount, sender);

        _finalizeNFTPurchase(
            _saleId,
            _quantity,
            _paymentToken,
            tokenAmount,
            tokenAmount,
            totalUSDAmount,
            sender,
            sale
        );
    }

    /**
     * @notice Allows a user to purchase NFTs from a sale
     * @param _saleId ID of the sale to purchase from
     * @param _receiver Address of NFT receiver
     * @param _quantity Quantity of NFTs to purchase
     */
    function _buyNFTFromCrossmint(
        uint256 _saleId,
        address _receiver,
        uint256 _quantity
    ) internal {
        address sender = _msgSender();
        if (_receiver == address(0)) {
            revert InvalidAddress();
        }
        if (sender != crossmintAddress) {
            revert InvalidSender();
        }

        NFTSale storage sale = nftSales[_saleId];
        if (sale.quantity == 0) {
            revert SaleDoesNotExist();
        }

        if (!sale.isActive) {
            revert SaleAlreadyStopped();
        }

        if (
            _quantity == 0 ||
            _quantity > (sale.quantity - sale.soldQuantity) ||
            _quantity > sale.onetimeLimitPerUser
        ) {
            revert InvalidQuantity();
        }

        address USDC = UniswapHelper(uniswapHelper).getUSDCAddress();
        uint256 totalUSDAmount = sale.USDPrice * _quantity;

        IERC20(USDC).safeTransferFrom(sender, address(this), totalUSDAmount);

        sale.soldQuantity += _quantity;

        sendMoneyToTreasure(USDC, totalUSDAmount);

        INFT(sale.NFTContract).mintWithSameMetadata(
            _receiver,
            _quantity,
            sale.tokenMetadata
        );

        emit NFTBoughtFromCrossmint(
            _saleId,
            _receiver,
            totalUSDAmount,
            USDC,
            totalUSDAmount,
            sale.NFTContract,
            _quantity
        );
    }

    /**
     * @dev Finalizes the NFT purchase by updating sale data, handling payments, recording spending,
     *      distributing referral rewards, minting NFTs, and emitting the purchase event.
     * @param _saleId The ID of the NFT sale
     * @param _quantity The number of NFTs purchased
     * @param _paymentToken The token used for payment
     * @param _tokenAmount The amount of tokens calculated for the purchase
     * @param _totalTokenAmount The total amount of tokens
     * @param _totalUSDAmount The equivalent USD amount of the purchase
     * @param _sender The address of the buyer
     * @param _sale The NFTSale struct storage reference
     */
    function _finalizeNFTPurchase(
        uint256 _saleId,
        uint256 _quantity,
        address _paymentToken,
        uint256 _tokenAmount,
        uint256 _totalTokenAmount,
        uint256 _totalUSDAmount,
        address _sender,
        NFTSale storage _sale
    ) internal {
        _sale.soldQuantity += _quantity;
        IVerification(verification).recordSpending(_sender, _totalUSDAmount);

        usersBoughtQuantity[_sender][_saleId] += _quantity;

        sendMoneyToTreasure(_paymentToken, _totalTokenAmount);

        INFT(_sale.NFTContract).mintWithSameMetadata(
            _sender,
            _quantity,
            _sale.tokenMetadata
        );

        emit NFTBought(
            _saleId,
            _sender,
            _totalUSDAmount,
            _paymentToken,
            _tokenAmount,
            _sale.NFTContract,
            _quantity
        );
    }

    function sendMoneyToTreasure(
        address _paymentToken,
        uint256 _totalTokenAmount
    ) internal {
        (
            address firstTreasure,
            address secondTreasure,
            uint256 firstTreasurePercentage,

        ) = IVerification(verification).getTreasureConfiguration();

        uint256 firstAmount = (_totalTokenAmount * firstTreasurePercentage) /
            10000;
        uint256 secondAmount = _totalTokenAmount - firstAmount;

        if (_paymentToken == address(0)) {
            (bool success1, ) = payable(firstTreasure).call{value: firstAmount}(
                ""
            );
            (bool success2, ) = payable(secondTreasure).call{
                value: secondAmount
            }("");

            if (!success1 || !success2) {
                revert ETHSendFailed();
            }
        } else {
            IERC20(_paymentToken).safeTransfer(firstTreasure, firstAmount);
            IERC20(_paymentToken).safeTransfer(secondTreasure, secondAmount);
        }
    }

    /**
     * @inheritdoc INFTSale
     */
    function mintNFTs(
        address _nftContract,
        address _to,
        uint256 _quantity,
        string memory _metadata,
        uint256 _timestamp,
        bytes memory _signature
    ) external override {
        if (_nftContract == address(0) || _to == address(0)) {
            revert InvalidAddress();
        }
        if (_quantity == 0) {
            revert InvalidQuantity();
        }

        IVerification(verification).verifySignaturePublic(
            keccak256(
                abi.encode(
                    address(this),
                    "mintNFTs",
                    _nftContract,
                    _to,
                    _quantity,
                    _metadata,
                    _timestamp,
                    block.chainid
                )
            ),
            _signature
        );

        INFT(_nftContract).mintWithSameMetadata(_to, _quantity, _metadata);

        emit NFTsMinted(_nftContract, _to, _quantity, _metadata);
    }

    /**
     * @dev Handles payment transfers or refunds excess ETH.
     * @param _paymentToken Address of the payment token
     * @param _tokenAmount Amount of tokens or ETH to handle
     * @param _sender Sender address
     */
    function _handlePayment(
        address _paymentToken,
        uint256 _tokenAmount,
        address _sender
    ) private {
        if (_paymentToken == address(0)) {
            if (msg.value < _tokenAmount) {
                revert InsufflientETHSent();
            }

            // Refund excess ETH
            if (msg.value > _tokenAmount) {
                (bool success, ) = payable(_sender).call{
                    value: msg.value - _tokenAmount
                }("");

                if (!success) {
                    revert ETHSendFailed();
                }
            }
        } else {
            IERC20(_paymentToken).safeTransferFrom(
                _sender,
                address(this),
                _tokenAmount
            );
        }
    }

    /**
     * @dev Checks if a given token is supported.
     * @param _token Address of the token to check.
     * @return Boolean indicating whether the token is supported.
     */
    function _isTokenSupported(address _token) private view returns (bool) {
        uint256 length = supportedTokens.length;

        for (uint256 i = 0; i < length; i++) {
            if (supportedTokens[i] == _token) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Removes a payment token from the supported list.
     * @param _token Address of the token to remove.
     * @return Boolean indicating whether the removal was successful.
     */
    function _removePaymentToken(address _token) private returns (bool) {
        uint256 length = supportedTokens.length;

        for (uint256 i = 0; i < length; i++) {
            if (supportedTokens[i] == _token) {
                supportedTokens[i] = supportedTokens[
                    supportedTokens.length - 1
                ];
                supportedTokens.pop();
                return true;
            }
        }
        return false;
    }

    /*
     * @dev Set the address for paymaster
     * @param _trustedForwarder address of paymaster
     */
    function setTrustedForwarder(address _trustedForwarder) external onlyOwner {
        trustedForwarder = _trustedForwarder;
    }

    /*
     * @dev Returns the actual sender of the call. If the call came through the trusted forwarder,
     * extracts the original sender from the end of calldata; otherwise, returns msg.sender.
     */
    function _msgSender() internal view override returns (address sender) {
        if (msg.sender == trustedForwarder && msg.data.length >= 20) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            sender = msg.sender;
        }
    }
}
