import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { Claim, Staking, TestToken } from '../typechain-types';
import { BigNumberish } from 'ethers';
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import keccak256 from 'keccak256';

describe('Claim Contract', function () {
  let claim: Claim;
  let staking: Staking;
  let token: TestToken;
  let owner: SignerWithAddress,
    user: SignerWithAddress,
    user1: SignerWithAddress,
    user2: SignerWithAddress,
    user3: SignerWithAddress,
    user4: SignerWithAddress,
    user5: SignerWithAddress,
    nonParticipant: SignerWithAddress,
    nonParticipant1: SignerWithAddress,
    nonParticipant2: SignerWithAddress,
    nonParticipant3: SignerWithAddress,
    other: SignerWithAddress;
  let merkleTree: StandardMerkleTree<any[]>;
  let merkleRoot: string;
  const ZERO_ADDRESS = ethers.ZeroAddress;
  const claimTokensAmount = ethers.parseEther('1000');
  let unlockTime: number;

  const participants: any[][] = [];

  beforeEach(async function () {
    [owner, user, user1, user2, user3, user4, user5, nonParticipant, nonParticipant1, nonParticipant2, nonParticipant3, other] = await ethers.getSigners();
    participants.push(
      [user.address, claimTokensAmount],
      [user1.address, claimTokensAmount],
      [user2.address, claimTokensAmount],
      [user3.address, claimTokensAmount],
      [user4.address, claimTokensAmount],
      [user5.address, claimTokensAmount]
    );

    merkleTree = StandardMerkleTree.of(participants, ['address', 'uint256']);
    merkleRoot = merkleTree.root;

    const TestTokenFactory = await ethers.getContractFactory('TestToken');
    token = await TestTokenFactory.deploy('TestToken', 'TTK', 18, ethers.parseEther('1000000'));
    await token.waitForDeployment();

    const StakingFactory = await ethers.getContractFactory('Staking');
    staking = await upgrades.deployProxy(StakingFactory, [await token.getAddress(), ethers.ZeroAddress], { initializer: 'initialize' });

    unlockTime = (await time.latest()) + 100000;

    claim = await (
      await ethers.getContractFactory('Claim')
    ).deploy(owner.address, await staking.getAddress(), await token.getAddress(), merkleRoot, unlockTime);
    await claim.waitForDeployment();

    await token.transfer(await claim.getAddress(), ethers.parseEther('10000'));
    await token.connect(user).approve(await staking.getAddress(), ethers.parseEther('10000'));

    await staking.connect(owner).unpause();
    await staking
      .connect(owner)
      .setSeasonInfo(
        1,
        Math.floor(Date.now() / 1000),
        Math.floor(Date.now() / 1000 + 1000 * 60 * 60 * 24 * 7),
        500,
        2000,
        2000,
        1000,
        100,
        await claim.getAddress()
      );
  });

  describe('Initialization', function () {
    it('should initialize with correct parameters', async function () {
      expect(await claim.merkleRoot()).to.equal(merkleRoot);
      expect(await claim.staking()).to.equal(await staking.getAddress());
      expect(await claim.token()).to.equal(await token.getAddress());
      expect(await claim.unlockTime()).to.equal(unlockTime);
    });

    it('should revert if unlockTime is in the past', async function () {
      const pastUnlockTime = Math.floor(Date.now() / 1000) - 1000;
      await expect(
        (await ethers.getContractFactory('Claim')).deploy(owner.address, await staking.getAddress(), await token.getAddress(), merkleRoot, pastUnlockTime)
      ).to.be.revertedWithCustomError(claim, 'InvalidUnlockTime');
    });
  });

  describe('Setter Functions', function () {
    it('should allow owner to update merkle root', async function () {
      const newRoot = `0x${keccak256('newRoot').toString('hex')}`;
      await expect(claim.connect(owner).setMerkleRoot(newRoot)).to.emit(claim, 'MerkleRootUpdated').withArgs(newRoot);
      expect(await claim.merkleRoot()).to.equal(newRoot);
    });

    it('should allow owner to update token address', async function () {
      await expect(claim.connect(owner).setTokenAddress(other.address)).to.emit(claim, 'TokenAddressUpdated').withArgs(other.address);
      expect(await claim.token()).to.equal(other.address);
    });

    it('should revert when setting token address to zero', async function () {
      await expect(claim.connect(owner).setTokenAddress(ZERO_ADDRESS)).to.be.revertedWithCustomError(claim, 'InvalidAddress');
    });

    it('should allow owner to update staking address', async function () {
      await expect(claim.connect(owner).setStakingAddress(other.address)).to.emit(claim, 'StakingAddressUpdated').withArgs(other.address);
      expect(await claim.staking()).to.equal(other.address);
    });

    it('should revert when setting staking address to zero', async function () {
      await expect(claim.connect(owner).setStakingAddress(ZERO_ADDRESS)).to.be.revertedWithCustomError(claim, 'InvalidAddress');
    });

    it('should revert when non-owner calls setter functions', async function () {
      await expect(claim.connect(user).setMerkleRoot(`0x${keccak256('newRoot').toString('hex')}`)).to.be.revertedWithCustomError(
        claim,
        'OwnableUnauthorizedAccount'
      );
      await expect(claim.connect(user).setTokenAddress(other.address)).to.be.revertedWithCustomError(claim, 'OwnableUnauthorizedAccount');
      await expect(claim.connect(user).setStakingAddress(other.address)).to.be.revertedWithCustomError(claim, 'OwnableUnauthorizedAccount');
    });
  });

  describe('claimTokens', function () {
    it('should revert if tokens parameter is zero', async function () {
      const proof = merkleTree.getProof([user.address, claimTokensAmount]);
      await expect(claim.connect(user).claimTokens(user.address, 0, proof)).to.be.revertedWithCustomError(claim, 'InvalidTokens');
    });

    it('should revert if claim contract has insufficient balance', async function () {
      const proof = merkleTree.getProof([user.address, claimTokensAmount]);
      await token.connect(owner).transfer(other.address, await token.balanceOf(await claim.getAddress()));
      await expect(claim.connect(user).claimTokens(user.address, ethers.parseEther('20000'), proof)).to.be.revertedWithCustomError(
        claim,
        'InsufficientBalance'
      );
    });

    it('should revert if proof is invalid', async function () {
      const wrongProof = merkleTree.getProof([user.address, claimTokensAmount]);
      await expect(claim.connect(owner).claimTokens(owner.address, claimTokensAmount, wrongProof)).to.be.revertedWithCustomError(claim, 'InvalidProof');
    });

    it('should allow a valid claim and stake tokens', async function () {
      const proof = merkleTree.getProof([user.address, claimTokensAmount]);
      const userTokenBalanceBefore = await token.balanceOf(user.address);
      await staking.connect(user)['claimAndDeposit(uint256,bytes32[])'](claimTokensAmount, proof);

      const userTokenBalanceAfter = await token.balanceOf(user.address);
      expect(userTokenBalanceAfter - userTokenBalanceBefore).to.equal(0);
      const userStakedInfo = await staking.users(user.address);

      expect(claimTokensAmount).to.equal(userStakedInfo.erc20balance);
    });

    it('should revert if user tries to claim twice', async function () {
      const proof = merkleTree.getProof([user.address, claimTokensAmount]);
      await claim.connect(user).claimTokens(user.address, claimTokensAmount, proof);
      await expect(claim.connect(user).claimTokens(user.address, claimTokensAmount, proof)).to.be.revertedWithCustomError(claim, 'TokensAlreadyClaimed');
    });
  });

  describe('isParticipating', function () {
    it('should return true if user is eligible and has not claimed', async function () {
      const proof = merkleTree.getProof([user.address, claimTokensAmount]);

      const participating = await claim.isParticipating(user.address, claimTokensAmount, proof);
      expect(participating).to.be.true;
    });

    it('should return false if tokens is zero', async function () {
      const proof: string[] = [];
      const participating = await claim.isParticipating(user.address, 0, proof);
      expect(participating).to.be.false;
    });

    it('should return false if user has already claimed', async function () {
      const proof = merkleTree.getProof([user.address, claimTokensAmount]);

      await claim.connect(user).claimTokens(user.address, claimTokensAmount, proof);
      const participating = await claim.isParticipating(user.address, claimTokensAmount, proof);
      expect(participating).to.be.false;
    });
  });

  describe('withdrawTokens', function () {
    it('should revert if withdraw is called before unlock time', async function () {
      const amount = ethers.parseEther('1000');
      await expect(claim.connect(owner).withdrawTokens(amount)).to.be.revertedWithCustomError(claim, 'WithdrawLocked');
    });

    it('should revert if amount is zero', async function () {
      await time.increase(unlockTime - Math.floor(Date.now() / 1000) + 1);

      await expect(claim.connect(owner).withdrawTokens(0)).to.be.revertedWithCustomError(claim, 'InvalidAmount');
    });

    it('should revert if contract has insufficient balance', async function () {
      await time.increase(unlockTime - Math.floor(Date.now() / 1000) + 1);

      const amount = ethers.parseEther('20000');
      await expect(claim.connect(owner).withdrawTokens(amount)).to.be.revertedWithCustomError(claim, 'InsufficientContractBalance');
    });

    it('should allow owner to withdraw tokens after unlock time', async function () {
      await time.increase(unlockTime - Math.floor(Date.now() / 1000) + 1);

      const amount = ethers.parseEther('1000');
      const ownerBalanceBefore = await token.balanceOf(owner.address);
      await expect(claim.connect(owner).withdrawTokens(amount)).to.emit(claim, 'TokensWithdrawn').withArgs(owner.address, amount);
      const ownerBalanceAfter = await token.balanceOf(owner.address);
      expect(ownerBalanceAfter - ownerBalanceBefore).to.equal(amount);
    });
  });
});
