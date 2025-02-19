// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {INFT} from "./interfaces/INFT.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title NFT
 * @dev Implementation of the INFT interface with metadata management, whitelisting, and EIP-2981 royalty support.
 */
contract NFT is INFT, ERC721A, Ownable, IERC2981 {
    using ECDSA for bytes32;

    /// @notice Address of the backend signer responsible for generating valid signatures
    address public backendSigner;

    /// @notice Indicates whether transfers are locked
    bool public transferLocked = true;

    /// @notice Tracks used message hashes to prevent replay attacks
    mapping(bytes32 => bool) private usedHashes;

    /// @notice Mapping from tokenId to its metadata
    mapping(uint256 => string) private tokenMetadata;

    /// @notice Contract metadata
    string contractMetadata;

    /// @notice Whitelisted contracts allowed to call mint functions
    mapping(address => bool) private whitelistedContracts;

    // *********** EIP-2981 (Royalty) Implementation ***********

    /// @notice Address that receives royalty payments
    address public royaltyReceiver;

    /// @notice Royalty fee in basis points (parts per 10,000)
    uint96 public royaltyBasisPoints;

    /**
     * @dev Constructor to initialize the contract.
     * @param _name Name of the NFT collection
     * @param _symbol Symbol of the NFT collection
     * @param _backendSigner Address of the backend signer
     * @param _whitelistedContracts List of initial whitelisted contracts
     * @param _owner Owner of the contract
     * @param _royaltyReceiver Address to receive royalty payments
     * @param _royaltyBasisPoints Royalty fee in basis points (parts per 10,000)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        address _backendSigner,
        address[] memory _whitelistedContracts,
        address _owner,
        address _royaltyReceiver,
        uint96 _royaltyBasisPoints
    ) ERC721A(_name, _symbol) Ownable(_owner) {
        if (
            _backendSigner == address(0) ||
            _royaltyReceiver == address(0)
        ) {
            revert InvalidAddress();
        }
        if (_royaltyBasisPoints > 10000) {
            revert InvalidRoyaltyBasisPoints();
        }

        contractMetadata = _contractURI;
        backendSigner = _backendSigner;

        for (uint256 i = 0; i < _whitelistedContracts.length; i++) {
            if (_whitelistedContracts[i] == address(0)) {
                revert InvalidAddress();
            }
            whitelistedContracts[_whitelistedContracts[i]] = true;
            emit ContractWhitelisted(_whitelistedContracts[i]);
        }

        royaltyReceiver = _royaltyReceiver;
        royaltyBasisPoints = _royaltyBasisPoints;

        emit RoyaltyInfoUpdated(
            _royaltyReceiver,
            _royaltyBasisPoints
        );
    }

    /**
     * @inheritdoc INFT
     */
    function setBackendSigner(address _newSigner) external override onlyOwner {
        if (_newSigner == address(0)) {
            revert InvalidAddress();
        }
        backendSigner = _newSigner;
        emit BackendSignerChanged(_newSigner);
    }

    /**
     * @inheritdoc INFT
     */
    function addWhitelistedContract(
        address _contractAddress
    ) external override onlyOwner {
        if (whitelistedContracts[_contractAddress]) {
            revert AlreadyWhitelisted();
        }
        whitelistedContracts[_contractAddress] = true;
        emit ContractWhitelisted(_contractAddress);
    }

    /**
     * @inheritdoc INFT
     */
    function removeWhitelistedContract(
        address _contractAddress
    ) external override onlyOwner {
        if (!whitelistedContracts[_contractAddress]) {
            revert NotWhitelisted();
        }
        delete whitelistedContracts[_contractAddress];
        emit ContractRemovedFromWhitelist(_contractAddress);
    }

    /**
     * @inheritdoc INFT
     */
    function mint(
        address _to,
        uint256 _quantity,
        string[] memory _metadata
    ) external override {
        if (!whitelistedContracts[msg.sender]) {
            revert NotWhitelisted();
        }
        if (_metadata.length != _quantity) {
            revert InvalidMetadataCount();
        }

        uint256 startTokenId = _nextTokenId();
        _mint(_to, _quantity);

        for (uint256 i = 0; i < _quantity; i++) {
            tokenMetadata[startTokenId + i] = _metadata[i];
            emit MetadataUpdate(startTokenId + i);
        }
    }

    /**
     * @inheritdoc INFT
     */
    function mintWithSameMetadata(
        address _to,
        uint256 _quantity,
        string memory _metadata
    ) external override {
        if (!whitelistedContracts[msg.sender]) {
            revert NotWhitelisted();
        }

        uint256 startTokenId = _nextTokenId();
        _mint(_to, _quantity);

        for (uint256 i = 0; i < _quantity; i++) {
            tokenMetadata[startTokenId + i] = _metadata;
        }
    }

    /**
     * @inheritdoc INFT
     */
    function updateMetadata(
        uint256 _tokenId,
        string memory _newMetadata,
        bytes memory _signature
    ) external override {
        bytes32 messageHash = keccak256(
            abi.encode(address(this), 'updateMetadata', _tokenId, _newMetadata, block.chainid)
        );
        if (!_verifySignature(messageHash, _signature)) {
            revert InvalidSigner();
        }
        tokenMetadata[_tokenId] = _newMetadata;

        emit MetadataUpdate(_tokenId);
    }

    /**
     * @inheritdoc ERC721A
     */
    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        if (!_exists(_tokenId)) {
            revert InvalidTokenId();
        }

        return tokenMetadata[_tokenId];
    }


    /**
     * @inheritdoc INFT
     */
    function contractURI() external view override returns (string memory) {
        return contractMetadata;
    }

    /**
     * @inheritdoc INFT
     */
    function isContractWhitelisted(
        address _contractAddress
    ) external view override returns (bool) {
        return whitelistedContracts[_contractAddress];
    }

    /**
     * @dev Internal function to verify signature validity.
     * @param _messageHash The hash of the message being verified.
     * @param _signature The signature to verify.
     * @return True if the signature is valid, false otherwise.
     */
    function _verifySignature(
        bytes32 _messageHash,
        bytes memory _signature
    ) private returns (bool) {
        if (usedHashes[_messageHash]) {
            revert InvalidMessageHash();
        }

        usedHashes[_messageHash] = true;

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            _messageHash
        );
        return ethSignedMessageHash.recover(_signature) == backendSigner;
    }

    // ******************* EIP-2981 (Royalty) Functions *******************

    /**
     * @notice Sets the royalty information for all tokens.
     * @param _royaltyReceiver Address to receive royalty payments.
     * @param _royaltyBasisPoints Royalty fee in basis points (parts per 10,000).
     */
    function setRoyaltyInfo(address _royaltyReceiver, uint96 _royaltyBasisPoints) external onlyOwner {
        if (_royaltyReceiver == address(0)) {
            revert InvalidAddress();
        }
        if (_royaltyBasisPoints > 10000) {
            revert InvalidRoyaltyBasisPoints();
        }

        royaltyReceiver = _royaltyReceiver;
        royaltyBasisPoints = _royaltyBasisPoints;

        emit RoyaltyInfoUpdated(
            _royaltyReceiver,
            _royaltyBasisPoints
        );
    }

    /**
     * @notice Returns royalty payment information for a given token and sale price.
     * @param _tokenId The token identifier (unused, but required for standard compliance).
     * @param _salePrice Sale price of the token.
     * @return receiver Address to receive the royalty payment.
     * @return royaltyAmount Calculated royalty amount based on the sale price.
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override returns (address receiver, uint256 royaltyAmount)
    {
        royaltyAmount = (_salePrice * royaltyBasisPoints) / 10000;
        receiver = royaltyReceiver;
    }

    /**
     * @notice Override supportsInterface to include support for EIP-2981.
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721A, IERC165) returns (bool)
    {
        return
            _interfaceId == 0x49064906 || // ERC-4906
            _interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    /**
     * @notice Unlocks token transfers. Can only be called by the owner.
     */
    function setContractURI(string memory _contractURI) external onlyOwner {
        contractMetadata = _contractURI;

        emit ContractURIUpdated();
    }

    /**
     * @notice Unlocks token transfers. Can only be called by the owner.
     */
    function unlockTransfers() external onlyOwner {
        transferLocked = false;

        emit TransfersUnlocked();
    }

    /**
     * @dev Prevents token approvals if transfers are locked.
     */
    function approve(address _to, uint256 _tokenId) public override payable {
        if (transferLocked) {
            revert TransfersAreLocked();
        }
        super.approve(_to, _tokenId);
    }

    /**
     * @dev Prevents setting operator approvals if transfers are locked.
     */
    function setApprovalForAll(address _operator, bool _approved) public override {
        if (transferLocked) {
            revert TransfersAreLocked();
        }
        super.setApprovalForAll(_operator, _approved);
    }

    /**
     * @dev Prevents token transfers if they are locked.
     * This function is an override of the ERC721A hook `_beforeTokenTransfers`.
     */
    function _beforeTokenTransfers(
        address _from,
        address _to,
        uint256 _startTokenId,
        uint256 _quantity
    ) internal virtual override {
        if (transferLocked && _from != address(0)) {
            revert TransfersAreLocked();
        }
        super._beforeTokenTransfers(_from, _to, _startTokenId, _quantity);
    }
}