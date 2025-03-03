import { ethers } from 'hardhat';
import { expect } from 'chai';
import { NFT } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('NFT Contract', function () {
  let nft: NFT;
  let owner: SignerWithAddress;
  let user: SignerWithAddress;
  let backendSigner: SignerWithAddress;
  let whitelistedContract: SignerWithAddress;
  const chainId = 31337;
  const ROYALTY_BASIS_POINTS = 500; // 5%
  const SALE_PRICE = ethers.parseEther("1");
  const CONTRACT_URI = '{"name":"OpenSea Creatures","description":"OpenSea Creatures are adorable aquatic beings primarily for demonstrating what can be done using the OpenSea platform. Adopt one today to try out all the OpenSea buying, selling, and bidding feature set.","image":"https://external-link-url.com/image.png","banner_image":"https://external-link-url.com/banner-image.png","featured_image":"https://external-link-url.com/featured-image.png","external_link":"https://external-link-url.com","collaborators":["0x0000000000000000000000000000000000000000"]}';

  beforeEach(async function () {
    [owner, user, backendSigner, whitelistedContract] = await ethers.getSigners();

    const NFTFactory = await ethers.getContractFactory('NFT');
    nft = await NFTFactory.deploy(
        'TestNFT',
        'TNFT',
        CONTRACT_URI,
        backendSigner.address,
        [whitelistedContract.address],
        owner.address,
        owner.address,
        ROYALTY_BASIS_POINTS
    );
    await nft.waitForDeployment();
  });

  describe('Deployment', function () {
    it('Should set the correct backend signer', async function () {
      expect(await nft.backendSigner()).to.equal(backendSigner.address);
    });

    it('Should revert if backend signer is zero address', async function () {
      const NFTFactory = await ethers.getContractFactory('NFT');
      await expect(
          NFTFactory.deploy(
              'TestNFT',
              'TNFT',
              CONTRACT_URI,
              ethers.ZeroAddress,
              [],
              owner.address,
              owner.address,
              1000
          )
      ).to.be.revertedWithCustomError(nft, 'InvalidAddress');
    });

    it('Should revert if royalty receiver is zero address', async function () {
      const NFTFactory = await ethers.getContractFactory('NFT');
      await expect(
          NFTFactory.deploy(
              'TestNFT',
              'TNFT',
              CONTRACT_URI,
              backendSigner.address,
              [],
              owner.address,
              ethers.ZeroAddress,
              1000
          )
      ).to.be.revertedWithCustomError(nft, 'InvalidAddress');
    });

    it('Should revert if royalty basis points are greater than 10000', async function () {
      const NFTFactory = await ethers.getContractFactory('NFT');
      await expect(
          NFTFactory.deploy(
              'TestNFT',
              'TNFT',
              CONTRACT_URI,
              backendSigner.address,
              [],
              owner.address,
              owner.address,
              10001
          )
      ).to.be.revertedWithCustomError(nft, 'InvalidRoyaltyBasisPoints');
    });
  });

  describe('setBackendSigner', function () {
    it('Should update the backend signer when called by owner', async function () {
      await nft.connect(owner).setBackendSigner(user.address);
      expect(await nft.backendSigner()).to.equal(user.address);
    });

    it('Should revert if non-owner tries to update the backend signer', async function () {
      await expect(
          nft.connect(user).setBackendSigner(user.address)
      ).to.be.revertedWithCustomError(nft, 'OwnableUnauthorizedAccount');
    });

    it('Should revert if new backend signer is zero address', async function () {
      await expect(
          nft.connect(owner).setBackendSigner(ethers.ZeroAddress)
      ).to.be.revertedWithCustomError(nft, 'InvalidAddress');
    });
  });

  describe('addWhitelistedContract', function () {
    it('Should add a contract to whitelist when called by owner', async function () {
      await nft.connect(owner).addWhitelistedContract(user.address);
      expect(await nft.isContractWhitelisted(user.address)).to.be.true;
    });

    it('Should revert if the contract is already whitelisted', async function () {
      await expect(
          nft.connect(owner).addWhitelistedContract(whitelistedContract.address)
      ).to.be.revertedWithCustomError(nft, 'AlreadyWhitelisted');
    });

    it('Should revert if non-owner tries to whitelist a contract', async function () {
      await expect(
          nft.connect(user).addWhitelistedContract(user.address)
      ).to.be.revertedWithCustomError(nft, 'OwnableUnauthorizedAccount');
    });
  });

  describe('removeWhitelistedContract', function () {
    it('Should remove a whitelisted contract when called by owner', async function () {
      await nft.connect(owner).removeWhitelistedContract(whitelistedContract.address);
      expect(await nft.isContractWhitelisted(whitelistedContract.address)).to.be.false;
    });

    it('Should revert if the contract is not whitelisted', async function () {
      await expect(
          nft.connect(owner).removeWhitelistedContract(user.address)
      ).to.be.revertedWithCustomError(nft, 'NotWhitelisted');
    });

    it('Should revert if non-owner tries to remove a contract from whitelist', async function () {
      await expect(
          nft.connect(user).removeWhitelistedContract(whitelistedContract.address)
      ).to.be.revertedWithCustomError(nft, 'OwnableUnauthorizedAccount');
    });
  });

  describe('mint', function () {
    it('Should mint tokens with metadata when called by a whitelisted contract', async function () {
      const metadata = [JSON.stringify({ id: 1, name: 'NFT 1' })];
      await nft.connect(whitelistedContract).mint(user.address, 1, metadata);

      expect(await nft.ownerOf(0)).to.equal(user.address);
      expect(await nft.tokenURI(0)).to.equal(metadata[0]);
    });

    it('Should revert if mint is called by a non-whitelisted contract', async function () {
      const metadata = [JSON.stringify({ id: 1, name: 'NFT 1' })];
      await expect(
          nft.connect(user).mint(user.address, 1, metadata)
      ).to.be.revertedWithCustomError(nft, 'NotWhitelisted');
    });

    it('Should revert if metadata count does not match quantity', async function () {
      const metadata = [JSON.stringify({ id: 1, name: 'NFT 1' })];
      await expect(
          nft.connect(whitelistedContract).mint(user.address, 2, metadata)
      ).to.be.revertedWithCustomError(nft, 'InvalidMetadataCount');
    });
  });

  describe('mintWithSameMetadata', function () {
    it('Should mint tokens with the same metadata when called by a whitelisted contract', async function () {
      const metadata = JSON.stringify({ id: 1, name: 'NFT' });
      await nft.connect(whitelistedContract).mintWithSameMetadata(user.address, 2, metadata);

      expect(await nft.ownerOf(0)).to.equal(user.address);
      expect(await nft.ownerOf(1)).to.equal(user.address);
      expect(await nft.tokenURI(0)).to.equal(metadata);
      expect(await nft.tokenURI(1)).to.equal(metadata);
    });

    it('Should revert if mintWithSameMetadata is called by a non-whitelisted contract', async function () {
      const metadata = JSON.stringify({ id: 1, name: 'NFT' });
      await expect(
          nft.connect(user).mintWithSameMetadata(user.address, 2, metadata)
      ).to.be.revertedWithCustomError(nft, 'NotWhitelisted');
    });
  });

  describe('updateMetadata', function () {
    it('Should update metadata with a valid backend signature', async function () {
      const timestamp = new Date().getTime();
      const initialMetadata = JSON.stringify({ id: 1, name: 'NFT 1' });
      await nft.connect(whitelistedContract).mint(user.address, 1, [initialMetadata]);

      const tokenId = 0;
      const newMetadata = JSON.stringify({ id: 1, name: 'Updated NFT' });

      const messageHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'string', 'uint256', 'string', 'uint256', 'uint256'],
              [await nft.getAddress(), 'updateMetadata', tokenId, newMetadata, timestamp, chainId]
          )
      );
      const signature = await backendSigner.signMessage(ethers.getBytes(messageHash));

      await nft.connect(user).updateMetadata(tokenId, newMetadata, timestamp, signature);
      expect(await nft.tokenURI(tokenId)).to.equal(newMetadata);
    });

    it('Should revert if signature is invalid', async function () {
      const timestamp = new Date().getTime();
      const initialMetadata = JSON.stringify({ id: 1, name: 'NFT 1' });
      await nft.connect(whitelistedContract).mint(user.address, 1, [initialMetadata]);

      const tokenId = 0;
      const newMetadata = JSON.stringify({ id: 1, name: 'Updated NFT' });
      const invalidSignature = await user.signMessage("Invalid");

      await expect(
          nft.connect(user).updateMetadata(tokenId, newMetadata, timestamp, invalidSignature)
      ).to.be.revertedWithCustomError(nft, 'InvalidSigner');
    });

    it('Should revert if the same signature is used twice (replay protection)', async function () {
      const timestamp = new Date().getTime();
      const initialMetadata = JSON.stringify({ id: 1, name: 'NFT 1' });
      await nft.connect(whitelistedContract).mint(user.address, 1, [initialMetadata]);

      const tokenId = 0;
      const newMetadata = JSON.stringify({ id: 1, name: 'Updated NFT' });
      const messageHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'string', 'uint256', 'string', 'uint256', 'uint256'],
              [await nft.getAddress(), 'updateMetadata', tokenId, newMetadata, timestamp, chainId]
          )
      );
      const signature = await backendSigner.signMessage(ethers.getBytes(messageHash));

      await nft.connect(user).updateMetadata(tokenId, newMetadata, timestamp, signature);
      await expect(
          nft.connect(user).updateMetadata(tokenId, newMetadata, timestamp, signature)
      ).to.be.revertedWithCustomError(nft, 'InvalidMessageHash');
    });
  });

  describe('tokenURI', function () {
    it('Should return the correct metadata for a minted token', async function () {
      const metadata = JSON.stringify({ id: 1, name: 'Custom NFT' });
      await nft.connect(whitelistedContract).mint(user.address, 1, [metadata]);
      expect(await nft.tokenURI(0)).to.equal(metadata);
    });
  });

  describe('contractURI', function () {
    it('Should return the correct metadata for a minted token', async function () {
      expect(await nft.contractURI()).to.equal(CONTRACT_URI);
    });
  });

  describe('isContractWhitelisted', function () {
    it('Should return true for whitelisted contracts', async function () {
      expect(await nft.isContractWhitelisted(whitelistedContract.address)).to.be.true;
    });

    it('Should return false for non-whitelisted contracts', async function () {
      expect(await nft.isContractWhitelisted(user.address)).to.be.false;
    });
  });

  describe('Royalty System', function () {
    it('Should return correct initial royalty info', async function () {
      const [receiver, royaltyAmount] = await nft.royaltyInfo(1, SALE_PRICE);
      expect(receiver).to.equal(owner.address);
      expect(royaltyAmount).to.equal((SALE_PRICE * BigInt(ROYALTY_BASIS_POINTS)) / BigInt(10000));
    });

    it('Should allow owner to update royalty info', async function () {
      const newReceiver = user.address;
      const newBasisPoints = 750; // 7.5%
      await expect(nft.connect(owner).setRoyaltyInfo(newReceiver, newBasisPoints))
          .to.emit(nft, 'RoyaltyInfoUpdated')
          .withArgs(newReceiver, newBasisPoints);
      const [receiver, royaltyAmount] = await nft.royaltyInfo(1, SALE_PRICE);
      expect(receiver).to.equal(newReceiver);
      expect(royaltyAmount).to.equal((SALE_PRICE * BigInt(newBasisPoints)) / BigInt(10000));
    });

    it('Should revert if non-owner tries to update royalty info', async function () {
      await expect(
          nft.connect(user).setRoyaltyInfo(user.address, 800)
      ).to.be.revertedWithCustomError(nft, 'OwnableUnauthorizedAccount');
    });

    it('Should revert when setting royalty receiver to zero address', async function () {
      await expect(
          nft.setRoyaltyInfo(ethers.ZeroAddress, 500)
      ).to.be.revertedWithCustomError(nft, 'InvalidAddress');
    });

    it('Should revert when setting royalty basis points above 10000', async function () {
      await expect(
          nft.setRoyaltyInfo(user.address, 10001)
      ).to.be.revertedWithCustomError(nft, 'InvalidRoyaltyBasisPoints');
    });
  });

  describe('Interface Support', function () {
    it('Should support ERC165 interface', async function () {
      expect(await nft.supportsInterface("0x01ffc9a7")).to.be.true; // ERC165
    });

    it('Should support ERC721 interface', async function () {
      expect(await nft.supportsInterface("0x80ac58cd")).to.be.true; // ERC721
    });

    it('Should support ERC721 Metadata interface', async function () {
      expect(await nft.supportsInterface("0x5b5e139f")).to.be.true; // ERC721 Metadata
    });

    it('Should support EIP-2981 Royalty interface', async function () {
      expect(await nft.supportsInterface("0x2a55205a")).to.be.true; // EIP-2981
    });

    it('Should support ERC-4906 Metadata interface', async function () {
      expect(await nft.supportsInterface("0x49064906")).to.be.true; // ERC-4906
    });

    it('Should not support a random interface', async function () {
      expect(await nft.supportsInterface("0x12345678")).to.be.false;
    });
  });

  describe('Transfer Lock Mechanism', function () {
    it('Should have transfers locked by default', async function () {
      expect(await nft.transferLocked()).to.be.true;
    });

    it('Should allow the owner to unlock transfers', async function () {
      await expect(nft.connect(owner).unlockTransfers())
          .to.emit(nft, 'TransfersUnlocked');

      expect(await nft.transferLocked()).to.be.false;
    });

    it('Should revert if non-owner tries to unlock transfers', async function () {
      await expect(nft.connect(user).unlockTransfers())
          .to.be.revertedWithCustomError(nft, 'OwnableUnauthorizedAccount');
    });

    it('Should prevent transfers when locked', async function () {
      const metadata = JSON.stringify({ id: 1, name: 'NFT' });
      await nft.connect(whitelistedContract).mintWithSameMetadata(user.address, 1, metadata);

      await expect(
          nft.connect(user).transferFrom(user.address, owner.address, 0)
      ).to.be.revertedWithCustomError(nft, 'TransfersAreLocked');
    });

    it('Should allow transfers after unlocking', async function () {
      const metadata = JSON.stringify({ id: 1, name: 'NFT' });
      await nft.connect(whitelistedContract).mintWithSameMetadata(user.address, 1, metadata);

      await nft.connect(owner).unlockTransfers();

      await nft.connect(user).transferFrom(user.address, owner.address, 0);
      expect(await nft.ownerOf(0)).to.equal(owner.address);
    });
  });
});