// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract DummyUniswapHelper {
    address public USDCAddress;

    constructor(address _USDCAddress) {
        USDCAddress = _USDCAddress;
    }

    function getUSDCAddress() external view returns (address) {
        return USDCAddress;
    }

    function getTokenAmount(
        uint256 amount,
        address, /*_paymentToken*/
        uint256, /*_expectedTokenAmount*/
        uint256 /*_slippageTolerance*/
    ) external pure returns (uint256) {
        return amount;
    }
}