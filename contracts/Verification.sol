// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IVerification} from "./interfaces/IVerification.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol"; // Library for working with ECDSA signatures
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol"; // Utility for Ethereum-signed message hashes

/**
 * @title Verification
 * @dev Contract for managing user KYC and AML verifications with signature verification.
 *      Includes functionality for secure backend signature validation.
 * @dev Implementation of the IVerification interface
 */
contract Verification is
    OwnableUpgradeable,
    IVerification
{
    using ECDSA for bytes32;

    /// @notice Address of the backend signer responsible for generating valid signatures
    address public backendSigner;

    /// @notice Address of first treasure
    address public treasureFirstAddress;

    /// @notice Address of second treasure
    address public treasureSecondAddress;

    /// @notice Percentage of first treasure
    uint256 public treasureFirstPercentage;

    /// @notice Percentage of second treasure
    uint256 public treasureSecondPercentage;

    /// @notice Spending limits for AML/KYC checks. The USDC token has 6 decimals
    uint256 public baseAmlLimit;
    uint256 public advancedAmlLimit;
    uint256 public baseKycLimit;
    uint256 public advancedKycLimit;

    /// @notice AML score limits
    uint256 public baseAmlScoreLimit;
    uint256 public advancedAmlScoreLimit;

    /// @notice Stores used message hashes with signatures
    mapping(bytes32 => bool) private usedHashes;

    /// @notice Stores the verification data for each user
    mapping(address => UserVerification) private userVerifications;

    /// @notice Mapping of user addresses to their total spending in USD
    mapping(address => uint256) private userTotalSpending;

    /// @notice Mapping of user addresses to their spending history
    mapping(address => SpendingRecord[]) private userSpendingHistory;

    /// @notice Contracts allowed to call restricted methods
    mapping(address => bool) private allowedContracts;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer of the contract with a backend signer address and owner address.
     * @param _backendSigner The address of the backend signer
     * @param _allowedContracts Array of contract addresses allowed to call restricted methods
     * @param _owner The address of the contract owner
     */
    function initialize(
        address _backendSigner,
        address[] memory _allowedContracts,
        address _owner
    ) public initializer {
        if (_backendSigner == address(0)) {
            revert InvalidAddress();
        }

        __Ownable_init(_owner);

        backendSigner = _backendSigner;

        baseAmlLimit = 5 * 10 ** 6;
        advancedAmlLimit = 50 * 10 ** 6;
        baseKycLimit = 100 * 10 ** 6;
        advancedKycLimit = 200 * 10 ** 6;
        baseAmlScoreLimit = 50;
        advancedAmlScoreLimit = 50;

        uint256 length = _allowedContracts.length;

        for (uint256 i = 0; i < length; i++) {
            if (_allowedContracts[i] == address(0)) {
                revert InvalidAddress();
            }
            allowedContracts[_allowedContracts[i]] = true;
        }
    }

    /**
     * @inheritdoc IVerification
     */
    function setBaseKyc(
        address _user,
        bool _baseKyc,
        bytes memory _signature
    ) external override {
        if (
            !_verifySignature(
                keccak256(
                    abi.encode(
                        address(this),
                        "setBaseKyc",
                        _user,
                        _baseKyc,
                        block.chainid
                    )
                ),
                _signature
            )
        ) {
            revert InvalidSigner();
        }

        userVerifications[_user].baseKyc = _baseKyc;
        emit BaseKycUpdated(_user, _baseKyc);
    }

    /**
     * @inheritdoc IVerification
     */
    function setAdvancedKyc(
        address _user,
        bool _advancedKyc,
        bytes memory _signature
    ) external override {
        if (
            !_verifySignature(
                keccak256(
                    abi.encode(
                        address(this),
                        "setAdvancedKyc",
                        _user,
                        _advancedKyc,
                        block.chainid
                    )
                ),
                _signature
            )
        ) {
            revert InvalidSigner();
        }

        userVerifications[_user].advancedKyc = _advancedKyc;
        emit AdvancedKycUpdated(_user, _advancedKyc);
    }

    /**
     * @inheritdoc IVerification
     */
    function setBaseAMLScore(
        address _user,
        uint256 _baseAMLScore,
        bytes memory _signature
    ) external override {
        if (
            !_verifySignature(
                keccak256(
                    abi.encode(
                        address(this),
                        "setBaseAMLScore",
                        _user,
                        _baseAMLScore,
                        block.chainid
                    )
                ),
                _signature
            )
        ) {
            revert InvalidSigner();
        }

        userVerifications[_user].baseAMLScore = _baseAMLScore;
        emit BaseAMLScoreUpdated(_user, _baseAMLScore);
    }

    /**
     * @inheritdoc IVerification
     */
    function setAdvancedAMLScore(
        address _user,
        uint256 _advancedAMLScore,
        bytes memory _signature
    ) external override {
        if (
            !_verifySignature(
                keccak256(
                    abi.encode(
                        address(this),
                        "setAdvancedAMLScore",
                        _user,
                        _advancedAMLScore,
                        block.chainid
                    )
                ),
                _signature
            )
        ) {
            revert InvalidSigner();
        }

        userVerifications[_user].advancedAMLScore = _advancedAMLScore;
        emit AdvancedAMLScoreUpdated(_user, _advancedAMLScore);
    }

    /**
     * @inheritdoc IVerification
     */
    function getVerification(
        address _user
    ) external view override returns (UserVerification memory) {
        return userVerifications[_user];
    }

    /**
     * @inheritdoc IVerification
     */
    function recordSpending(
        address _user,
        uint256 _amount
    ) external override {
        if (!allowedContracts[msg.sender]) {
            revert NotAllowedContract();
        }

        userTotalSpending[_user] += _amount;
        userSpendingHistory[_user].push(
            SpendingRecord(_amount, block.timestamp, msg.sender)
        );

        emit SpendingRecorded(_user, _amount, msg.sender);
    }

    /**
     * @inheritdoc IVerification
     */
    function getTotalSpending(
        address _user
    ) external view override returns (uint256) {
        return userTotalSpending[_user];
    }

    /**
     * @inheritdoc IVerification
     */
    function getSpendingHistory(
        address _user
    ) external view override returns (SpendingRecord[] memory) {
        return userSpendingHistory[_user];
    }

    /**
     * @inheritdoc IVerification
     */
    function addAllowedContract(
        address _contractAddress
    ) external override onlyOwner {
        if(_contractAddress == address(0)) {
            revert InvalidAddress();
        }

        allowedContracts[_contractAddress] = true;
    }

    /**
     * @inheritdoc IVerification
     */
    function removeAllowedContract(
        address _contractAddress
    ) external override onlyOwner {
        delete allowedContracts[_contractAddress];
    }

    /**
     * @inheritdoc IVerification
     */
    function setBackendSigner(address _newSigner) external override onlyOwner {
        if (_newSigner == address(0)) {
            revert InvalidAddress();
        }

        backendSigner = _newSigner;
        emit BackendSignerChanged(_newSigner);
    }

    /**
     * @inheritdoc IVerification
     */
    function validateSpending(
        address _user,
        uint256 _amount
    ) external view override {
        uint256 dailyAmount = _amount + calculate24HourSpending(_user);
        UserVerification memory verification = userVerifications[_user];

        if (dailyAmount >= advancedKycLimit) {
            if (
                !verification.advancedKyc ||
                verification.advancedAMLScore >= advancedAmlScoreLimit ||
                verification.advancedAMLScore == 0
            ) {
                revert AMLKYCCheckFailed();
            }
        } else if (dailyAmount >= baseKycLimit) {
            if (!verification.baseKyc && !verification.advancedKyc) {
                revert AMLKYCCheckFailed();
            }
            if (
                verification.advancedAMLScore >= advancedAmlScoreLimit ||
                verification.advancedAMLScore == 0
            ) {
                revert AMLKYCCheckFailed();
            }
        } else if (dailyAmount >= advancedAmlLimit) {
            if (
                verification.advancedAMLScore >= advancedAmlScoreLimit ||
                verification.advancedAMLScore == 0
            ) {
                revert AMLKYCCheckFailed();
            }
        } else if (dailyAmount >= baseAmlLimit) {
            if (verification.advancedAMLScore > 0) {
                if (verification.advancedAMLScore >= advancedAmlScoreLimit) {
                    revert AMLKYCCheckFailed();
                }
            } else {
                if (
                    verification.baseAMLScore >= baseAmlScoreLimit ||
                    verification.baseAMLScore == 0
                ) {
                    revert AMLKYCCheckFailed();
                }
            }
        }
    }

    /**
     * @inheritdoc IVerification
     */
    function setTreasureConfiguration(
        address _treasureFirstAddress,
        address _treasureSecondAddress,
        uint256 _treasureFirstPercentage,
        uint256 _treasureSecondPercentage
    ) external override onlyOwner {
        if (_treasureFirstAddress == address(0) || _treasureSecondAddress == address(0)) {
            revert InvalidAddress();
        }

        if (_treasureFirstPercentage + _treasureSecondPercentage != 10000) {
            revert InvalidConfiguration();
        }

        treasureFirstAddress = _treasureFirstAddress;
        treasureSecondAddress = _treasureSecondAddress;
        treasureFirstPercentage = _treasureFirstPercentage;
        treasureSecondPercentage = _treasureSecondPercentage;

        emit TreasureConfigurationUpdated(
            _treasureFirstAddress,
            _treasureSecondAddress,
            _treasureFirstPercentage,
            _treasureSecondPercentage
        );
    }

    /**
     * @inheritdoc IVerification
     */
    function getTreasureConfiguration() external view override returns (
        address firstTreasure,
        address secondTreasure,
        uint256 firstTreasurePercentage,
        uint256 secondTreasurePercentage
    )
    {
        return (
            treasureFirstAddress,
            treasureSecondAddress,
            treasureFirstPercentage,
            treasureSecondPercentage
        );
    }

    /**
     * @inheritdoc IVerification
     */
    function updateSpendingLimits(
        uint256 _baseAmlLimit,
        uint256 _advancedAmlLimit,
        uint256 _baseKycLimit,
        uint256 _advancedKycLimit
    ) external override onlyOwner {
        if (
            _baseAmlLimit > _advancedAmlLimit ||
            _advancedAmlLimit > _baseKycLimit ||
            _baseKycLimit > _advancedKycLimit
        ) {
            revert InvalidConfiguration();
        }

        baseAmlLimit = _baseAmlLimit;
        advancedAmlLimit = _advancedAmlLimit;
        baseKycLimit = _baseKycLimit;
        advancedKycLimit = _advancedKycLimit;

        emit SpendingLimitsUpdated(
            _baseAmlLimit,
            _advancedAmlLimit,
            _baseKycLimit,
            _advancedKycLimit
        );
    }

    /**
     * @inheritdoc IVerification
     */
    function updateAMLScoreLimits(
        uint256 _baseAmlScoreLimit,
        uint256 _advancedAmlScoreLimit
    ) external override onlyOwner {
        if (_baseAmlScoreLimit > 100 || _advancedAmlScoreLimit > 100) {
            revert InvalidConfiguration();
        }

        baseAmlScoreLimit = _baseAmlScoreLimit;
        advancedAmlScoreLimit = _advancedAmlScoreLimit;

        emit AMLScoreLimitsUpdated(_baseAmlScoreLimit, _advancedAmlScoreLimit);
    }

    /**
     * @dev Calculates the total spending of a user in the last 24 hours
     * @param _user Address of the user
     * @return Total spending in the last 24 hours in USD
     */
    function calculate24HourSpending(
        address _user
    ) private view returns (uint256) {
        uint256 totalSpending = 0;

        SpendingRecord[] memory records = userSpendingHistory[_user];
        uint256 length = records.length;

        for (uint256 i = length; i > 0; i--) {
            if (block.timestamp - records[i - 1].timestamp > 24 hours) {
                break;
            }
            totalSpending += records[i - 1].amount;
        }

        return totalSpending;
    }

    /**
     * @dev Verifies the validity of a signature against a message hash.
     * @param _messageHash The encoded data being verified
     * @param _signature The signature to verify
     */
    function verifySignaturePublic(
        bytes32 _messageHash,
        bytes memory _signature
    ) external override {
        if (
            !_verifySignature(
            _messageHash,
            _signature
        )
        ) {
            revert InvalidSigner();
        }

    }

    /**
     * @dev Verifies the validity of a signature against a message hash.
     * @param _messageHash The encoded data being verified
     * @param _signature The signature to verify
     * @return bool True if the signature is valid, false otherwise
     */
    function _verifySignature(
        bytes32 _messageHash,
        bytes memory _signature
    ) private returns (bool) {
        if(usedHashes[_messageHash]) {
            revert InvalidMessageHash();
        }

        usedHashes[_messageHash] = true;

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            _messageHash
        );
        return ethSignedMessageHash.recover(_signature) == backendSigner;
    }
}
