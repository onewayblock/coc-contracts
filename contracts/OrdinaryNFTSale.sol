// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./NFTSale.sol";

/**
 * @title OrdinaryNFTSale
 * @dev Standard version of NFTSale.
 */
contract OrdinaryNFTSale is NFTSale {
    /**
     * @dev Initializes the base NFTShop contract.
     * @param _kycAmlVerification Address of the KYCAMLVerification contract
     * @param _uniswapHelper Address of the Uniswap Helper contract
     * @param _crossmintAddress Crossmint address
     * @param _paymentTokens Initial list of payment tokens
     * @param _owner Address of the contract owner
     */
    function initialize(
        address _kycAmlVerification,
        address _uniswapHelper,
        address _crossmintAddress,
        address[] memory _paymentTokens,
        address _owner
    ) public initializer {
        __NFTSale_init(
            _kycAmlVerification,
            _uniswapHelper,
            _crossmintAddress,
            _paymentTokens,
            _owner
        );
    }

    /**
     * @notice Allows a user to purchase NFTs from a sale
     * @param _saleId ID of the sale to purchase from
     * @param _quantity Quantity of NFTs to purchase
     * @param _paymentToken Address of the token used for payment
     * @param _expectedTokenAmount Expected token amount by the user
     * @param _slippageTolerance Slippage tolerance in basis points (e.g., 300 for 3%)
     */
    function buyNFT(
        uint256 _saleId,
        uint256 _quantity,
        address _paymentToken,
        uint256 _expectedTokenAmount,
        uint256 _slippageTolerance
    ) public payable nonReentrant {
        super._buyNFT(
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
     */
    function buyNFTFromCrossmint(
        uint256 _saleId,
        address _receiver,
        uint256 _quantity
    ) public nonReentrant {
        super._buyNFTFromCrossmint(_saleId, _receiver, _quantity);
    }
}
