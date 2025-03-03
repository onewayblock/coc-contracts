// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IClaim} from "./interfaces/IClaim.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Claim Contract
 * @dev This contract allows users to claim tokens based on a Merkle proof and optionally stake them.
 */
contract Claim is Ownable, ReentrancyGuard, IClaim {
    using SafeERC20 for IERC20;

    /// @notice Merkle root for the whitelist
    bytes32 public merkleRoot;

    /// @notice Address of the staking contract
    address public staking;

    /// @notice Address of the token contract
    address public token;

    /// @notice Tracks whether a user has claimed their tokens
    mapping(address => uint256) public tokensClaimed;

    /// @notice The time when the withdraw function will be unlocked
    uint256 public unlockTime;

    /**
     * @dev Constructor to initialize the contract.
     * @param _owner The address of the contract owner
     * @param _staking The address of the staking contract
     * @param _token The address of the token contract
     * @param _merkleRoot The initial Merkle root
     * @param _unlockTime The time when the withdraw function will be unlocked
     */
    constructor(
        address _owner,
        address _staking,
        address _token,
        bytes32 _merkleRoot,
        uint256 _unlockTime
    ) Ownable(_owner) {
        if (_staking == address(0) || _token == address(0)) {
            revert InvalidAddress();
        }

        if (_unlockTime < block.timestamp) {
            revert InvalidUnlockTime();
        }

        merkleRoot = _merkleRoot;
        staking = _staking;
        token = _token;
        unlockTime = _unlockTime;
    }

    /**
     * @inheritdoc IClaim
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /**
     * @inheritdoc IClaim
     */
    function setTokenAddress(address _token) external onlyOwner {
        if (_token == address(0)) {
            revert InvalidAddress();
        }

        token = _token;
        emit TokenAddressUpdated(_token);
    }

    /**
     * @inheritdoc IClaim
     */
    function setStakingAddress(address _staking) external onlyOwner {
        if (_staking == address(0)) {
            revert InvalidAddress();
        }

        staking = _staking;
        emit StakingAddressUpdated(_staking);
    }

    /**
     * @inheritdoc IClaim
     */
    function claimTokens(
        address receiver,
        uint256 tokens,
        bytes32[] calldata proof
    ) public nonReentrant {
        if (msg.sender != staking) {
            if (receiver != msg.sender) {
                revert InvalidReceiver();
            }
        }

        if (tokensClaimed[receiver] > 0) {
            revert TokensAlreadyClaimed();
        }

        if (tokens == 0) {
            revert InvalidTokens();
        }

        if (IERC20(token).balanceOf(address(this)) < tokens) {
            revert InsufficientBalance();
        }

        if (!isParticipating(receiver, tokens, proof)) {
            revert InvalidProof();
        }

        tokensClaimed[receiver] = tokens;

        IERC20(token).safeTransfer(receiver, tokens);

        emit TokensClaimed(receiver, tokens);
    }

    /**
     * @inheritdoc IClaim
     */
    function withdrawTokens(uint256 amount) external onlyOwner nonReentrant {
        if (block.timestamp < unlockTime) {
            revert WithdrawLocked();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        if (IERC20(token).balanceOf(address(this)) < amount) {
            revert InsufficientContractBalance();
        }

        IERC20(token).safeTransfer(owner(), amount);
        emit TokensWithdrawn(owner(), amount);
    }

    /**
     * @inheritdoc IClaim
     */
    function isParticipating(
        address user,
        uint256 tokens,
        bytes32[] calldata proof
    ) public view returns (bool) {
        if (tokensClaimed[user] > 0 || tokens == 0) {
            return false;
        }

        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(user, tokens)))
        );
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }
}
