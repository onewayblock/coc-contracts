import { expect } from 'chai';
import { ethers } from 'hardhat';
import {ReferralShare, Token, Verification} from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('ReferralShare Contract', () => {
  let referralShare: ReferralShare;
  let verification: Verification;
  let token: Token;
  let owner: SignerWithAddress, user: SignerWithAddress, newSigner: SignerWithAddress, whitelistedContract: SignerWithAddress, backendSigner: SignerWithAddress;

  const chainId = 31337;
  const referralCode = 'REF123';

  beforeEach(async () => {
    [owner, user, newSigner, whitelistedContract, backendSigner] = await ethers.getSigners();

    const Verif = await ethers.getContractFactory('Verification');
    verification = await Verif.deploy();
    await verification.waitForDeployment();
    await verification.initialize(backendSigner.address, [owner.address], owner.address);

    const TokenFactory = await ethers.getContractFactory('Token');
    token = await TokenFactory.deploy('Token', 'TKN');
    await token.waitForDeployment();

    await token.mint(owner.address, ethers.parseEther('1000'));

    const ReferralShareFactory = await ethers.getContractFactory('ReferralShare');
    referralShare = await ReferralShareFactory.deploy();
    await referralShare.waitForDeployment();
    await referralShare.initialize(verification.getAddress(), [token.target], [whitelistedContract.address], owner.address);
  });

  describe('recordDeposit', () => {
    it('Should allow a whitelisted contract to record a deposit for a token', async () => {
      const tokenAddress = ethers.Wallet.createRandom().address;
      await referralShare.connect(owner).addSupportedToken(tokenAddress);

      const amount = ethers.parseEther('100');
      await expect(referralShare.connect(whitelistedContract).recordDeposit(referralCode, tokenAddress, amount))
        .to.emit(referralShare, 'DepositRecorded')
        .withArgs(referralCode, tokenAddress, amount);

      const balance = await referralShare.getReferralBalance(referralCode, tokenAddress);
      expect(balance).to.equal(amount);
    });

    it('Should revert if called by a non-whitelisted contract', async () => {
      const tokenAddress = ethers.Wallet.createRandom().address;
      await referralShare.connect(owner).addSupportedToken(tokenAddress);

      const amount = ethers.parseEther('100');
      await expect(referralShare.connect(user).recordDeposit(referralCode, tokenAddress, amount)).to.be.revertedWithCustomError(
        referralShare,
        'NotWhitelisted'
      );
    });

    it('Should revert if token is not supported', async () => {
      const tokenAddress = ethers.Wallet.createRandom().address;
      const amount = ethers.parseEther('100');
      await expect(referralShare.connect(whitelistedContract).recordDeposit(referralCode, tokenAddress, amount)).to.be.revertedWithCustomError(
        referralShare,
        'UnsupportedToken'
      );
    });
  });

  describe('withdrawBalances', () => {
    it('Should allow a user to withdraw all balances with a valid signature', async () => {
      const amount = ethers.parseEther('1');
      const timestamp = Date.now();
      const signature = await getSignature(
          await referralShare.getAddress(),
          'withdrawBalances',
          user.address,
          referralCode,
          timestamp,
          backendSigner
      );

      await user.sendTransaction({
        to: referralShare.target,
        value: amount,
      });

      await token.connect(owner).transfer(referralShare.target, amount);

      await referralShare.connect(whitelistedContract).recordDeposit(referralCode, ethers.ZeroAddress, amount);

      await referralShare.connect(whitelistedContract).recordDeposit(referralCode, token.target, amount);

      await expect(referralShare.connect(user).withdrawBalances(referralCode, timestamp, signature))
        .to.emit(referralShare, 'WithdrawalRecorded')
        .withArgs(referralCode, ethers.ZeroAddress, amount)
        .and.to.emit(referralShare, 'WithdrawalRecorded')
        .withArgs(referralCode, token.target, amount);
    });

    it('Should revert if signature is invalid', async () => {
      const amount = ethers.parseEther('1');
      const timestamp = Date.now();
      const invalidSignature = await getSignature(
          await referralShare.getAddress(),
          'withdrawBalances',
          user.address,
          referralCode,
          timestamp,
          newSigner);

      await referralShare.connect(whitelistedContract).recordDeposit(referralCode, ethers.ZeroAddress, amount);

      await expect(referralShare.connect(user).withdrawBalances(referralCode, timestamp, invalidSignature)).to.be.revertedWithCustomError(verification, 'InvalidSigner');
    });
  });

  describe('Token Management', () => {
    it('Should allow owner to add a supported token', async () => {
      const tokenAddress = ethers.Wallet.createRandom().address;

      await expect(referralShare.connect(owner).addSupportedToken(tokenAddress)).to.emit(referralShare, 'TokenAdded').withArgs(tokenAddress);

      expect(await referralShare.getSupportedTokens()).to.include(tokenAddress);
    });

    it('Should revert if token is already supported', async () => {
      const tokenAddress = ethers.Wallet.createRandom().address;

      await referralShare.connect(owner).addSupportedToken(tokenAddress);
      await expect(referralShare.connect(owner).addSupportedToken(tokenAddress)).to.be.revertedWithCustomError(referralShare, 'AlreadySupportedToken');
    });
  });

  describe('Whitelist Management', () => {
    it('Should allow owner to add a whitelisted contract', async () => {
      const contractAddress = ethers.Wallet.createRandom().address;

      await expect(referralShare.connect(owner).addWhitelistedContract(contractAddress))
        .to.emit(referralShare, 'ContractWhitelisted')
        .withArgs(contractAddress);

      await referralShare.connect(owner).removeWhitelistedContract(contractAddress);
    });

    it('Should revert if trying to whitelist an already whitelisted contract', async () => {
      const contractAddress = ethers.Wallet.createRandom().address;

      await referralShare.connect(owner).addWhitelistedContract(contractAddress);
      await expect(referralShare.connect(owner).addWhitelistedContract(contractAddress)).to.be.revertedWithCustomError(referralShare, 'AlreadyWhitelisted');
    });
  });

  const getSignature = async (
      contractAddress: string,
      methodName: string,
      userAddress: string,
      value: any,
      timestamp: number,
      signer: SignerWithAddress
  ) => {
    const messageHash = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
            ['address', 'string', 'address', typeof value === 'boolean' ? 'bool' : typeof value === 'string' ? 'string' : 'uint256', 'uint256', 'uint256'],
            [contractAddress, methodName, userAddress, value, timestamp, chainId]
        )
    );
    return await signer.signMessage(ethers.getBytes(messageHash));
  };
});
