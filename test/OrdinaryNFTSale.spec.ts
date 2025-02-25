import { expect } from 'chai';
import {ethers, upgrades} from 'hardhat';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

import { NFTSale, NFT } from '../typechain-types';
import { TestToken } from '../typechain-types';
import { DummyUniswapHelper } from '../typechain-types';
import { DummyVerification } from '../typechain-types';

describe('NFTSale Contract', function () {
  let nftSale: NFTSale;
  let nft: NFT;
  let testToken: TestToken;
  let dummyUniswapHelper: DummyUniswapHelper;
  let dummyVerification: DummyVerification;

  let owner: SignerWithAddress, user: SignerWithAddress, other: SignerWithAddress;
  const zeroAddress = ethers.ZeroAddress;
  const CONTRACT_URI = '{"name":"OpenSea Creatures","description":"OpenSea Creatures are adorable aquatic beings primarily for demonstrating what can be done using the OpenSea platform. Adopt one today to try out all the OpenSea buying, selling, and bidding feature set.","image":"https://external-link-url.com/image.png","banner_image":"https://external-link-url.com/banner-image.png","featured_image":"https://external-link-url.com/featured-image.png","external_link":"https://external-link-url.com","collaborators":["0x0000000000000000000000000000000000000000"]}';

  beforeEach(async function () {
    [owner, user, other] = await ethers.getSigners();

    const TestTokenFactory = await ethers.getContractFactory('TestToken');
    testToken = await TestTokenFactory.deploy("TestToken", "TTK", 18, ethers.parseUnits("1000000", 18));
    await testToken.waitForDeployment();

    const NFTFactory = await ethers.getContractFactory('NFT');
    nft = await NFTFactory.deploy(
        "TestNFT",
        "TNFT",
        CONTRACT_URI,
        owner.address,
        [owner.address],
        owner.address,
        owner.address,
        500
    );
    await nft.waitForDeployment();

    const DummyUniswapHelperFactory = await ethers.getContractFactory('DummyUniswapHelper');
    dummyUniswapHelper = await DummyUniswapHelperFactory.deploy(await testToken.getAddress());
    await dummyUniswapHelper.waitForDeployment();

    const DummyVerificationFactory = await ethers.getContractFactory('DummyVerification');
    dummyVerification = await DummyVerificationFactory.deploy();
    await dummyVerification.waitForDeployment();

    const NFTSaleFactory = await ethers.getContractFactory('OrdinaryNFTSale');
    nftSale = await upgrades.deployProxy(
        NFTSaleFactory,
        [
          await dummyVerification.getAddress(),
          await dummyUniswapHelper.getAddress(),
          owner.address,
          [await testToken.getAddress(), zeroAddress]
        ],
        { initializer: "initialize" }
    );

    await nft.addWhitelistedContract(await nftSale.getAddress())
  });

  describe('Deployment and Initialization', function () {
    it('Should initialize supported payment tokens', async function () {
      const tokens = await nftSale.getSupportedTokens();
      expect(tokens).to.include(await testToken.getAddress());
      expect(tokens).to.include(zeroAddress);
    });
  });

  describe('Payment Token Management', function () {
    it('Should allow the owner to add a new payment token', async function () {
      const newToken = other.address;
      await expect(nftSale.connect(owner).addPaymentToken(newToken))
          .to.emit(nftSale, 'PaymentTokenAdded')
          .withArgs(newToken);
      const tokens = await nftSale.getSupportedTokens();
      expect(tokens).to.include(newToken);
    });

    it('Should revert when adding an already supported token', async function () {
      await expect(nftSale.connect(owner).addPaymentToken(await testToken.getAddress()))
          .to.be.revertedWithCustomError(nftSale, 'TokenAlreadySupported');
    });

    it('Should allow the owner to remove a payment token', async function () {
      await expect(nftSale.connect(owner).removePaymentToken(await testToken.getAddress()))
          .to.emit(nftSale, 'PaymentTokenRemoved')
          .withArgs(await testToken.getAddress());
      const tokens = await nftSale.getSupportedTokens();
      expect(tokens).to.not.include(await testToken.getAddress());
    });

    it('Should revert when removing a non-supported token', async function () {
      await expect(nftSale.connect(owner).removePaymentToken(other.address))
          .to.be.revertedWithCustomError(nftSale, 'TokenNotSupported');
    });
  });

  describe('Settings Updates', function () {
    it('Should update verification contract address', async function () {
      await expect(nftSale.connect(owner).updateVerificationContractAddress(other.address))
          .to.emit(nftSale, 'VerificationAddressUpdated')
          .withArgs(other.address);
    });
    it('Should revert when updating verification contract address to zero', async function () {
      await expect(nftSale.connect(owner).updateVerificationContractAddress(zeroAddress))
          .to.be.revertedWithCustomError(nftSale, 'InvalidAddress');
    });
  });

  describe('NFT Sale Management', function () {
    const nftTokenMetadata = "Test NFT Metadata";
    const saleQuantity = 10;
    const USDPrice = ethers.parseUnits('1', 6);
    const totalLimit = 20;
    const oneTimeLimit = 5;

    beforeEach(async function () {
      await expect(nftSale.connect(owner).listNFTForSale(
          await nft.getAddress(),
          nftTokenMetadata,
          saleQuantity,
          true,
          USDPrice,
          totalLimit,
          oneTimeLimit
      ))
          .to.emit(nftSale, 'NFTListedForSale')
          .withArgs(1, await nft.getAddress(), nftTokenMetadata, saleQuantity, true, USDPrice, totalLimit, oneTimeLimit);
    });

    it('Should list an NFT for sale correctly', async function () {
      const sale = await nftSale.getNFTSaleDetails(1);
      expect(sale.NFTContract).to.equal(await nft.getAddress());
      expect(sale.tokenMetadata).to.equal(nftTokenMetadata);
      expect(sale.quantity).to.equal(saleQuantity);
      expect(sale.isActive).to.be.true;
      expect(sale.USDPrice).to.equal(USDPrice);
      expect(sale.totalLimitPerUser).to.equal(totalLimit);
      expect(sale.onetimeLimitPerUser).to.equal(oneTimeLimit);
    });

    it('Should revert listing sale with invalid parameters', async function () {
      await expect(nftSale.connect(owner).listNFTForSale(
          zeroAddress,
          nftTokenMetadata,
          saleQuantity,
          true,
          USDPrice,
          totalLimit,
          oneTimeLimit
      )).to.be.revertedWithCustomError(nftSale, 'InvalidAddress');

      await expect(nftSale.connect(owner).listNFTForSale(
          await nft.getAddress(),
          nftTokenMetadata,
          0,
          true,
          USDPrice,
          totalLimit,
          oneTimeLimit
      )).to.be.revertedWithCustomError(nftSale, 'InvalidQuantity');

      await expect(nftSale.connect(owner).listNFTForSale(
          await nft.getAddress(),
          nftTokenMetadata,
          saleQuantity,
          true,
          0,
          totalLimit,
          oneTimeLimit
      )).to.be.revertedWithCustomError(nftSale, 'InvalidPrice');

      await expect(nftSale.connect(owner).listNFTForSale(
          await nft.getAddress(),
          nftTokenMetadata,
          saleQuantity,
          true,
          USDPrice,
          5,
          6
      )).to.be.revertedWithCustomError(nftSale, 'InvalidQuantity');
    });

    it('Should stop an active sale', async function () {
      await expect(nftSale.connect(owner).stopNFTSale(1))
          .to.emit(nftSale, 'NFTSaleStopped')
          .withArgs(1);
      const sale = await nftSale.getNFTSaleDetails(1);
      expect(sale.isActive).to.be.false;
    });

    it('Should revert stopping a non-existent sale', async function () {
      await expect(nftSale.connect(owner).stopNFTSale(2))
          .to.be.revertedWithCustomError(nftSale, 'SaleDoesNotExist');
    });

    it('Should revert stopping an already stopped sale', async function () {
      await nftSale.connect(owner).stopNFTSale(1);
      await expect(nftSale.connect(owner).stopNFTSale(1))
          .to.be.revertedWithCustomError(nftSale, 'SaleAlreadyStopped');
    });

    it('Should renew a stopped sale', async function () {
      await nftSale.connect(owner).stopNFTSale(1);
      await expect(nftSale.connect(owner).renewNFTSale(1))
          .to.emit(nftSale, 'NFTSaleRenewed')
          .withArgs(1);
      const sale = await nftSale.getNFTSaleDetails(1);
      expect(sale.isActive).to.be.true;
    });

    it('Should revert renewing an active sale', async function () {
      await expect(nftSale.connect(owner).renewNFTSale(1))
          .to.be.revertedWithCustomError(nftSale, 'SaleAlreadyActive');
    });

    it('Should delist a sale after NFTs are sold', async function () {
      const purchaseQuantity = 2;
      const totalUSDAmount = USDPrice * BigInt(purchaseQuantity);
      await dummyVerification.setReferrer(user.address, "");
      await expect(nftSale.connect(user).buyNFT(
          1,
          purchaseQuantity,
          zeroAddress,
          totalUSDAmount,
          300,
          { value: totalUSDAmount }
      )).to.emit(nftSale, 'NFTBought');

      await expect(nftSale.connect(owner).delistNFTFromSale(1))
          .to.be.revertedWithCustomError(nftSale, 'SaleAlreadyStarted');
    });

    it('Should revert delisting a sale with no NFTs sold', async function () {
      await expect(nftSale.connect(owner).delistNFTFromSale(1))
          .to.emit(nftSale, 'NFTDelisted')
          .withArgs(1);

      await expect(nftSale.getNFTSaleDetails(1))
          .to.be.revertedWithCustomError(nftSale, 'SaleDoesNotExist');
    });
  });

  describe('mintNFTs Function', function () {
    const metadata = "Minted NFT Metadata";
    const mintQuantity = 3;

    it('Should mint NFTs with valid parameters and signature', async function () {
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const messageHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(
              ["address", "string", "address", "address", "uint256", "string", "uint256"],
              [await nftSale.getAddress(), "mintNFTs", await nft.getAddress(), user.address, mintQuantity, metadata, chainId]
          )
      );
      const signature = await owner.signMessage(ethers.getBytes(messageHash));

      await expect(nftSale.connect(user).mintNFTs(
          await nft.getAddress(),
          user.address,
          mintQuantity,
          metadata,
          signature
      )).to.emit(nftSale, 'NFTsMinted')
          .withArgs(await nft.getAddress(), user.address, mintQuantity, metadata);
    });

    it('Should revert minting NFTs if _nftContract or _to is zero address', async function () {
      const signature = "0x";
      await expect(nftSale.connect(user).mintNFTs(
          zeroAddress,
          user.address,
          mintQuantity,
          metadata,
          signature
      )).to.be.revertedWithCustomError(nftSale, 'InvalidAddress');

      await expect(nftSale.connect(user).mintNFTs(
          await nft.getAddress(),
          zeroAddress,
          mintQuantity,
          metadata,
          signature
      )).to.be.revertedWithCustomError(nftSale, 'InvalidAddress');
    });

    it('Should revert minting NFTs if quantity is zero', async function () {
      const signature = "0x";
      await expect(nftSale.connect(user).mintNFTs(
          await nft.getAddress(),
          user.address,
          0,
          metadata,
          signature
      )).to.be.revertedWithCustomError(nftSale, 'InvalidQuantity');
    });
  });

  describe('buyNFT Function', function () {
    const nftTokenMetadata = "Buy NFT Metadata";
    const quantity = 5;
    const USDPrice = ethers.parseUnits('2', 6);
    const totalLimit = 10;
    const oneTimeLimit = 5;

    beforeEach(async function () {
      await nftSale.connect(owner).listNFTForSale(
         await  nft.getAddress(),
          nftTokenMetadata,
          20,
          true,
          USDPrice,
          totalLimit,
          oneTimeLimit
      );
    });

    it('Should allow buying NFT with ETH when payment token is zero address', async function () {
      const purchaseQuantity = 2;
      const totalUSDAmount = USDPrice * BigInt(purchaseQuantity);
      await dummyVerification.setReferrer(user.address, "");
      await expect(nftSale.connect(user).buyNFT(
          1,
          purchaseQuantity,
          zeroAddress,
          totalUSDAmount,
          300,
          { value: totalUSDAmount }
      )).to.emit(nftSale, 'NFTBought');
      const sale = await nftSale.getNFTSaleDetails(1);
      expect(sale.soldQuantity).to.equal(purchaseQuantity);
      const bought = await nftSale.usersBoughtQuantity(user.address, 1);
      expect(bought).to.equal(purchaseQuantity);
    });

    it('Should refund excess ETH sent in a purchase', async function () {
      const purchaseQuantity = 1;
      const totalUSDAmount = USDPrice * BigInt(purchaseQuantity);
      const excess = ethers.parseEther("1");
      const balanceBefore = await ethers.provider.getBalance(user.address);
      const tx = await nftSale.connect(user).buyNFT(
          1,
          purchaseQuantity,
          zeroAddress,
          USDPrice * BigInt(purchaseQuantity),
          300,
          { value: totalUSDAmount + BigInt(excess) }
      );
      const receipt = await tx.wait();
      const gasUsed = BigInt(receipt?.gasUsed || 0) * BigInt(receipt?.gasPrice || 0);
      const balanceAfter = await ethers.provider.getBalance(user.address);
      expect(balanceBefore - balanceAfter - gasUsed)
          .to.be.closeTo(totalUSDAmount, 10);
    });

    it('Should allow buying NFT with ERC20 payment', async function () {
      const purchaseQuantity = 3;
      const totalUSDAmount = USDPrice * BigInt(purchaseQuantity);
      await dummyVerification.setReferrer(user.address, "");
      await testToken.connect(owner).mint(user.address, ethers.parseEther("10000"));
      await testToken.connect(user).approve(await nftSale.getAddress(), totalUSDAmount);
      await expect(nftSale.connect(user).buyNFT(
          1,
          purchaseQuantity,
          await testToken.getAddress(),
          totalUSDAmount,
          300,
      )).to.emit(nftSale, 'NFTBought');
      const sale = await nftSale.getNFTSaleDetails(1);
      expect(sale.soldQuantity).to.equal(purchaseQuantity);
    });

    it('Should revert buying NFT from non-existent sale', async function () {
      await expect(nftSale.connect(user).buyNFT(
          999,
          1,
          zeroAddress,
          999,
          300,
          { value: USDPrice }
      )).to.be.revertedWithCustomError(nftSale, 'SaleDoesNotExist');
    });

    it('Should revert buying NFT from inactive sale', async function () {
      await nftSale.connect(owner).stopNFTSale(1);
      await expect(nftSale.connect(user).buyNFT(
          1,
          1,
          zeroAddress,
          1,
          300,
          { value: USDPrice }
      )).to.be.revertedWithCustomError(nftSale, 'SaleAlreadyStopped');
    });

    it('Should revert buying NFT with invalid quantity', async function () {
      await expect(nftSale.connect(user).buyNFT(
          1,
          0,
          zeroAddress,
          1,
          300,
          { value: 0 }
      )).to.be.revertedWithCustomError(nftSale, 'InvalidQuantity');
    });

    it('Should revert buying NFT with unsupported payment token', async function () {
      await expect(nftSale.connect(user).buyNFT(
          1,
          1,
          other.address,
          100,
          300,
          { value: USDPrice }
      )).to.be.revertedWithCustomError(nftSale, 'TokenNotSupported');
    });
  });
});