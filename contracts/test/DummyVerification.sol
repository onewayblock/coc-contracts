// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract DummyVerification {
    mapping(address => string) public referrers;

    /// @notice Addresses of treasures and their percentage allocation
    address public treasureFirstAddress = 0x1000000000000000000000000000000000000001;
    address public treasureSecondAddress = 0x1000000000000000000000000000000000000002;
    uint256 public treasureFirstPercentage = 3000;
    uint256 public treasureSecondPercentage = 7000;

    function validateSpending(address, uint256) external pure {}

    function recordSpending(address, uint256) external pure {}

    function verifySignaturePublic(bytes32, bytes memory) external pure {}

    function setReferrer(address user, string calldata ref) external {
        referrers[user] = ref;
    }

    function getReferrer(address user) external view returns (string memory) {
        return referrers[user];
    }

    function getTreasureConfiguration() external view returns (
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
}