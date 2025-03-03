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
}
