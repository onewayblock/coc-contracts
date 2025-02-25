
#### [NEW] Use of `_mint` instead of `_safeMint` in `NFT`
##### Location
| File                                                                                                                                             | Location                                         | Line |
| ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------ | ---- |
| [NFT.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/d8577a7c4f35c740d5863aeafa97702274543987/contracts/NFT.sol#L148) | contract `NFT` > function `mint`                 | 148  |
| [NFT.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/d8577a7c4f35c740d5863aeafa97702274543987/contracts/NFT.sol#L169) | contract `NFT` > function `mintWithSameMetadata` | 169  |

##### Description
In the mentioned locations, the internal function `_mint` is used for minting NFT tokens. However, to prevent minting tokens for a contract that does not support `ERC721A`, the function `_safeMint` should be used.

### CLASH RESOLVING:

Added code fixes

---

#### [NEW] The latest version of `ERC721A` has not been audited in `NFT`
##### Location
File | Location | Line
--- | --- | ---
[NFT.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/d8577a7c4f35c740d5863aeafa97702274543987/contracts/NFT.sol#L16) | contract `NFT` | 16

##### Description
In the contract `NFT`, `ERC721A` is inherited as the base contract. The latest versions of this contract have not been audited, which introduces additional risks to the protocol.

### CLASH RESOLVING:

Copied ERC721A source code for audit from https://github.com/chiru-labs/ERC721A

---

#### [NEW] Possible purchases without validation if `baseAmlLimit > _amount > 0` in `Verification`
##### Location
File | Location | Line
--- | --- | ---
[Verification.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/d8577a7c4f35c740d5863aeafa97702274543987/contracts/Verification.sol#L333) | contract `Verification` > function `validateSpending` | 333
##### Description
In the function `validateSpending` of the contract `Verification`, if `dailyAmount < baseAmlLimit`, no actions are performed. This means that if the NFT price is lower than `baseAmlLimit`, it is possible to purchase an NFT without validation in the function `validateSpending`.

Additionally, the contracts `NFTSale` and `OrdinaryNFTSale` do not check whether buyers are whitelisted (unlike `WhitelistNFTSale`). Therefore, if the daily limit is reached in the function `validateSpending`, or the `totalLimitPerUser` is exceeded, it is possible to continue purchasing NFTs from another arbitrary address.

A similar issue is also present when making purchases in the contract `HardCurrencyShop`.

### CLASH RESOLVING:

1. We allow to buy less than dailyAmount without any aml verifications, so it's not an issue
2. Ordinary NFT Sale is made for selling NFT to everyone without any restrictions (exclude KYC/AML verifications), and we have Whitelist NFT Sale where will be listed positions only available for buying from whitelisted addresses

---

#### [NEW] Incorrect `msg.sender` whitelist check in `WhitelistNFTSale`
##### Location
File | Location | Line
--- | --- | ---
[WhitelistNFTSale.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/bb6ae7cd910dd5e0e42bb4dc1f8c2bd431d95221/contracts/WhitelistNFTSale.sol#L80) | contract `WhitelistNFTSale` > function `buyNFT` | 80
[WhitelistNFTSale.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/bb6ae7cd910dd5e0e42bb4dc1f8c2bd431d95221/contracts/WhitelistNFTSale.sol#L111) | contract `WhitelistNFTSale` > function `buyNFTFromCrossmint` | 111

##### Description
In the mentioned locations, `msg.sender` is checked for whitelist inclusion. However, in the case of the following functions:
- In `buyNFT`, the actual user address may be present in the calldata if `msg.sender == trustedForwarder`.
- In `buyNFTFromCrossmint`, the whitelist check is meaningless if `msg.sender != crossmintAddress`.

It is likely that, in the case of the `buyNFT` function, the whitelist check should be performed on the result of the `_msgSender` function instead of `msg.sender` to verify the actual user address.

For the `buyNFTFromCrossmint` function, it would be more appropriate to check whether the `_receiver` parameter is included in the whitelist, as checking `msg.sender` is not meaningful since only `crossmintAddress` can call this function.

### CLASH RESOLVING:

Added code fixes

---

#### [NEW] Unable to delist when `soldQuantity == 0` in `NFTSale`
##### Location
| File                                                                                                                                                     | Location                                          | Line |
| -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ---- |
| [NFTSale.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/d8577a7c4f35c740d5863aeafa97702274543987/contracts/NFTSale.sol#L221) | contract `NFTSale` > function `delistNFTFromSale` | 221  |

##### Description
In the function `delistNFTFromSale` of contract `NFTSale`, there is a check requiring at least one token sale to proceed with delisting. This results in an erroneously listed `NFTSale` being impossible to remove from the listing.

Additionally, the user will receive the error `SaleDoesNotExist`, which is incorrect since the `NFTSale` does exist.

Instead of checking `soldQuantity == 0`, it would be more appropriate to check whether `quantity == 0`.

### CLASH RESOLVING:


Added code fixes
For now we will remove only if quantity > 0 (sale exists) and no NFT's were sold

---

#### [NEW] Royalty reset due to rounding during division in `NFT`
##### Location
| File                                                                                                                                             | Location                                | Line |
| ------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------- | ---- |
| [NFT.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/d8577a7c4f35c740d5863aeafa97702274543987/contracts/NFT.sol#L280) | contract `NFT` > function `royaltyInfo` | 280  |

##### Description
In the function `royaltyInfo` of contract `NFT`, `royaltyAmount` may become `0` if the product of `_salePrice` and `royaltyBasisPoints` is less than `10000` due to rounding during division:
```solidity
royaltyAmount = (_salePrice * royaltyBasisPoints) / 10000;
```
It is important to consider that some tokens have a small `decimals` value. For example, the GUSD token has `decimals = 2`. In this case, when purchasing for `$1` with a `0.5%` royalty rate, the royalty will be rounded down to zero.

### CLASH RESOLVING:

Added code fixes

---

#### [NEW] Unused imports in `NFTSale.sol`
##### Location
| File                                                                                                                                                    | Location | Line |
| ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ---- |
| [NFTSale.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/d8577a7c4f35c740d5863aeafa97702274543987/contracts/NFTSale.sol#L7)  | -        | 7    |
| [NFTSale.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/d8577a7c4f35c740d5863aeafa97702274543987/contracts/NFTSale.sol#L15) | -        | 15   |

##### Description
In the mentioned locations, contracts are imported but not used in the code.

### CLASH RESOLVING:

Added code fixes

---

#### [NEW] Unused `_fee` parameter in `WhitelistNFTSale`
##### Location
File | Location | Line
--- | --- | ---
[WhitelistNFTSale.sol](https://github.com/oxor-io/onewayblock-clash-pre-audit-contracts/tree/d8577a7c4f35c740d5863aeafa97702274543987/contracts/WhitelistNFTSale.sol#L74) | contract `WhitelistNFTSale` > function `buyNFT` | 74

##### Description
In the function `buyNFT` of contract `WhitelistNFTSale`, the `_fee` parameter is not used.


### CLASH RESOLVING:

Added code fixes

---

