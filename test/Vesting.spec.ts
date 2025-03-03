import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';
import { Token, Token__factory, Vesting, Vesting__factory, Staking, Staking__factory } from '../typechain-types';
import { time } from '@nomicfoundation/hardhat-network-helpers';

describe('TokenVesting', () => {
  let Token: Token__factory;
  let testToken: Token;
  let TokenVesting: Vesting__factory;
  let Staking: Staking__factory;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];
  let tokenVesting: Vesting;
  let staking: Staking;

  beforeEach(async () => {
    Token = await ethers.getContractFactory('Token');
    TokenVesting = await ethers.getContractFactory('Vesting');
    Staking = await ethers.getContractFactory('Staking');

    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    testToken = await Token.connect(owner).deploy('Test Token', 'TT');
    await testToken.waitForDeployment();
    await testToken.connect(owner).mint(owner.address, 1000n * 10n ** 18n);

    tokenVesting = await upgrades.deployProxy(TokenVesting, [await testToken.getAddress(), owner.address, owner.address], {
      initializer: 'initialize',
    });

    staking = await upgrades.deployProxy(Staking, [await testToken.getAddress(), await tokenVesting.getAddress()], {
      initializer: 'initialize',
    });

    await tokenVesting.connect(owner).setStakingAddress(await staking.getAddress());

    await staking.connect(owner).unpause();
    await staking
      .connect(owner)
      .setSeasonInfo(1, Math.floor(Date.now() / 1000), Math.floor(Date.now() / 1000 + 1000 * 60 * 60 * 24 * 7), 500, 2000, 2000, 1000, 100, ethers.ZeroAddress);
  });

  describe('Vesting', () => {
    it('should assign the total supply of tokens to the owner', async () => {
      const ownerBalance = await testToken.balanceOf(owner.address);
      expect(await testToken.totalSupply()).to.equal(ownerBalance);
    });

    it('should vest tokens gradually', async () => {
      expect(await tokenVesting.getToken()).to.equal(await testToken.getAddress());

      await expect(testToken.transfer(await tokenVesting.getAddress(), 1000))
        .to.emit(testToken, 'Transfer')
        .withArgs(owner.address, await tokenVesting.getAddress(), 1000);

      const vestingContractBalance = await testToken.balanceOf(await tokenVesting.getAddress());
      expect(vestingContractBalance).to.equal(1000);
      expect(await tokenVesting.getWithdrawableAmount()).to.equal(1000);

      const baseTime = await time.latest();
      const beneficiary = addr1;
      const startTime = baseTime;
      const cliff = 0;
      const duration = 1000;
      const slicePeriodSeconds = 1;
      const amount = 100;

      await tokenVesting.createVestingSchedule(beneficiary.address, startTime, cliff, duration, slicePeriodSeconds, amount);

      expect(await tokenVesting.getVestingSchedulesCount()).to.equal(1);
      expect(await tokenVesting.getVestingSchedulesCountByBeneficiary(beneficiary.address)).to.equal(1);

      const vestingScheduleId = await tokenVesting.computeVestingScheduleIdForAddressAndIndex(beneficiary.address, 0);

      expect(await tokenVesting.computeReleasableAmount(vestingScheduleId)).to.equal(0);

      const halfTime = duration / 2;
      await time.increase(halfTime);

      expect(await tokenVesting.connect(beneficiary).computeReleasableAmount(vestingScheduleId)).to.equal(50);

      await expect(tokenVesting.connect(addr2).release(vestingScheduleId)).to.be.revertedWithCustomError(tokenVesting, 'Unauthorized');

      await expect(tokenVesting.connect(beneficiary).release(vestingScheduleId))
        .to.emit(testToken, 'Transfer')
        .withArgs(await tokenVesting.getAddress(), beneficiary.address, 50);

      expect(await tokenVesting.connect(beneficiary).computeReleasableAmount(vestingScheduleId)).to.equal(0);

      const vestingSchedule = await tokenVesting.getVestingSchedule(vestingScheduleId);
      expect(vestingSchedule.released).to.equal(50);

      await time.increase(duration + 1);

      expect(await tokenVesting.connect(beneficiary).computeReleasableAmount(vestingScheduleId)).to.equal(50);

      await expect(tokenVesting.connect(beneficiary).release(vestingScheduleId))
        .to.emit(testToken, 'Transfer')
        .withArgs(await tokenVesting.getAddress(), beneficiary.address, 50);

      const updatedVestingSchedule = await tokenVesting.getVestingSchedule(vestingScheduleId);
      expect(updatedVestingSchedule.released).to.equal(100);

      expect(await tokenVesting.connect(beneficiary).computeReleasableAmount(vestingScheduleId)).to.equal(0);
    });
  });

  describe('Integration with Staking', () => {
    it('should release and deposit tokens via Staking contract', async () => {
      expect(await tokenVesting.getToken()).to.equal(await testToken.getAddress());

      await expect(testToken.transfer(await tokenVesting.getAddress(), 1000))
        .to.emit(testToken, 'Transfer')
        .withArgs(owner.address, await tokenVesting.getAddress(), 1000);

      const vestingContractBalance = await testToken.balanceOf(await tokenVesting.getAddress());
      expect(vestingContractBalance).to.equal(1000);
      expect(await tokenVesting.getWithdrawableAmount()).to.equal(1000);

      const beneficiary = addr1;
      const startTime = await time.latest();
      const cliff = 0;
      const duration = 1000;
      const slicePeriodSeconds = 1;
      const amount = 100;

      await tokenVesting.createVestingSchedule(beneficiary.address, startTime, cliff, duration, slicePeriodSeconds, amount);

      const vestingScheduleId = await tokenVesting.computeVestingScheduleIdForAddressAndIndex(beneficiary.address, 0);

      await time.increase(duration / 2);

      const releasableAmount = await tokenVesting.computeReleasableAmount(vestingScheduleId);
      expect(releasableAmount).to.equal(50);

      await testToken.connect(beneficiary).approve(await staking.getAddress(), 100);

      await expect(staking.connect(beneficiary).releaseAndDeposit(vestingScheduleId))
        .to.emit(testToken, 'Transfer')
        .withArgs(await tokenVesting.getAddress(), beneficiary.address, releasableAmount);

      const userStakedInfo = await staking.users(beneficiary.address);
      expect(userStakedInfo.erc20balance).to.equal(releasableAmount);
    });

    it('should revert if non-beneficiary tries to release and deposit', async () => {
      expect(await tokenVesting.getToken()).to.equal(await testToken.getAddress());

      await expect(testToken.transfer(await tokenVesting.getAddress(), 1000))
        .to.emit(testToken, 'Transfer')
        .withArgs(owner.address, await tokenVesting.getAddress(), 1000);

      const vestingContractBalance = await testToken.balanceOf(await tokenVesting.getAddress());
      expect(vestingContractBalance).to.equal(1000);
      expect(await tokenVesting.getWithdrawableAmount()).to.equal(1000);

      const beneficiary = addr1;
      const startTime = await time.latest();
      const cliff = 0;
      const duration = 1000;
      const slicePeriodSeconds = 1;
      const amount = 100;

      await tokenVesting.createVestingSchedule(beneficiary.address, startTime, cliff, duration, slicePeriodSeconds, amount);

      const vestingScheduleId = await tokenVesting.computeVestingScheduleIdForAddressAndIndex(beneficiary.address, 0);

      await time.increase(duration / 2);

      await expect(staking.connect(addr2).releaseAndDeposit(vestingScheduleId)).to.be.revertedWithCustomError(tokenVesting, 'Unauthorized');
    });
  });

  describe('Withdraw', () => {
    it('should not allow non-owners to withdraw tokens', async () => {
      await testToken.transfer(await tokenVesting.getAddress(), 1000);

      await expect(tokenVesting.withdraw(500))
        .to.emit(testToken, 'Transfer')
        .withArgs(await tokenVesting.getAddress(), owner.address, 500);

      await expect(tokenVesting.connect(addr1).withdraw(100)).to.be.reverted;
      await expect(tokenVesting.connect(addr2).withdraw(200)).to.be.reverted;
    });

    it('should not allow withdrawing more than the available withdrawable amount', async () => {
      await testToken.transfer(await tokenVesting.getAddress(), 1000);

      await expect(tokenVesting.withdraw(1500)).to.be.revertedWithCustomError(tokenVesting, 'InsufficientWithdrawableFunds');
    });

    it('should emit a Transfer event when withdrawing tokens', async () => {
      await testToken.transfer(await tokenVesting.getAddress(), 1000);

      await expect(tokenVesting.withdraw(500))
        .to.emit(testToken, 'Transfer')
        .withArgs(await tokenVesting.getAddress(), owner.address, 500);
    });

    it('should update the withdrawable amount after withdrawing tokens', async () => {
      await testToken.transfer(await tokenVesting.getAddress(), 1000);

      await tokenVesting.withdraw(300);
      expect(await tokenVesting.getWithdrawableAmount()).to.equal(700);
    });
  });
});
