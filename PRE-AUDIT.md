
#### [NEW] Potential manipulation of `totalTokenAmount` value in `HardCurrencyShop`
##### Location
File | Location | Line
--- | --- | ---
[HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L87) | contract `HardCurrencyShop` > function `purchase` | 87

##### Description
In the `purchase` function of the `HardCurrencyShop` contract, there is a possibility to manipulate `totalTokenAmount` values since `_expectedTokenAmount` and `_slippageTolerance` parameters are not validated. Using techniques like flash loans, one can manipulate the price to maximize the effect, paying less `totalTokenAmount` while gaining more benefit from `_USDAmount`. In essence, the slippage protection is not working as intended.

For resolving this issue, it's recommended to rely on oracle values. In Uniswap V3, each pool has a built-in [oracle](https://docs.uniswap.org/concepts/protocol/oracle).

It needs to be clarified whether `_expectedTokenAmount` and `_slippageTolerance` values are provided by the backend. If so, it would make sense to implement backend signature verification.


### CLASH RESOLVING:

We will use only tokens which have USDC pool pair (like ETH, USDT, own token)
We will block transaction if expected token amount is less than real amount
Added additional checks

---

#### [NEW] Unsafe ether transfer in `HardCurrencyShop`, `ReferralShare`
##### Location
File | Location | Line
--- | --- | ---
[HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/blob/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L114) | contract `HardCurrencyShop` > function `_handlePayment` | 114
[HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/blob/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L115) | contract `HardCurrencyShop` > function `_handlePayment` | 115
[HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/blob/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L191) | contract `HardCurrencyShop` > function `_handlePayment` | 191
[ReferralShare.sol](https://github.com/onewayblock/clash-pre-audit-contracts/blob/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/ReferralShare.sol#L107) | contract `ReferralShare` > function `withdrawBalances` | 107

##### Description
In the mentioned locations, using the `transfer` method for sending ether is deprecated and vulnerable. It's recommended to use the `call` method instead. More details can be found [here](https://solidity-by-example.org/sending-ether/).

### CLASH RESOLVING:
Added code fixes

---

#### [NEW] Potential reentrancy in `HardCurrencyShop`, `ReferralShare`
##### Location
File | Location | Line
--- | --- | ---
[HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/blob/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L114) | contract `HardCurrencyShop` > function `_handlePayment` | 114
[HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/blob/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L115) | contract `HardCurrencyShop` > function `_handlePayment` | 115
[HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/blob/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L191) | contract `HardCurrencyShop` > function `_handlePayment` | 191
[ReferralShare.sol](https://github.com/onewayblock/clash-pre-audit-contracts/blob/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/ReferralShare.sol#L107) | contract `ReferralShare` > function `withdrawBalances` | 107

##### Description
In the mentioned locations, reentrancy is possible since there are ether operations. We recommend using OpenZeppelin's nonReentrant modifier for user-facing functions.

### CLASH RESOLVING:
Added code fixes

---

#### [NEW] Possibility to send ether alongside tokens in `HardCurrencyShop`
##### Location
File | Location | Line
--- | --- | ---
[HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L70) | contract `HardCurrencyShop` > function `purchase` | 70

##### Description
In the `purchase` function of `HardCurrencyShop` contract, it's possible to send ether while specifying a token as the payment method. In this case, the ether will be lost and stuck in the contract.

### CLASH RESOLVING:
Added code fixes

---

#### [NEW] Unable to reuse function calls with signature in `Verification`
##### Location
File | Location | Line
--- | --- | ---
[HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/blob/main/contracts/Verification.sol#L501) | contract `Verification` > function `_verifySignature` | 501

##### Description
In the `Verification` contract, the `_messageHash` becomes invalid after use
```solidity
    function _verifySignature(
        bytes32 _messageHash,
        bytes memory _signature
    ) private returns (bool) {
        if(usedHashes[_messageHash]) {
            revert InvalidMessageHash();
        }

        usedHashes[_messageHash] = true;

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            _messageHash
        );
        return ethSignedMessageHash.recover(_signature) == backendSigner;
    }
```

but the hash itself doesn't contain unique parameters like a nonce.
This means that functions requiring signature validation can only be called once, as subsequent calls with the same parameters will be rejected.
For example,
 ```solidity
        IVerification(verification).verifySignaturePublic(
            keccak256(abi.encode(address(this), 'withdrawBalances', sender, _referralCode, block.chainid)),
            _signature
        );

        msgHash =  keccak256(abi.encode(address(this), 'withdrawBalances', sender, _referralCode, block.chainid))
```



We recommend adding a nonce field to the messageHash, which would be a sequential transaction number, and implementing `nonces[msg.sender]++` increment in the `_verifySignature` function after verification. This way, the current signature becomes invalid after use, and new signatures will differ by their sequential number.

### CLASH RESOLVING:

For withdraw balance added timestamp field which will be the same as user's request timestamp

---

#### [NEW] A compromised address from the whitelist can withdraw all funds in `ReferralShare`
##### Location
| File                                                                                                                                                        | Location                                            | Line |     |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- | ---- | --- |
| [ReferralShare.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/ReferralShare.sol#L79) | contract `ReferralShare` > function `recordDeposit` | 79   |     |

##### Description
In the `recordDeposit` function of the `ReferralShare` contract, tokens are added to the balance without actually being transferred to the contract. Additionally, there are no restrictions on the amount by which the balance can be increased.

If one of the addresses in the whitelist is compromised, it can set the maximum possible balance for "its" referral code for each of the tokens stored in the contract. Subsequently, using this referral code, all tokens held in the contract can be withdrawn.

### CLASH RESOLVING:
Added code fixes
About compromised addresses. For now, we're using OpenZeppelin Defender Relayer for all backend transactions and we don't have access to the private key of this relayer wallet, so it's impossible to compromise it.

---

#### [NEW] `userVerifications` parameters cannot be changed in `Verification`
##### Location
| File | Location | Line |
| --- | --- | --- |
| [Verification.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/Verification.sol#L111) | contract `Verification` > function `setBaseKyc` | 111 |
| [Verification.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/Verification.sol#L144) | contract `Verification` > function `setAdvancedKyc` | 144 |
| [Verification.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/Verification.sol#L177) | contract `Verification` > function `setBaseAMLScore` | 177 |
| [Verification.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/Verification.sol#L210) | contract `Verification` > function `setAdvancedAMLScore` | 210 |

##### Description
In the specified locations, once a value is set in `userVerifications`, it cannot be changed. This leads to the following issues:
- For `baseKyc/advancedKyc`, passing a `bool` parameter becomes meaningless, as only `true` can be set. Calling the setter with `false` has no effect other than emitting an event.
- For `baseAMLScore/advancedAMLScore`, the inability to modify values in `userVerifications` means that a user can maintain a good score even if it deteriorates significantly. The protocol will be unable to revoke the user's access to higher limits.
- In all four setters, an event with the name `*Updated` is emitted, even though the value is only set once and cannot be changed.


### CLASH RESOLVING:
Removed check for set status for these fields.
For KYC we will have possibility to revoke verification for specific cases.
For AML will be possible to recheck it and change in the contract

---

#### [NEW] If `_msgSender` is a contract, it should be able to receive Ether in `HardCurrencyShop`
##### Location
| File | Location | Line |
| --- | --- | --- |
| [HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L240) | contract `HardCurrencyShop` > function `_msgSender` | 240 |

##### Description
In the `_msgSender` function of the `HardCurrencyShop` contract, the returned address may belong to a contract. Therefore, it is necessary to check whether the contract can receive Ether before transferring funds and to return a readable error message if the transfer fails.


### CLASH RESOLVING:
Added code fixes

---

#### [NEW] Missing `_disableInitializers` call in `HardCurrencyShop`, `ReferralShare`, `Verification`
##### Location
| File | Location | Line |
| --- | --- | --- |
| [HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L38) | contract `HardCurrencyShop` | 38 |
| [ReferralShare.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/ReferralShare.sol#L34) | contract `ReferralShare` | 34 |
| [Verification.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/Verification.sol#L69) | contract `Verification` | 69 |

##### Description
In the specified locations, the `_disableInitializers` function is not called in the constructor. Given the presence of the `Proxies.sol` file, it is likely that the contracts are used through a proxy. In this case, calling `_disableInitializers` in the constructor is recommended.


### CLASH RESOLVING:
Added code fixes

---

#### [NEW] Unused function in `Verification`
##### Location
| File | Location | Line |
| --- | --- | --- |
| [Verification.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/Verification.sol#L566) | contract `Verification` > function `setTrustedForwarder` | 566 |

##### Description
The `setTrustedForwarder` function in the `Verification` contract is not used, nor is the `trustedForwarder` variable.

### CLASH RESOLVING:
Added code fixes

---

#### [NEW] Array length determination should be assigned to a separate memory variable in `HardCurrencyShop`, `ReferralShare`, `UniswapHelper`
##### Location
| File | Location | Line |
| --- | --- | --- |
| [HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L204) | contract `HardCurrencyShop` > function `_isTokenSupported` | 204 |
| [HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L218) | contract `HardCurrencyShop` > function `_removePaymentToken` | 218 |
| [ReferralShare.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/ReferralShare.sol#L98) | contract `ReferralShare` > function `withdrawBalances` | 98 |
| [UniswapHelper.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/UniswapHelper.sol#L98) | contract `UniswapHelper` > function `getFeeTier` | 98 |

##### Description
In the specified locations, the array length is determined within the loop for each iteration while the array resides in storage. For gas optimization, this determination should be assigned to a separate memory variable.

### CLASH RESOLVING:
Added code fixes

---

#### [NEW] Lack of validations in `HardCurrencyShop`
##### Location
| File | Location | Line |
| --- | --- | --- |
| [HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L61) | contract `HardCurrencyShop` > function `initialize` | 61 |
| [ReferralShare.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/ReferralShare.sol#L54) | contract `ReferralShare` > function `initialize` | 54 |
| [ReferralShare.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/ReferralShare.sol#L57) | contract `ReferralShare` > function `initialize` | 57 |
| [Verification.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/Verification.sol#L329) | contract `Verification` > function `addAllowedContract` | 329 |

##### Description
In the `initialize` function of the `HardCurrencyShop` contract, there is no validation to check for duplicate addresses in the array or an empty `_paymentTokens` list.
In the `initialize` function of the `ReferralShare` contract, duplicate addresses in the `_supportedTokens` array are not checked, nor are zero addresses in the `_whitelistedContracts` array.
In the `addAllowedContract` function of the `Verification` contract, there is no validation to check for a zero address in the provided contract.

### CLASH RESOLVING:
Added code fixes

---

#### [NEW] Missing check for a zero address in `supportedTokens` for handling Ether in `HardCurrencyShop`
##### Location
| File | Location | Line |
| --- | --- | --- |
| [HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L61) | contract `HardCurrencyShop` > function `initialize` | 61 |

##### Description
In the `initialize` function of the `HardCurrencyShop` contract, supported tokens for purchases are set. However, there is no validation to check for the presence of a zero address in the list, which is used to support native tokens. For example, setting a zero token as a native token is used in the `ReferralShare` contract.


### CLASH RESOLVING:
Sale can be ONLY in USDC for example, so ETH payment is not required, so removed adding logic also from Referral share contract

---

#### [NEW] `Initializable` is already inherited within `OwnableUpgradeable` in `HardCurrencyShop`, `ReferralShare`, `Verification`
##### Location
| File | Location | Line |
| --- | --- | --- |
| [HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L20) | contract `HardCurrencyShop` | 20 |
| [ReferralShare.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/ReferralShare.sol#L16) | contract `ReferralShare` | 16 |
| [Verification.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/Verification.sol#L16) | contract `Verification` | 16 |

##### Description
In the specified locations, explicit inheritance from the `Initializable` contract is unnecessary, as its logic is already inherited through `OwnableUpgradeable`.

### CLASH RESOLVING:
Added code fixes

---

#### [NEW] Unused imports in `HardCurrencyShop.sol`
##### Location
| File | Location | Line |
| --- | --- | --- |
| [HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L10) | - | 10 |
| [HardCurrencyShop.sol](https://github.com/onewayblock/clash-pre-audit-contracts/tree/cd9722082d145d7ea2b17567d2cacc26f77f22c9/contracts/HardCurrencyShop.sol#L11) | - | 11 |


### CLASH RESOLVING:
Added code fixes

---