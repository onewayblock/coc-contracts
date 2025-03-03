// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IUniswapHelper} from "./interfaces/IUniswapHelper.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

contract UniswapHelper is Initializable, IUniswapHelper {
    /// @notice USDC token address
    address public usdcAddress;

    /// @notice WETH token address
    address public wethAddress;

    /// @notice Uniswap available fee tiers
    uint24[] private AVAILABLE_FEE_TIERS;

    /// @notice Quoter contract for Uniswap price calculations
    IQuoterV2 public uniswapQuoter;

    /// @notice Uniswap contract for Uniswap fee calculations
    IUniswapV3Factory public uniswapFactory;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Constructor initializes the contract with the necessary parameters.
     * @param _usdcAddress Address of the USDC token
     * @param _wethAddress Address of the WETH token
     * @param _uniswapQuoter Address of the Uniswap QuoterV2 contract
     * @param _uniswapFactory Address of the Uniswap Factory contract
     */
    function initialize(
        address _usdcAddress,
        address _wethAddress,
        address _uniswapQuoter,
        address _uniswapFactory
    ) public initializer {
        if (
            _usdcAddress == address(0) ||
            _wethAddress == address(0) ||
            _uniswapQuoter == address(0) ||
            _uniswapFactory == address(0)
        ) {
            revert InvalidAddress();
        }

        usdcAddress = _usdcAddress;
        wethAddress = _wethAddress;
        uniswapQuoter = IQuoterV2(_uniswapQuoter);
        uniswapFactory = IUniswapV3Factory(_uniswapFactory);

        AVAILABLE_FEE_TIERS = [500, 3000, 10000];
    }

    /*
     * @inheritdoc IReferralShare
     */
    function getTokenAmount(
        uint256 _USDAmount,
        address _paymentToken,
        uint256 _expectedTokenAmount,
        uint256 _slippageTolerance
    ) external override returns (uint256) {
        uint256 maxTokenAmount = _expectedTokenAmount +
            ((_expectedTokenAmount * _slippageTolerance) / 10_000); // +slippage%
        uint256 minTokenAmount = _expectedTokenAmount -
            ((_expectedTokenAmount * _slippageTolerance) / 10_000); // -slippage%

        address tokenIn = _paymentToken == address(0)
            ? wethAddress
            : _paymentToken;

        uint256 tokenAmount = getTokenAmountForOutput(
            tokenIn,
            usdcAddress,
            _USDAmount
        );

        if (tokenAmount < minTokenAmount || tokenAmount > maxTokenAmount) {
            revert SlippageExceeds();
        }

        return tokenAmount;
    }

    /**
     * @notice Determines the optimal fee tier for a given token pair.
     * @param _tokenIn The address of the input token.
     * @param _tokenOut The address of the output token.
     * @return feeTier The fee tier associated with the available Uniswap pool.
     * @dev Iterates through the predefined fee tiers and returns the first available pool.
     *      Reverts if no pool is available.
     */
    function getFeeTier(
        address _tokenIn,
        address _tokenOut
    ) public view returns (uint24 feeTier) {
        uint256 length = AVAILABLE_FEE_TIERS.length;

        for (uint256 i = 0; i < length; i++) {
            address pool = uniswapFactory.getPool(
                _tokenIn,
                _tokenOut,
                AVAILABLE_FEE_TIERS[i]
            );
            if (pool != address(0)) {
                return AVAILABLE_FEE_TIERS[i];
            }
        }
        revert NoPoolAvailable();
    }

    /**
     * @notice Calculates the required amount of input tokens to receive a specific output amount.
     * @param _tokenIn The address of the input token.
     * @param _tokenOut The address of the output token.
     * @param _amountOut The desired output amount.
     * @return The required amount of input tokens.
     * @dev Fetches the optimal fee tier using getFeeTier() and queries the Uniswap Quoter contract.
     */
    function getTokenAmountForOutput(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountOut
    ) public returns (uint256) {
        uint24 feeTier = getFeeTier(_tokenIn, _tokenOut);

        IQuoterV2.QuoteExactOutputSingleParams memory params = IQuoterV2
            .QuoteExactOutputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: feeTier,
            amount: _amountOut,
            sqrtPriceLimitX96: 0
        });

        (uint256 tokenInAmount, , , ) = uniswapQuoter.quoteExactOutputSingle(
            params
        );

        return tokenInAmount;
    }

    /**
     * @notice Calculates the expected output amount for a given input amount.
     * @param _tokenIn The address of the input token.
     * @param _tokenOut The address of the output token.
     * @param _amountIn The amount of input tokens.
     * @return The expected amount of output tokens.
     * @dev Fetches the optimal fee tier using getFeeTier() and queries the Uniswap Quoter contract.
     */
    function getOutputForTokenAmount(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) public returns (uint256) {
        uint24 feeTier = getFeeTier(_tokenIn, _tokenOut);

        IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2
            .QuoteExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: feeTier,
            amountIn: _amountIn,
            sqrtPriceLimitX96: 0
        });

        (uint256 amountOut, , , ) = uniswapQuoter.quoteExactInputSingle(params);

        return amountOut;
    }

    /*
     * @inheritdoc IReferralShare
     */
    function getUSDCAddress() external view override returns (address) {
        return usdcAddress;
    }

    /**
     * @notice Checks that the price for the USDC/token pair, obtained via the Uniswap V3 TWAP oracle,
     *         is within an acceptable deviation from an expected token amount.
     * @param _token The address of the token (paired with USDC).
     * @param _USDAmount The amount of USDC used as input.
     * @param _expectedTokenAmount The expected output amount of the token.
     * @param _oracleLookbackPeriod Time period (in seconds) to calculate the TWAP.
     * @dev Reverts with PriceDeviationTooHigh if the deviation is greater than _maxDeviationPercent.
     */
    function checkPrice(
        address _token,
        uint256 _USDAmount,
        uint256 _expectedTokenAmount,
        uint256 _slippage,
        uint32 _oracleLookbackPeriod
    ) external view {
        (address tokenA, address tokenB) = usdcAddress < _token
            ? (usdcAddress, _token)
            : (_token, usdcAddress);

        uint24 feeTier = getFeeTier(tokenA, tokenB);

        address pool = uniswapFactory.getPool(tokenA, tokenB, feeTier);

        if(pool == address(0)) {
            revert NoPoolAvailable();
        }

        (int24 timeWeightedAverageTick, ) = OracleLibrary.consult(pool, _oracleLookbackPeriod);

        uint256 referenceTokenAmount = OracleLibrary.getQuoteAtTick(
            timeWeightedAverageTick,
            uint128(_USDAmount),
            usdcAddress,
            _token
        );

        uint256 deviationThreshold = (referenceTokenAmount * _slippage) / 10000;

        if (
            _expectedTokenAmount < referenceTokenAmount - deviationThreshold ||
            _expectedTokenAmount > referenceTokenAmount + deviationThreshold
        ) {
            revert PriceDeviationTooHigh();
        }
    }
}