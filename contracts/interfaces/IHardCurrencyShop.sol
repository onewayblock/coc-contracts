// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IHardCurrencyShop
 * @dev Interface for the HardCurrencyShop contract.
 */
interface IHardCurrencyShop {
    /// @dev Error when a token is already supported
    error TokenAlreadySupported();

    /// @dev Error when a token is not supported
    error TokenNotSupported();

    /// @dev Error when a provided address is invalid
    error InvalidAddress();

    /// @dev Error when insufflient ETH sent
    error InsufflientETHSent();

    /// @dev Error when user setted invalid slippage tolerance
    error InvalidSlippage();

    /// @dev Error when  provided invalid expected amount of tokens
    error InvalidExpectedAmount();

    /// @dev Error when we are sending ethereum to address
    error ETHSendFailed();

    /// @dev Error when user send ETH while payment token is different
    error ETHNotAllowedWithTokenPayment();

    /// @dev Error when we want to send ETH to empty contract
    error ContractCannotReceiveETH();

    /// @dev Error when provided duplicated address
    error DuplicateAddress();

    /// @dev Error when expected token amount exceeds deviation
    error expectedTokenAmountExceedsDeviation();

    /// @dev Error when expected USD amount is 0.
    error InvalidUSDAmount();

    /// @dev Event emitted when a token is added to the payment list
    event PaymentTokenAdded(address token);

    /// @dev Event emitted when a token is removed from the payment list
    event PaymentTokenRemoved(address token);

    /// @dev Event emitted when the Verification address is updated
    event VerificationAddressUpdated(address newKYCAMLVerification);

    /// @dev Event emitted when user bought hard currency
    event HardCurrencyBought(
        address buyer,
        uint256 USDAmount,
        address paymentToken,
        uint256 paymentTokenAmount
    );

    /**
     * @dev Purchase method for buying hard currency with slippage and user expectations.
     * @param _USDAmount Amount to spend in USDC
     * @param _paymentToken Address of the token to use for payment
     * @param _expectedTokenAmount Expected token amount by the user
     * @param _slippageTolerance Slippage tolerance in basis points (e.g., 300 for 3%)
     */
    function purchase(
        uint256 _USDAmount,
        address _paymentToken,
        uint256 _expectedTokenAmount,
        uint256 _slippageTolerance
    ) external payable;

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
     * @dev Returns the list of supported payment tokens.
     * @return Array of supported token addresses.
     */
    function getSupportedTokens() external view returns (address[] memory);
}
