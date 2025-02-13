// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title USDC Token
 * @dev A mock implementation of the USDC token with EIP-2612 support and owner-controlled minting.
 */
contract Token is ERC20, ERC20Permit, Ownable {
    /**
     * @dev Constructor sets the token name, symbol, and owner.
     * @param _name The name of the token (e.g., "USD Coin").
     * @param _symbol The symbol of the token (e.g., "USDC").
     */
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol)
    ERC20Permit(_name)  // The token name is used for the EIP-2612 domain separator.
    Ownable(msg.sender) {}

    /**
     * @dev Allows the owner to mint tokens to a specific address.
     * @param to The address to receive the minted tokens.
     * @param amount The amount of tokens to mint (in smallest units, e.g., 1 USDC = 1e6).
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}