// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IUniswapHelper
 * @dev Interface for the UniswapHelper contract.
 */
interface IUniswapHelper {
    /// @notice Error when a provided address is invalid
    error InvalidAddress();

    /// @notice Error when slippage exceeds price impact
    error SlippageExceeds();

    /// @notice Error when pool wasn’t found for token
    error NoPoolAvailable();

    /// @notice Error when price deviation is too high
    error PriceDeviationTooHigh();

    /**
     * @dev Determines the appropriate fee tier for a token pair.
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @return feeTier The best available fee tier for the token pair
     */
    function getFeeTier(address _tokenIn, address _tokenOut) external view returns (uint24 feeTier);

    /**
     * @dev Gets the token amount required for a specific USD amount, considering slippage.
     * @param _USDAmount The desired amount in USD
     * @param _paymentToken Address of the payment token
     * @param _expectedTokenAmount Expected token amount
     * @param _slippageTolerance Slippage tolerance in basis points (e.g., 300 for 3%)
     * @return tokenAmount Final token amount calculated
     */
    function getTokenAmount(
        uint256 _USDAmount,
        address _paymentToken,
        uint256 _expectedTokenAmount,
        uint256 _slippageTolerance
    ) external returns (uint256 tokenAmount);

    /**
     * @dev Returns the address of the USDC token.
     * @return Address of the USDC token
     */
    function getUSDCAddress() external view returns (address);
}