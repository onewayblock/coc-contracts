// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IReferralShare} from "./interfaces/IReferralShare.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVerification} from "./interfaces/IVerification.sol";

/**
 * @title ReferralShare
 * @dev Contract to manage token and ether balances for referral codes with backend signature verification.
 * @dev Implementation of the IReferralShare interface
 */
contract ReferralShare is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    IReferralShare
{
    using SafeERC20 for IERC20;

    /// @notice Mapping of referral codes to token/ether addresses and their balances
    mapping(string => mapping(address => uint256)) private referralBalances;

    /// @notice Address of the Verification contract
    address public verification;

    /// @notice List of supported token addresses
    address[] private supportedTokens;

    /// @notice Mapping of whitelisted addresses that can call recordDeposit
    mapping(address => bool) private whitelistedContracts;

    /// @notice Trusted forwarder address for meta-transactions
    address public trustedForwarder;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with a backend signer and supported tokens
     * @param _verification Address of the Verification contract
     * @param _supportedTokens Array of token addresses supported by the contract
     * @param _whitelistedContracts Array of initial whitelisted contract addresses
     * @param _owner Owner of the contract
     */
    function initialize(
        address _verification,
        address[] memory _supportedTokens,
        address[] memory _whitelistedContracts,
        address _owner
    ) public initializer {
        if (_verification == address(0)) {
            revert InvalidAddress();
        }

        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        verification = _verification;

        uint256 tokensLength = _supportedTokens.length;

        for (uint256 i = 0; i < tokensLength; i++) {
            for (uint256 j = 0; j < i; j++) {
                if(_supportedTokens[i] == _supportedTokens[j]) {
                    revert DuplicateAddress();
                }
            }

            supportedTokens.push(_supportedTokens[i]);
        }

        uint256 contractsLength = _whitelistedContracts.length;

        for (uint256 i = 0; i < contractsLength; i++) {
            if(_whitelistedContracts[i] == address(0)) {
                revert InvalidAddress();
            }
            for (uint256 j = 0; j < i; j++) {
                if(_whitelistedContracts[i] == _whitelistedContracts[j]) {
                    revert DuplicateAddress();
                }
            }

            whitelistedContracts[_whitelistedContracts[i]] = true;
        }
    }

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
    ) external payable nonReentrant {
        if (!whitelistedContracts[msg.sender]) {
            revert NotWhitelisted();
        }

        if (!_isSupportedToken(_token)) {
            revert UnsupportedToken();
        }

        if (_token != address(0) && msg.value > 0) {
            revert ETHNotAllowedWithTokenPayment();
        }

        if (_token == address(0)) {
            if (msg.value != _amount) {
                revert InvalidETHAmount();
            }
        } else {
            if (msg.value > 0) {
                revert ETHNotAllowedWithTokenPayment();
            }
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }

        referralBalances[_referralCode][_token] += _amount;

        emit DepositRecorded(_referralCode, _token, _amount);
    }

    /**
     * @inheritdoc IReferralShare
     */
    function withdrawBalances(
        string memory _referralCode,
        uint256 _timestamp,
        bytes memory _signature
    ) external override nonReentrant {
        address sender = _msgSender();

        IVerification(verification).verifySignaturePublic(
            keccak256(abi.encode(address(this), 'withdrawBalances', sender, _referralCode, _timestamp, block.chainid)),
            _signature
        );

        uint256 length = supportedTokens.length;

        for (uint256 i = 0; i < length; i++) {
            address token = supportedTokens[i];
            uint256 balance = referralBalances[_referralCode][token];

            if (balance > 0) {
                referralBalances[_referralCode][token] = 0;

                if (token == address(0)) {
                    // Ether withdrawal
                    (bool success, ) = payable(sender).call{value: balance}("");

                    if(!success) {
                        revert ETHSendFailed();
                    }
                } else {
                    // Token withdrawal
                    IERC20(token).safeTransfer(sender, balance);
                }

                emit WithdrawalRecorded(_referralCode, token, balance);
            }
        }
    }

    /**
     * @inheritdoc IReferralShare
     */
    function addSupportedToken(address _token) external override onlyOwner {
        if (_isSupportedToken(_token)) {
            revert AlreadySupportedToken();
        }

        supportedTokens.push(_token);
        emit TokenAdded(_token);
    }

    /**
     * @inheritdoc IReferralShare
     */
    function removeSupportedToken(address _token) external override onlyOwner {
        uint256 length = supportedTokens.length;

        for (uint256 i = 0; i < length; i++) {
            if (supportedTokens[i] == _token) {
                supportedTokens[i] = supportedTokens[
                    supportedTokens.length - 1
                ];
                supportedTokens.pop();
                emit TokenRemoved(_token);
                break;
            }
        }
    }

    /**
     * @inheritdoc IReferralShare
     */
    function addWhitelistedContract(
        address _contractAddress
    ) external override onlyOwner {
        if (whitelistedContracts[_contractAddress]) {
            revert AlreadyWhitelisted();
        }

        whitelistedContracts[_contractAddress] = true;
        emit ContractWhitelisted(_contractAddress);
    }

    /**
     * @inheritdoc IReferralShare
     */
    function removeWhitelistedContract(
        address _contractAddress
    ) external override onlyOwner {
        if (!whitelistedContracts[_contractAddress]) {
            revert NotWhitelisted();
        }

        delete whitelistedContracts[_contractAddress];
        emit ContractRemovedFromWhitelist(_contractAddress);
    }

    /**
     * @inheritdoc IReferralShare
     */
    function getReferralBalance(
        string memory _referralCode,
        address _token
    ) external view override returns (uint256) {
        return referralBalances[_referralCode][_token];
    }

    /**
     * @inheritdoc IReferralShare
     */
    function getSupportedTokens() public view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @inheritdoc IReferralShare
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
     * @dev Checks if a token is supported by the contract
     * @param _token Address of the token to check
     * @return bool True if the token is supported, false otherwise
     */
    function _isSupportedToken(address _token) private view returns (bool) {
        uint256 length = supportedTokens.length;

        for (uint256 i = 0; i < length; i++) {
            if (supportedTokens[i] == _token) {
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
     * @dev Fallback function to handle calls with data that do not match any function signature.
     * This function is executed if no other function matches the call or if ETH is sent with data.
     */
    fallback() external payable {}

    /**
     * @dev Receive function to handle calls with data that do not match any function signature.
     * This function is executed if no other function matches the call or if ETH is sent with data.
     */
    receive() external payable {}
}
