import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Verification } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('Verification Contract', () => {
  let verification: Verification;
  let owner: SignerWithAddress, user: SignerWithAddress, backendSigner: SignerWithAddress, newSigner: SignerWithAddress;
  const chainId = 31337;
  const USDC_MULTIPLIER = 10 ** 6;

  beforeEach(async () => {
    [owner, user, backendSigner, newSigner] = await ethers.getSigners();

    const Verif = await ethers.getContractFactory('Verification');
    verification = await Verif.deploy();
    await verification.waitForDeployment();
    await verification.initialize(backendSigner.address, [owner.address], owner.address);
  });

  describe('Deployment', () => {
    it('Should set the correct backend signer', async () => {
      expect(await verification.backendSigner()).to.equal(backendSigner.address);
    });

    it('Should revert when deployed with zero backend signer address', async () => {
      const Verif = await ethers.getContractFactory('Verification');
      await expect((await Verif.deploy()).initialize(ethers.ZeroAddress, [owner.address], owner.address)).to.be.revertedWithCustomError(verification, 'InvalidAddress');
    });
  });

  describe('Set KYC and AML', () => {
    it('Should allow a user to set base KYC with a valid signature', async () => {
      const baseKyc = true;

      const signature = await getSignature(await verification.getAddress(), 'setBaseKyc', user.address, baseKyc, backendSigner);

      await expect(verification.connect(user).setBaseKyc(user.address, baseKyc, signature)).to.emit(verification, 'BaseKycUpdated').withArgs(user.address, baseKyc);

      const verificationStatus = await verification.getVerification(user.address);
      expect(verificationStatus.baseKyc).to.equal(baseKyc);
    });

    it('Should not allow a user to overwrite base KYC', async () => {
      const baseKyc = true;

      const signature = await getSignature(await verification.getAddress(), 'setBaseKyc', user.address, baseKyc, backendSigner);

      await verification.connect(user).setBaseKyc(user.address, baseKyc, signature);

      await expect(verification.connect(user).setBaseKyc(user.address, baseKyc, signature)).to.be.revertedWithCustomError(verification, 'DataAlreadySet');
    });

    it('Should allow a user to set advanced AML score with a valid signature', async () => {
      const advancedAMLScore = 85;

      const signature = await getSignature(await verification.getAddress(), 'setAdvancedAMLScore', user.address, advancedAMLScore, backendSigner);

      await expect(verification.connect(user).setAdvancedAMLScore(user.address, advancedAMLScore, signature))
        .to.emit(verification, 'AdvancedAMLScoreUpdated')
        .withArgs(user.address, advancedAMLScore);

      const verificationStatus = await verification.getVerification(user.address);
      expect(verificationStatus.advancedAMLScore).to.equal(advancedAMLScore);
    });
  });

  describe('Backend Signer Management', () => {
    it('Should allow the owner to set a new backend signer', async () => {
      await expect(verification.connect(owner).setBackendSigner(newSigner.address)).to.emit(verification, 'BackendSignerChanged').withArgs(newSigner.address);

      expect(await verification.backendSigner()).to.equal(newSigner.address);
    });

    it('Should not allow a non-owner to set a new backend signer', async () => {
      await expect(verification.connect(user).setBackendSigner(newSigner.address))
        .to.be.revertedWithCustomError(verification, 'OwnableUnauthorizedAccount')
        .withArgs(user.address);
    });

    it('Should allow valid signatures from the new backend signer', async () => {
      await verification.connect(owner).setBackendSigner(newSigner.address);

      const baseKyc = true;

      const signature = await getSignature(await verification.getAddress(), 'setBaseKyc', user.address, baseKyc, newSigner);

      await expect(verification.connect(user).setBaseKyc(user.address, baseKyc, signature)).to.emit(verification, 'BaseKycUpdated').withArgs(user.address, baseKyc);
    });
  });

  describe('Allowed Contracts Management', () => {
    it('Should allow the owner to add an allowed contract', async () => {
      await verification.connect(owner).addAllowedContract(newSigner.address);
      await expect(verification.connect(newSigner).recordSpending(user.address, 1000)).to.emit(verification, 'SpendingRecorded').withArgs(user.address, 1000, newSigner.address);
    });

    it('Should not allow non-owner to add an allowed contract', async () => {
      await expect(verification.connect(user).addAllowedContract(newSigner.address))
        .to.be.revertedWithCustomError(verification, 'OwnableUnauthorizedAccount')
        .withArgs(user.address);
    });

    it('Should allow the owner to remove an allowed contract', async () => {
      await verification.connect(owner).removeAllowedContract(owner.address);
      await expect(verification.connect(owner).recordSpending(user.address, 1000)).to.be.revertedWithCustomError(verification, 'NotAllowedContract');
    });

    it('Should not allow non-owner to remove an allowed contract', async () => {
      await expect(verification.connect(user).removeAllowedContract(owner.address))
        .to.be.revertedWithCustomError(verification, 'OwnableUnauthorizedAccount')
        .withArgs(user.address);
    });
  });

  describe('Update Spending and Score Limits', () => {
    it('Should allow the owner to update spending limits', async () => {
      await verification.connect(owner).updateSpendingLimits(10 * 10 ** 6, 60 * 10 ** 6, 120 * 10 ** 6, 250 * 10 ** 6);

      expect(await verification.baseAmlLimit()).to.equal(10 * 10 ** 6);
      expect(await verification.advancedAmlLimit()).to.equal(60 * 10 ** 6);
      expect(await verification.baseKycLimit()).to.equal(120 * 10 ** 6);
      expect(await verification.advancedKycLimit()).to.equal(250 * 10 ** 6);
    });

    it('Should not allow invalid spending limit configurations', async () => {
      await expect(verification.connect(owner).updateSpendingLimits(60 * 10 ** 6, 10 * 10 ** 6, 120 * 10 ** 6, 250 * 10 ** 6)).to.be.revertedWithCustomError(
          verification,
        'InvalidConfiguration'
      );
    });

    it('Should allow the owner to update AML score limits', async () => {
      await verification.connect(owner).updateAMLScoreLimits(40, 70);

      expect(await verification.baseAmlScoreLimit()).to.equal(40);
      expect(await verification.advancedAmlScoreLimit()).to.equal(70);
    });

    it('Should not allow invalid AML score configurations', async () => {
      await expect(verification.connect(owner).updateAMLScoreLimits(110, 70)).to.be.revertedWithCustomError(verification, 'InvalidConfiguration');
    });
  });

  describe('Record Spending', () => {
    it('Should record spending for a user from an allowed contract', async () => {
      const amount = 40 * USDC_MULTIPLIER; // $40 in USDC format

      await expect(verification.connect(owner).recordSpending(user.address, amount)).to.emit(verification, 'SpendingRecorded').withArgs(user.address, amount, owner.address);

      const totalSpending = await verification.getTotalSpending(user.address);
      expect(totalSpending).to.equal(amount);

      const spendingHistory = await verification.getSpendingHistory(user.address);
      expect(spendingHistory.length).to.equal(1);
      expect(spendingHistory[0].amount).to.equal(amount);
      expect(spendingHistory[0].contractAddress).to.equal(owner.address);
    });

    it('Should revert if called by a non-allowed contract', async () => {
      const amount = 40 * USDC_MULTIPLIER; // $40 in USDC format

      await expect(verification.connect(user).recordSpending(user.address, amount)).to.be.revertedWithCustomError(verification, 'NotAllowedContract');
    });
  });

  describe('validateSpending', () => {
    it('Should allow spending below base AML limit', async () => {
      const amount = 4 * USDC_MULTIPLIER; // $4 in USDC format
      await expect(verification.validateSpending(user.address, amount)).not.to.be.reverted;
    });

    it('Should revert spending at base AML limit if baseAMLScore is too high', async () => {
      const amount = 5 * USDC_MULTIPLIER; // $5 in USDC format
      await verification.connect(user).setBaseAMLScore(user.address, 60, await getSignature(await verification.getAddress(), 'setBaseAMLScore', user.address, 60, backendSigner));
      await expect(verification.validateSpending(user.address, amount)).to.be.revertedWithCustomError(verification, 'AMLKYCCheckFailed');
    });

    it('Should allow spending above base AML but below advanced AML limit with valid advancedAMLScore', async () => {
      await verification.connect(user).setAdvancedAMLScore(user.address, 20, await getSignature(await verification.getAddress(), 'setAdvancedAMLScore', user.address, 20, backendSigner));
      const amount = 40 * USDC_MULTIPLIER; // $40 in USDC format
      await expect(verification.validateSpending(user.address, amount)).not.to.be.reverted;
    });

    it('Should revert spending at advanced AML limit if advancedAMLScore is too high', async () => {
      const amount = 50 * USDC_MULTIPLIER; // $50 in USDC format
      await verification.connect(user).setAdvancedAMLScore(user.address, 60, await getSignature(await verification.getAddress(), 'setAdvancedAMLScore', user.address, 60, backendSigner));
      await expect(verification.validateSpending(user.address, amount)).to.be.revertedWithCustomError(verification, 'AMLKYCCheckFailed');
    });

    it('Should allow spending above advanced AML but below base KYC limit with valid baseKyc', async () => {
      await verification.connect(user).setBaseKyc(user.address, true, await getSignature(await verification.getAddress(), 'setBaseKyc', user.address, true, backendSigner));
      await verification.connect(user).setAdvancedAMLScore(user.address, 20, await getSignature(await verification.getAddress(), 'setAdvancedAMLScore', user.address, 20, backendSigner));
      const amount = 80 * USDC_MULTIPLIER; // $80 in USDC format
      await expect(verification.validateSpending(user.address, amount)).not.to.be.reverted;
    });

    it('Should revert spending at base KYC limit if baseKyc is false', async () => {
      const amount = 100 * USDC_MULTIPLIER; // $100 in USDC format
      await verification.connect(user).setBaseKyc(user.address, false, await getSignature(await verification.getAddress(), 'setBaseKyc', user.address, false, backendSigner));
      await expect(verification.validateSpending(user.address, amount)).to.be.revertedWithCustomError(verification, 'AMLKYCCheckFailed');
    });

    it('Should allow spending above base KYC but below advanced KYC limit with valid advancedKyc', async () => {
      await verification.connect(user).setAdvancedKyc(user.address, true, await getSignature(await verification.getAddress(), 'setAdvancedKyc', user.address, true, backendSigner));
      await verification.connect(user).setAdvancedAMLScore(user.address, 20, await getSignature(await verification.getAddress(), 'setAdvancedAMLScore', user.address, 20, backendSigner));
      const amount = 150 * USDC_MULTIPLIER; // $150 in USDC format
      await expect(verification.validateSpending(user.address, amount)).not.to.be.reverted;
    });

    it('Should revert spending at advanced KYC limit if advancedKyc is false', async () => {
      const amount = 200 * USDC_MULTIPLIER; // $200 in USDC format
      await verification.connect(user).setAdvancedKyc(user.address, false, await getSignature(await verification.getAddress(), 'setAdvancedKyc', user.address, false, backendSigner));
      await expect(verification.validateSpending(user.address, amount)).to.be.revertedWithCustomError(verification, 'AMLKYCCheckFailed');
    });

    it('Should correctly calculate 24-hour spending and revert if limit is exceeded with base KYC and advanced AML', async () => {
      // Record spending of $150 (150 * 10^6 in USDC format)
      await verification.recordSpending(user.address, 150 * USDC_MULTIPLIER);
      await verification.connect(user).setBaseKyc(user.address, true, await getSignature(await verification.getAddress(), 'setBaseKyc', user.address, true, backendSigner));
      await verification.connect(user).setAdvancedAMLScore(user.address, 20, await getSignature(await verification.getAddress(), 'setAdvancedAMLScore', user.address, 20, backendSigner));
      // Validate additional $60 spending (total $210 within 24 hours)
      await expect(verification.validateSpending(user.address, 60 * USDC_MULTIPLIER)).to.be.revertedWithCustomError(verification, 'AMLKYCCheckFailed');
    });
  });
  describe('verifySignaturePublic', () => {
    const testMessage = 'Hello, signature test!';

    let messageHash: string;
    let validSignature: string;

    beforeEach(async () => {
      messageHash = ethers.keccak256(ethers.toUtf8Bytes(testMessage));
      validSignature = await backendSigner.signMessage(
          ethers.getBytes(messageHash)
      );
    });

    it('Should verify a valid signature', async () => {
      await expect(verification.verifySignaturePublic(messageHash, validSignature))
          .not.to.be.reverted;
    });

    it('Should revert with InvalidSigner if signature is invalid', async () => {
      const invalidSignature = await newSigner.signMessage(
          ethers.getBytes(messageHash)
      );

      await expect(verification.verifySignaturePublic(messageHash, invalidSignature))
          .to.be.revertedWithCustomError(verification, 'InvalidSigner');
    });

    it('Should revert with InvalidMessageHash if called again with the same hash', async () => {
      await expect(verification.verifySignaturePublic(messageHash, validSignature))
          .not.to.be.reverted;
      await expect(verification.verifySignaturePublic(messageHash, validSignature))
          .to.be.revertedWithCustomError(verification, 'InvalidMessageHash');
    });
  });

  const getSignature = async (contractAddress: string, methodName: string, userAddress: string, value: any, signer: SignerWithAddress) => {
    const messageHash = ethers.keccak256(
      ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'string', 'address', typeof value === 'boolean' ? 'bool' : typeof value === 'string' ? 'string' : 'uint256', 'uint256'],
        [contractAddress, methodName, userAddress, value, chainId]
      )
    );
    return await signer.signMessage(ethers.getBytes(messageHash));
  };
});
