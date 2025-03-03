// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./NFTSale.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title WhitelistNFTSale
 * @dev Extension of NFTSale with whitelist functionality using Merkle Tree.
 */
contract WhitelistNFTSale is NFTSale {
    /// @notice Merkle root for the whitelist
    mapping(uint256 => bytes32) public merkleRoot;

    /// @notice Reverts when the user is not in the whitelist
    error NotInWhitelist();

    /// @notice Reverts when Merkle root not specified
    error NoMerkleRoot();

    /// @notice Event emitted when the Merkle root is updated
    event MerkleRootUpdated(uint256 saleId, bytes32 newMerkleRoot);

    /**
     * @dev Initializes the base NFTShop contract.
     * @param _kycAmlVerification Address of the KYCAMLVerification contract
     * @param _uniswapHelper Address of the Uniswap Helper contract
     * @param _crossmintAddress Crossmint address
     * @param _paymentTokens Initial list of payment tokens
     */
    function initialize(
        address _kycAmlVerification,
        address _uniswapHelper,
        address _crossmintAddress,
        address[] memory _paymentTokens
    ) public initializer {
        __NFTSale_init(
            _kycAmlVerification,
            _uniswapHelper,
            _crossmintAddress,
            _paymentTokens
        );
    }

    /**
     * @notice Sets the Merkle root for the whitelist.
     * @param _saleId The new Merkle root
     * @param _merkleRoot The new Merkle root
     */
    function setMerkleRoot(uint256 _saleId, bytes32 _merkleRoot) external onlyOwner {
        merkleRoot[_saleId] = _merkleRoot;
        emit MerkleRootUpdated(_saleId, _merkleRoot);
    }

    /**
     * @notice Allows a user to purchase NFTs from a sale
     * @param _saleId ID of the sale to purchase from
     * @param _quantity Quantity of NFTs to purchase
     * @param _paymentToken Address of the token used for payment
     * @param _expectedTokenAmount Expected token amount by the user
     * @param _slippageTolerance Slippage tolerance in basis points (e.g., 300 for 3%)
     * @param _merkleProof Proof that user is in whitelist
     */
    function buyNFT(
        uint256 _saleId,
        uint256 _quantity,
        address _paymentToken,
        uint256 _expectedTokenAmount,
        uint256 _slippageTolerance,
        bytes32[] calldata _merkleProof
    ) public payable {
        if (merkleRoot[_saleId] == bytes32(0)) {
            revert NoMerkleRoot();
        }

        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        if (!MerkleProof.verify(_merkleProof, merkleRoot[_saleId], leaf)) {
            revert NotInWhitelist();
        }

        super.buyNFT(
            _saleId,
            _quantity,
            _paymentToken,
            _expectedTokenAmount,
            _slippageTolerance
        );
    }

    /**
     * @notice Allows a user to purchase NFTs from a sale
     * @param _saleId ID of the sale to purchase from
     * @param _receiver Address of NFT receiver
     * @param _quantity Quantity of NFTs to purchase
     * @param _merkleProof Proof that user is in whitelist
     */
    function buyNFTFromCrossmint(
        uint256 _saleId,
        address _receiver,
        uint256 _quantity,
        bytes32[] calldata _merkleProof
    ) public {
        if (merkleRoot[_saleId] == bytes32(0)) {
            revert NoMerkleRoot();
        }

        bytes32 leaf = keccak256(abi.encodePacked(_receiver));
        if (!MerkleProof.verify(_merkleProof, merkleRoot[_saleId], leaf)) {
            revert NotInWhitelist();
        }

        super.buyNFTFromCrossmint(
            _saleId,
            _receiver,
            _quantity
        );
    }
}
