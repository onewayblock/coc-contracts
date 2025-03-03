# Project Contracts Overview

This document provides a brief overview of the main smart contracts in the project. Each contract is explained separately with its purpose, key features, and a description of the intended flow. All contracts are written in Solidity (v0.8.x) and use OpenZeppelin libraries for upgradeability, security, and standard compliance.

---

## Table of Contents

1. [HardCurrencyShop](#hardcurrencys-shop)
2. [NFT](#nft)
3. [NFTSale & OrdinaryNFTSale](#nftsale--ordinarynftsale)
4. [WhitelistNFTSale](#whitelistnftsale)
5. [ReferralShare](#referralshare)
6. [Token (USDC)](#token-usdc)
7. [UniswapHelper](#uniswaphelper)
8. [Verification](#verification)
9. [Vesting](#vesting)
10. [Claim](#claim)

---

## HardCurrencyShop

**Purpose:**  
Facilitates the purchase of hard currency using supported payment tokens or ETH.

**Key Features:**

- Supports multiple payment tokens.
- Integrates with a `Verification` contract for AML/KYC spending validation.
- Uses `UniswapHelper` to calculate token amounts based on USD value and slippage tolerance.
- Records user spending in the `Verification` system.
- Splits the received funds between two "treasure" addresses based on a configurable percentage.

**Flow:**

1. The user calls the `purchase` function with the desired USD amount, payment token address, expected token amount, and slippage tolerance.
2. The contract checks if the payment token is supported.
3. The user's spending is validated through the `Verification` contract.
4. If the payment token is not USDC, the `UniswapHelper` calculates the necessary token amount.
5. The payment is processed (excess ETH is refunded if applicable).
6. Funds are distributed to the two treasure addresses.
7. An event `HardCurrencyBought` is emitted.

---

## NFT

**Purpose:**  
Implements an ERC721-based NFT contract with enhanced metadata management, minting controls, and royalty support.

**Key Features:**

- Uses ERC721A for efficient batch minting.
- Only allows minting from whitelisted contracts.
- Supports metadata updates through backend signature verification (preventing unauthorized changes).
- Implements EIP-2981 for royalty payments.
- Features a transfer lock that can be disabled by the owner to prevent unwanted transfers.

**Flow:**

1. Whitelisted contracts invoke `mint` or `mintWithSameMetadata` to create new tokens along with their metadata.
2. Metadata can later be updated via `updateMetadata` if a valid backend signature is provided.
3. Royalty information can be updated using `setRoyaltyInfo`.
4. The owner may unlock transfers by calling `unlockTransfers` once initial restrictions are no longer needed.

---

## NFTSale & OrdinaryNFTSale

**Purpose:**  
Manages NFT sale events, including listing NFTs for sale, processing purchases, and handling limits per user.

**Key Features:**

- Each sale is defined by a struct containing details like the NFT contract address, token metadata, total quantity, USD price, and per-user limits.
- Allows listing, delisting, pausing, and renewing NFT sales.
- Supports payments in multiple tokens and ETH.
- Integrates with `Verification` to record and validate spending.
- Uses `UniswapHelper` to compute required token amounts if the payment token differs from USDC.
- Provides a crossmint flow (`buyNFTFromCrossmint`) for purchases made by a designated Crossmint address.

**Flow:**

1. The admin lists an NFT for sale using `listNFTForSale` with the sale details.
2. Buyers call `buyNFT` to purchase NFTs, subject to sale limits and spending validation.
3. The contract processes the payment, records the spending, mints NFTs via the NFT contract, and emits the `NFTBought` event.
4. The crossmint purchase flow (`buyNFTFromCrossmint`) works similarly but is restricted to a specific Crossmint address.

**OrdinaryNFTSale:**  
A standard implementation of `NFTSale` without additional whitelist functionality, intended for general NFT sales.

---

## WhitelistNFTSale

**Purpose:**  
Extends the `NFTSale` contract by adding whitelist functionality using a Merkle tree.

**Key Features:**

- Maintains a Merkle root for each sale.
- Requires users to provide a valid Merkle proof before participating in the NFT sale.
- Enforces that only whitelisted addresses can purchase NFTs.

**Flow:**

1. The admin sets the Merkle root for a sale using `setMerkleRoot`.
2. When purchasing via `buyNFT` or `buyNFTFromCrossmint`, users must include a valid Merkle proof.
3. The contract verifies the proof and, if valid, proceeds with the purchase.

---

## ReferralShare

**Purpose:**  
Manages deposits and withdrawals associated with referral codes, allowing users and contracts to benefit from referral activities.

**Key Features:**

- Records deposits (both tokens and ETH) under specific referral codes.
- Allows withdrawal of accumulated referral funds after backend signature verification.
- Maintains a list of supported tokens and whitelisted contracts that can record deposits.
- Emits events on deposit and withdrawal for transparency.

**Flow:**

1. Whitelisted contracts call `recordDeposit` to credit funds to a referral code.
2. Users can later call `withdrawBalances` to claim their referral rewards, provided they supply a valid backend signature.
3. Funds are transferred to the user (either as tokens or ETH), and a `WithdrawalRecorded` event is emitted.

---

## Token

**Purpose:**  
An implementation of the ERC-20 token.

**Key Features:**

- Standard ERC20 functionality with additional support for EIP-2612 permits.
- Owner-controlled minting functionality for supply management.

**Flow:**

1. The owner can mint new tokens to any address by calling the `mint` function.
2. Token holders can use standard ERC20 functions (transfer, approve, etc.) along with permit functionality.

---

## UniswapHelper

**Purpose:**  
Provides helper functions to interact with Uniswap V3, enabling the calculation of token amounts required for a given USD value.

**Key Features:**

- Determines the optimal fee tier for token pairs using Uniswap V3’s factory.
- Uses Uniswap’s Quoter contract to fetch token exchange rates.
- Calculates input token amounts for a desired output amount while enforcing slippage limits.

**Flow:**

1. The contract uses `getFeeTier` to determine the available pool fee for a token pair.
2. It then calculates the required token amount for a specified USD output using `getTokenAmountForOutput`.
3. The main function `getTokenAmount` applies slippage tolerance checks before returning the final token amount.

---

## Verification

**Purpose:**  
Manages user AML/KYC verifications, spending limits, and referral associations while enforcing backend authorization via signatures.

**Key Features:**

- Stores and manages verification data (base/advanced KYC and AML scores) for each user.
- Allows updating of verification statuses and AML scores through functions such as `setBaseKyc`, `setAdvancedAMLScore`, etc., using backend-signed messages.
- Records user spending and enforces spending limits based on verification status.
- Enables configuration of "treasure" addresses and percentages for fund allocation.
- Implements a replay protection mechanism by marking used message hashes.

**Flow:**

1. The backend provides signatures for user verification updates (e.g., KYC/AML scores, referrer codes).
2. Users call the corresponding functions (e.g., `setBaseKyc`, `setReferrer`) with the signature to update their verification status.
3. Every spending event is recorded using `recordSpending`, and the `validateSpending` function enforces AML/KYC limits on further spending.
4. The treasure configuration is used to determine how funds are split in related contracts.

---

## Vesting

**Purpose:**  
Manages the gradual release of tokens to beneficiaries over a predefined vesting schedule, with support for integration with a staking contract.

**Key Features:**

- Allows the creation of custom vesting schedules with configurable start time, cliff, duration, and slice periods.
- Supports token release by beneficiaries or the contract owner.
- Enables the staking contract to release tokens on behalf of beneficiaries via `releaseAndStake`.
- Tracks vesting schedules and released amounts for each beneficiary.
- Provides view functions to query vesting schedules, releasable amounts, and other details.
- Ensures secure withdrawals of unvested tokens by the contract owner.

**Flow:**

1. The owner creates a vesting schedule for a beneficiary using `createVestingSchedule`, specifying the start time, cliff, duration, slice period, and total token amount.
2. Beneficiaries or the owner can release vested tokens by calling `release`, which transfers the releasable amount to the beneficiary.
3. The staking contract can release tokens on behalf of beneficiaries using `releaseAndStake`, ensuring integration with staking mechanisms.
4. The owner can withdraw unvested tokens using `withdraw`, provided there are sufficient withdrawable funds.
5. View functions like `computeReleasableAmount` and `getVestingSchedule` allow users to query vesting details and releasable amounts.

**Events:**

- `VestingScheduleCreated`: Emitted when a new vesting schedule is created.
- `TokensReleased`: Emitted when tokens are released to a beneficiary.
- `FundsWithdrawn`: Emitted when the owner withdraws unvested tokens.
- `StakingAddressUpdated`: Emitted when the staking address is updated.

**Error Handling:**

- Reverts with `InvalidAddress` if invalid addresses are provided.
- Reverts with `InsufficientTokens` if there are not enough tokens to create a vesting schedule.
- Reverts with `Unauthorized` if a non-beneficiary or non-owner attempts to release tokens.
- Reverts with `InsufficientWithdrawableFunds` if the owner attempts to withdraw more than the available unvested tokens.

---

## Claim

**Purpose:**  
Manages the distribution of tokens to eligible users based on a Merkle proof, with optional staking integration and secure withdrawal functionality.

**Key Features:**

- Allows users to claim tokens by providing a valid Merkle proof.
- Integrates with a staking contract to enable direct staking of claimed tokens.
- Tracks claimed tokens to prevent double claims.
- Enables the contract owner to withdraw tokens after a predefined unlock time.
- Uses Merkle trees for efficient and secure whitelist verification.

**Flow:**

1. The owner sets the Merkle root, token address, and staking address during contract deployment.
2. Users call `claimTokens` with their address, the amount of tokens they are eligible to claim, and a valid Merkle proof.
3. The contract verifies the Merkle proof and ensures the user has not already claimed tokens.
4. If the proof is valid and the contract has sufficient tokens, the tokens are transferred to the user.
5. The owner can withdraw tokens from the contract after the unlock time by calling `withdrawTokens`.

**Events:**

- `MerkleRootUpdated`: Emitted when the Merkle root is updated.
- `TokenAddressUpdated`: Emitted when the token address is updated.
- `StakingAddressUpdated`: Emitted when the staking address is updated.
- `TokensClaimed`: Emitted when a user successfully claims tokens.
- `TokensWithdrawn`: Emitted when the owner withdraws tokens from the contract.

**Error Handling:**

- Reverts with `InvalidAddress` if invalid addresses are provided.
- Reverts with `InvalidUnlockTime` if the unlock time is in the past.
- Reverts with `InvalidReceiver` if the receiver is not the caller (unless called by the staking contract).
- Reverts with `TokensAlreadyClaimed` if a user attempts to claim tokens more than once.
- Reverts with `InvalidTokens` if the token amount is zero.
- Reverts with `InsufficientBalance` if the contract does not have enough tokens to fulfill the claim.
- Reverts with `InvalidProof` if the provided Merkle proof is invalid.
- Reverts with `WithdrawLocked` if the owner attempts to withdraw tokens before the unlock time.
- Reverts with `InvalidAmount` if the withdrawal amount is zero.
- Reverts with `InsufficientContractBalance` if the contract does not have enough tokens for withdrawal.

---
