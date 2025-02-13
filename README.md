# Project Contracts Overview

This document provides a brief overview of the main smart contracts in the project. Each contract is explained separately with its purpose, key features, and a description of the intended flow. All contracts are written in Solidity (v0.8.x) and use OpenZeppelin libraries for upgradeability, security, and standard compliance.

---

## Table of Contents

1. [HardCurrencyShop](#hardcurrencys-shop)
2. [ReferralShare](#referralshare)
3. [UniswapHelper](#uniswaphelper)
4. [Verification](#verification)

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
