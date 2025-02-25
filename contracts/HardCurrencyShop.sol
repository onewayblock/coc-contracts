// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {UniswapHelper} from "./UniswapHelper.sol";
import {IHardCurrencyShop} from "./interfaces/IHardCurrencyShop.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVerification} from "./interfaces/IVerification.sol";

/**
 * @title HardCurrencyShop
 * @dev Contract for hard currency sale with referral sharing.
 * @dev Implementation of the IHardCurrencyShop interface
 */
contract HardCurrencyShop is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    IHardCurrencyShop
{
    using SafeERC20 for IERC20;

    /// @notice Supported payment tokens
    address[] private supportedTokens;

    /// @notice Address of the Verification contract
    address public verification;

    /// @notice Address of the Uniswap Helper
    address public uniswapHelper;

    /// @notice Trusted forwarder address for meta-transactions
    address public trustedForwarder;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the necessary parameters.
     * @param _verification Address of the Verification contract
     * @param _uniswapHelper Address of the Uniswap Helper contract
     * @param _paymentTokens Initial list of payment tokens
     */
    function initialize(
        address _verification,
        address _uniswapHelper,
        address[] memory _paymentTokens
    ) public initializer {
        if (
            _verification == address(0) ||
            _uniswapHelper == address(0)
        ) {
            revert InvalidAddress();
        }

        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        verification = _verification;
        uniswapHelper = _uniswapHelper;

        uint256 length = _paymentTokens.length;
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = 0; j < i; j++) {
                if(_paymentTokens[i] == _paymentTokens[j]) {
                    revert DuplicateAddress();
                }
            }

            supportedTokens.push(_paymentTokens[i]);
        }
    }

    /**
     * @inheritdoc IHardCurrencyShop
     */
    function purchase(
        uint256 _USDAmount,
        address _paymentToken,
        uint256 _expectedTokenAmount,
        uint256 _slippageTolerance
    ) external payable override nonReentrant {
        address sender = _msgSender();

        if (!_isTokenSupported(_paymentToken)) {
            revert TokenNotSupported();
        }
        if(_slippageTolerance == 0 || _slippageTolerance > 3000) {
            revert InvalidSlippage();
        }
        if(_expectedTokenAmount == 0) {
            revert InvalidExpectedAmount();
        }

        if (_paymentToken != address(0) && msg.value > 0) {
            revert ETHNotAllowedWithTokenPayment();
        }

        IVerification(verification).validateSpending(sender, _USDAmount);

        uint256 totalTokenAmount = _USDAmount;

        if (_paymentToken != UniswapHelper(uniswapHelper).getUSDCAddress()) {
            uint256 referenceTokenAmount = UniswapHelper(uniswapHelper)
                .getTokenAmountForOutput(
                    _paymentToken,
                    UniswapHelper(uniswapHelper).getUSDCAddress(),
                    _USDAmount
                );

            if(_expectedTokenAmount < referenceTokenAmount - ((referenceTokenAmount * 30) / 100)) {
                revert expectedTokenAmountExceedsDeviation();
            }
            if(_expectedTokenAmount > referenceTokenAmount + ((referenceTokenAmount * 30) / 100)) {
                revert expectedTokenAmountExceedsDeviation();
            }

            totalTokenAmount = UniswapHelper(uniswapHelper).getTokenAmount(
                _USDAmount,
                _paymentToken,
                _expectedTokenAmount,
                _slippageTolerance
            );
        }

        _handlePayment(
            _paymentToken,
            totalTokenAmount,
            sender
        );

        IVerification(verification).recordSpending(sender, _USDAmount);

        (
            address firstTreasure,
            address secondTreasure,
            uint256 firstTreasurePercentage,
        ) = IVerification(verification).getTreasureConfiguration();

        uint256 firstAmount = totalTokenAmount * firstTreasurePercentage / 10000;
        uint256 secondAmount = totalTokenAmount - firstAmount;

        if (_paymentToken == address(0)) {
            (bool success1, ) = payable(firstTreasure).call{value: firstAmount}("");
            (bool success2, ) = payable(secondTreasure).call{value: secondAmount}("");

            if(!success1 || !success2) {
                revert ETHSendFailed();
            }
        } else {
            IERC20(_paymentToken).safeTransfer(firstTreasure, firstAmount);
            IERC20(_paymentToken).safeTransfer(secondTreasure, secondAmount);
        }

        emit HardCurrencyBought(
            sender,
            _USDAmount,
            _paymentToken,
            totalTokenAmount
        );
    }

    /**
     * @inheritdoc IHardCurrencyShop
     */
    function getSupportedTokens() external view override returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @inheritdoc IHardCurrencyShop
     */
    function addPaymentToken(address _token) external override onlyOwner {
        if (_isTokenSupported(_token)) {
            revert TokenAlreadySupported();
        }

        supportedTokens.push(_token);
        emit PaymentTokenAdded(_token);
    }

    /**
     * @inheritdoc IHardCurrencyShop
     */
    function removePaymentToken(address _token) external override onlyOwner {
        if (!_removePaymentToken(_token)) {
            revert TokenNotSupported();
        }

        emit PaymentTokenRemoved(_token);
    }

    /**
     * @inheritdoc IHardCurrencyShop
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

    /*
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
                if (_isContract(_sender)) {
                    if(address(_sender).code.length == 0) {
                        revert ContractCannotReceiveETH();
                    }
                }

                (bool success, ) = payable(_sender).call{value: msg.value - _tokenAmount}("");

                if(!success) {
                    revert ETHSendFailed();
                }
            }
        } else {
            IERC20(_paymentToken).safeTransferFrom(_sender, address(this), _tokenAmount);
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
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
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

    /**
     * @dev Checks if an address is a contract
     * @param _addr Address to check
     * @return bool True if the address is a contract, false otherwise
     */
    function _isContract(address _addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}