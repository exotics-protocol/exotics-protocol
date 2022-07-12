import { expect } from "chai";
import { deployments, ethers, network } from "hardhat";

describe("Rewarder test case", function () {
  before(async function () {
    this.signers = await ethers.getSigners();
    this.rewarderFactory = await ethers.getContractFactory('Rewarder');
    this.tokenFactory = await ethers.getContractFactory("XTCToken");
  });

  beforeEach(async function () {
    this.token = await this.tokenFactory.deploy(
      'exotic',
      'XTC',
      this.signers[0].address,
      this.signers[0].address,
      this.signers[0].address,
      this.signers[0].address,
    );
    this.rewarder = await this.rewarderFactory.deploy(
      5000, // half the avax value
      this.signers[0].address
    );
    await this.rewarder.setToken(this.token.address);
  });

  it("should report and dispense correct amount", async function (){
    await this.token.transfer(this.rewarder.address, ethers.utils.parseEther('100'));
    expect(await this.rewarder.claimable(this.signers[0].address)).to.eq(0);
    await this.rewarder.addReward(
      this.signers[0].address,
      ethers.utils.parseEther('1')
    );
    expect(
      await this.rewarder.claimable(this.signers[0].address)
    ).to.eq(ethers.utils.parseEther('0.5'));
    await this.rewarder.claim()
    expect(await this.rewarder.claimable(this.signers[0].address)).to.eq(0);

    await this.rewarder.updateRate('20000')

    await this.rewarder.addReward(
      this.signers[0].address,
      ethers.utils.parseEther('1')
    );

    expect(
      await this.rewarder.claimable(this.signers[0].address)
    ).to.eq(ethers.utils.parseEther('2'));
  });

  it("should report and dispense correct adjusted amount", async function () {
    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const timestamp = block.timestamp;
    expect(
      await this.rewarder.rewardableAmount(100, timestamp + 60*10)
    ).to.equal(50);
    expect(
      await this.rewarder.rewardableAmount(100, timestamp + 60*9)
    ).to.equal(45);
    expect(
      await this.rewarder.rewardableAmount(100, timestamp + 60*5)
    ).to.equal(25);
    expect(
      await this.rewarder.rewardableAmount(100, timestamp)
    ).to.equal(0);


  });

});
