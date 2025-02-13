// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract DummyReferralShare {
    event DepositRecorded(address referrer, address paymentToken, uint256 amount);

    function recordDeposit(address referrer, address paymentToken, uint256 amount) external {
        emit DepositRecorded(referrer, paymentToken, amount);
    }
}