import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import {
  HardCurrencyShop,
  TestToken,
  DummyUniswapHelper,
  DummyVerification,
} from '../typechain-types';

describe('HardCurrencyShop Contract', function () {
  let shop: HardCurrencyShop;
  let testToken: TestToken;
  let dummyUniswapHelper: DummyUniswapHelper;
  let dummyVerification: DummyVerification;
  let owner: SignerWithAddress, user: SignerWithAddress, other: SignerWithAddress;
  const zeroAddress = ethers.ZeroAddress;

  beforeEach(async function () {
    [owner, user, other] = await ethers.getSigners();

    const TestTokenFactory = await ethers.getContractFactory('TestToken');
    testToken = await TestTokenFactory.deploy("TestToken", "TTK", 18, ethers.parseUnits("1000000", 18));
    await testToken.waitForDeployment();

    const DummyUniswapHelperFactory = await ethers.getContractFactory('DummyUniswapHelper');
    dummyUniswapHelper = await DummyUniswapHelperFactory.deploy(await testToken.getAddress());
    await dummyUniswapHelper.waitForDeployment();

    const DummyVerificationFactory = await ethers.getContractFactory('DummyVerification');
    dummyVerification = await DummyVerificationFactory.deploy();
    await dummyVerification.waitForDeployment();

    const HardCurrencyShopFactory = await ethers.getContractFactory('HardCurrencyShop');
    shop = await HardCurrencyShopFactory.deploy();
    await shop.waitForDeployment();

    await shop.initialize(
        await dummyVerification.getAddress(),
        await dummyUniswapHelper.getAddress(),
        [await testToken.getAddress(), zeroAddress]
    );
  });

  describe('Deployment and Initialization', function () {
    it('Should initialize supported payment tokens', async function () {
      const tokens = await shop.getSupportedTokens();
      expect(tokens).to.include(await testToken.getAddress());
      expect(tokens).to.include(zeroAddress);
    });
    it('Should revert initialization if any critical address is zero', async function () {
      const HardCurrencyShopFactory = await ethers.getContractFactory('HardCurrencyShop');
      const shop2 = await HardCurrencyShopFactory.deploy();
      await shop2.waitForDeployment();
      await expect(
          shop2.initialize(
              await dummyVerification.getAddress(),
              ethers.ZeroAddress,
              [await testToken.getAddress()]
          )
      ).to.be.revertedWithCustomError(shop2, 'InvalidAddress');
    });
  });

  describe('Payment Token Management', function () {
    it('Should allow the owner to add a new payment token', async function () {
      await expect(shop.connect(owner).addPaymentToken(other.address))
          .to.emit(shop, 'PaymentTokenAdded')
          .withArgs(other.address);
      const tokens = await shop.getSupportedTokens();
      expect(tokens).to.include(other.address);
    });
    it('Should revert when adding an already supported token', async function () {
      await expect(shop.connect(owner).addPaymentToken(await testToken.getAddress()))
          .to.be.revertedWithCustomError(shop, 'TokenAlreadySupported');
    });
    it('Should allow the owner to remove a payment token', async function () {
      await expect(shop.connect(owner).removePaymentToken(await testToken.getAddress()))
          .to.emit(shop, 'PaymentTokenRemoved')
          .withArgs(await testToken.getAddress());
      const tokens = await shop.getSupportedTokens();
      expect(tokens).to.not.include(await testToken.getAddress());
    });
    it('Should revert when removing a non-supported token', async function () {
      await expect(shop.connect(owner).removePaymentToken(other.address))
          .to.be.revertedWithCustomError(shop, 'TokenNotSupported');
    });
  });

  describe('Settings Updates', function () {
    it('Should update verification contract address', async function () {
      await expect(shop.connect(owner).updateVerificationContractAddress(other.address))
          .to.emit(shop, 'VerificationAddressUpdated')
          .withArgs(other.address);
    });
    it('Should revert when updating verification contract address to zero', async function () {
      await expect(shop.connect(owner).updateVerificationContractAddress(zeroAddress))
          .to.be.revertedWithCustomError(shop, 'InvalidAddress');
    });
  });

  describe('Purchase Function', function () {
    it('Should revert purchase if payment token is not supported', async function () {
      await expect(shop.connect(user).purchase(
          1000,
          other.address,
          1000,
          300,
          { value: 1000 }
      )).to.be.revertedWithCustomError(shop, 'TokenNotSupported');
    });

    it('Should revert purchase if insufficient ETH is sent when paying with ETH', async function () {
      await expect(shop.connect(user).purchase(
          1000,
          zeroAddress,
          1000,
          300,
          { value: 100 }
      )).to.be.revertedWithCustomError(shop, 'InsufflientETHSent');
    });

    it('Should handle ETH purchase correctly with excess refund', async function () {
      const USDAmount = 1000000000000000;
      const excess = 500;
      const balanceBefore = await ethers.provider.getBalance(user.address);
      const tx = await shop.connect(user).purchase(
          USDAmount,
          zeroAddress,
          100000,
          300,
          { value: USDAmount + excess }
      );
      const receipt = await tx.wait();
      const gasUsed = BigInt(receipt?.gasUsed || 0) * BigInt(receipt?.gasPrice || 0);
      const balanceAfter = await ethers.provider.getBalance(user.address);

      expect(balanceBefore - balanceAfter - gasUsed)
          .to.be.closeTo(USDAmount, 10);
      await expect(tx).to.emit(shop, 'HardCurrencyBought')
          .withArgs(user.address, USDAmount, zeroAddress, USDAmount);
    });

    it('Should handle ERC20 purchase correctly', async function () {
      const USDAmount = 1000;
      await testToken.transfer(user.address, USDAmount);
      await testToken.connect(user).approve(await shop.getAddress(), USDAmount);
      const tx = await shop.connect(user).purchase(
          USDAmount,
          await testToken.getAddress(),
          1000,
          300,
      );
      await expect(tx).to.emit(shop, 'HardCurrencyBought')
          .withArgs(user.address, USDAmount, await testToken.getAddress(), USDAmount);
    });
  });
});