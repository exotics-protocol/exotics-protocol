import { expect } from "chai";
import { deployments, ethers, network } from "hardhat";
import { BigNumber } from "ethers";

describe("Exotics MVP test case", function () {
  before(async function () {
    this.signers = await ethers.getSigners();
  });

  beforeEach(async function () {
    await deployments.fixture(["RollLens", "XTCToken"]);
    this.exotic = await ethers.getContract("Exotic");
    this.vrf = await ethers.getContract('MockVRFCoordinator');
    this.lens = await ethers.getContract('RollLens');
    this.rewarder = await ethers.getContract("Rewarder");
    this.xtc = await ethers.getContract('XTCToken');
    this.equityFarm = await ethers.getContract('EquityFarm');
    this.house = await ethers.getContract("House");
    // Top up the rewarder.
    await this.xtc.transfer(this.rewarder.address, ethers.utils.parseEther("1000000"));
  });

  it("should take win bets and give correct odds", async function () {
    const nextRoll = await this.exotic.nextRollId();

    let odds = await this.exotic.odds(nextRoll, 0);
    expect(odds).to.eq(0);

    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther("1")});
    odds = await this.exotic.odds(nextRoll, 0);
    expect(odds).to.eq(1*10**10);

    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther("1")});
    odds = await this.exotic.odds(nextRoll, 0);
    expect(odds).to.eq(5*10**9);
    odds = await this.exotic.odds(nextRoll, 1);
    expect(odds).to.eq(5*10**9);

    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther("1")});
    await this.exotic.placeBet(nextRoll, 2, {value: ethers.utils.parseEther("1")});
    odds = await this.exotic.odds(nextRoll, 1);
    expect(odds).to.eq(5*10**9);
    odds = await this.exotic.odds(nextRoll, 0);
    expect(odds).to.eq(25*10**8);
    odds = await this.exotic.odds(nextRoll, 2);
    expect(odds).to.eq(25*10**8);
  });

  it("A one bet roll should always win", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther("1")});
    await network.provider.send("evm_increaseTime", [1199])  // Maximum time possible for roll to end as we don't fully control starttime.
    await this.exotic.startRoll(nextRoll);
    await this.vrf.fulfill();
    const balanceBefore = await this.signers[0].getBalance();
    await this.exotic.payout(0);
    expect(
      await this.signers[0].getBalance()
    ).to.be.closeTo(
      balanceBefore.add(ethers.utils.parseEther('0.99')),
      ethers.utils.parseEther('0.001')
    );
  });

  it("should return the odds for a win bet", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    const odds = await this.exotic.odds(nextRoll, 0);
    expect(odds).to.equal(1*10**10);
    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther('1')});
    expect(await this.exotic.odds(nextRoll, 0)).to.equal(5*10**9);
    expect(await this.exotic.odds(nextRoll, 1)).to.equal(5*10**9);
    expect(await this.exotic.odds(nextRoll, 2)).to.equal(0);

    await this.exotic.placeBet(nextRoll, 2, {value: ethers.utils.parseEther('2')});

    expect(await this.exotic.odds(nextRoll, 0)).to.equal(25*10**8);
    expect(await this.exotic.odds(nextRoll, 1)).to.equal(25*10**8);
    expect(await this.exotic.odds(nextRoll, 2)).to.equal(5*10**9);
  });

  it("should payout winner and not loser", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    await this.exotic.connect(this.signers[1]).placeBet(nextRoll, 1, {value: ethers.utils.parseEther('1')});
    await network.provider.send("evm_increaseTime", [1199])  // Maximum time possible for roll to end as we don't fully control starttime.
    await this.exotic.startRoll(nextRoll);
    await this.vrf.fulfill();
    const result = await this.exotic.rollResult(nextRoll);
    let winner, loser;
    if (result[0] == 0) {
        winner = this.signers[0];
        loser = this.signers[1];
    } else {
        loser = this.signers[0];
        winner = this.signers[1];
    }
    const loserBefore = await loser.getBalance();
    const winnerBefore = await winner.getBalance();
    await this.exotic.connect(winner).payout(0);
    await this.exotic.connect(loser).payout(0);
    expect(
      await winner.getBalance()
    ).to.be.closeTo(
      winnerBefore.add(ethers.utils.parseEther('1.98')),
      ethers.utils.parseEther('0.001')
    );
    expect(
      await loser.getBalance()
    ).to.be.closeTo(
      loserBefore,
      ethers.utils.parseEther('0.001')
    );

  });

  it("should not allow ending a roll twice", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    await this.exotic.connect(this.signers[1]).placeBet(nextRoll, 1, {value: ethers.utils.parseEther('1')});
    await network.provider.send("evm_increaseTime", [1199])  // Maximum time possible for roll to end as we don't fully control starttime.
    await this.exotic.startRoll(nextRoll);
    await expect(this.exotic.startRoll(nextRoll)).to.be.reverted;
  });

  it("should return users bets", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    expect(await this.exotic.userBetCount(this.signers[0].address)).to.equal(1);
    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther('1')});
    expect(await this.exotic.userBetCount(this.signers[0].address)).to.equal(2);

    const betOne = await this.exotic.userBet(this.signers[0].address, 0);
    expect(betOne[2]).to.equal(nextRoll);
    expect(betOne[0]).to.equal(ethers.utils.parseEther('0.99'));
    expect(betOne[1]).to.equal(this.signers[0].address);
    expect(betOne[3]).to.equal(0);
    expect(betOne[4]).to.equal(false);
  });

  it("should not allow bet on invalid rollId", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await expect(this.exotic.placeBet(nextRoll + 1, 0, {value: ethers.utils.parseEther('1')})).to.be.reverted;
  });

  it("should send the fee and pol contribution on bet", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    expect(
      await ethers.provider.getBalance(this.house.address)
    ).to.eq(ethers.utils.parseEther('0.005'));
    expect(
      await ethers.provider.getBalance(this.equityFarm.address)
    ).to.eq(ethers.utils.parseEther('0.005'));
  });

  it("should return roll from lens contract", async function (){
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther('1')});

    let roll = await this.lens.roll(nextRoll)
    expect(roll.rollResult).to.eql(
      ethers.BigNumber.from(0),
    );

    await network.provider.send("evm_increaseTime", [1199])
    await this.exotic.startRoll(nextRoll);
    await this.vrf.fulfill();

    roll = await this.lens.roll(nextRoll)
    expect(roll.rollResult).to.eq(1);

  });

  it("should return paginated list of bets", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther('1')});
    await this.exotic.placeBet(nextRoll, 2, {value: ethers.utils.parseEther('1')});
    const bets = await this.lens.userBets(this.signers[0].address, 3, 0);
    expect(bets.length).to.equal(3);
  });

  it("should trim users bet list to max available", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther('1')});
    await this.exotic.placeBet(nextRoll, 2, {value: ethers.utils.parseEther('1')});
    let bets;
    bets = await this.lens.userBets(this.signers[0].address, 3, 0);
    // All bets
    expect(bets.length).to.equal(3);
    expect(bets[0][3]).to.equal(2);
    expect(bets[1][3]).to.equal(1);
    expect(bets[2][3]).to.equal(0);

    bets = await this.lens.userBets(this.signers[0].address, 2, 0);
    // Most recent 2
    expect(bets.length).to.equal(2);
    expect(bets[0][3]).to.equal(2);
    expect(bets[1][3]).to.equal(1);

    bets = await this.lens.userBets(this.signers[0].address, 2, 1);
    // Last bet
    expect(bets.length).to.equal(1);
    expect(bets[0][3]).to.equal(0);

    await this.exotic.placeBet(nextRoll, 3, {value: ethers.utils.parseEther('1')});
    await this.exotic.placeBet(nextRoll, 4, {value: ethers.utils.parseEther('1')});
    await this.exotic.placeBet(nextRoll, 5, {value: ethers.utils.parseEther('1')});

    bets = await this.lens.userBets(this.signers[0].address, 10, 0);
    expect(bets.length).to.equal(6);
    expect(bets[0][3]).to.equal(5);
    expect(bets[1][3]).to.equal(4);
    expect(bets[2][3]).to.equal(3);
    expect(bets[3][3]).to.equal(2);
    expect(bets[4][3]).to.equal(1);
    expect(bets[5][3]).to.equal(0);

    bets = await this.lens.userBets(this.signers[0].address, 10, 3);
    expect(bets.length).to.equal(0);

    bets = await this.lens.userBets(this.signers[0].address, 2, 1);
    expect(bets.length).to.equal(2);
    expect(bets[0][3]).to.equal(3);
    expect(bets[1][3]).to.equal(2);

    bets = await this.lens.userBets(this.signers[0].address, 5, 1);
    expect(bets.length).to.equal(1);
    expect(bets[0][3]).to.equal(0);
  });

  it("should respect the maxBet parameter", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    await expect(
        this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1000')})
    ).to.be.reverted;
    await this.exotic.updateMaxBet(ethers.utils.parseEther("5"));
    await expect(
        this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('6')})
    ).to.be.reverted;
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('4')});
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('5')});
  });

  it("should auto start roll if bet placed after frequency", async function (){
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    await network.provider.send("evm_increaseTime", [1199])
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    await this.vrf.fulfill();
    const roll = await this.exotic.roll(nextRoll);
    expect(roll[1]).to.be.gt(0);
  });

  it("should return all bets on a roll", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    let bets = await this.exotic.betsOnRoll(this.signers[0].address, nextRoll);
    expect(bets.length).to.eq(1);
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    bets = await this.exotic.betsOnRoll(this.signers[0].address, nextRoll);
    expect(bets.length).to.eq(3);
  });

  it.skip("should give a reward on bet", async function () {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    expect(await this.rewarder.claimable(this.signers[0].address)).to.equal(ethers.utils.parseEther("1"));
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    expect(await this.rewarder.claimable(this.signers[0].address)).to.equal(ethers.utils.parseEther("2"));
    const balanceBefore = await this.xtc.balanceOf(this.signers[0].address);
    await this.rewarder.claim();
    expect(
      await this.xtc.balanceOf(this.signers[0].address)
    ).to.be.equal(
      balanceBefore.add(ethers.utils.parseEther('2')),
    );
    expect(await this.rewarder.claimable(this.signers[0].address)).to.equal(ethers.utils.parseEther("0"));
  });

  it("should distribute fees to stakers", async function () {
    // Deposit to equity farm.
    await this.xtc.approve(this.equityFarm.address, ethers.utils.parseEther("100"));
    await this.equityFarm.deposit(ethers.utils.parseEther("100"));
    expect(await this.equityFarm.pendingReward(this.signers[0].address)).to.equal(0);
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    expect(await this.equityFarm.pendingReward(this.signers[0].address)).to.equal(ethers.utils.parseEther('0.005'));
  });

  it("should return bets for a given roll", async function() {
    const nextRoll = await this.exotic.nextRollId();
    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther('1')});
    await this.exotic.placeBet(nextRoll, 2, {value: ethers.utils.parseEther('1')});
    let bets = await this.lens.userRollBets(nextRoll, this.signers[0].address, 3, 0);
    expect(bets.length).to.equal(3);

    bets = await this.lens.userRollBets(nextRoll, this.signers[0].address, 1, 0);
  });

  it("should return odds from lens", async function () {
    const nextRoll = await this.exotic.nextRollId();

    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    let odds = await this.lens.decimalOdds(nextRoll);
    expect(odds[0]).to.equal(10000);
    expect(odds[1]).to.equal(0);
    expect(odds[2]).to.equal(0);
    expect(odds[3]).to.equal(0);
    expect(odds[4]).to.equal(0);
    expect(odds[5]).to.equal(0);

    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther('2')});

    odds = await this.lens.decimalOdds(nextRoll);
    expect(odds[0]).to.equal(30000);
    expect(odds[1]).to.equal(15000);
    expect(odds[2]).to.equal(0);
    expect(odds[3]).to.equal(0);
    expect(odds[4]).to.equal(0);
    expect(odds[5]).to.equal(0);

    await this.exotic.placeBet(nextRoll, 5, {value: ethers.utils.parseEther('10')});

    odds = await this.lens.decimalOdds(nextRoll);
    expect(odds[0]).to.equal(130000);
    expect(odds[1]).to.equal(65000);
    expect(odds[2]).to.equal(0);
    expect(odds[3]).to.equal(0);
    expect(odds[4]).to.equal(0);
    expect(odds[5]).to.equal(13000);
  });

  it("should estimate odds correctly", async function () {
    const nextRoll = await this.exotic.nextRollId();
    let odds = await this.lens.estimateOdds(nextRoll, 0, ethers.utils.parseEther('1'));
    expect(odds).to.equal(10000);

    await this.exotic.placeBet(nextRoll, 0, {value: ethers.utils.parseEther('1')});
    odds = await this.lens.estimateOdds(nextRoll, 0, ethers.utils.parseEther('1'));
    expect(odds).to.equal(10000);

    odds = await this.lens.estimateOdds(nextRoll, 1, ethers.utils.parseEther('.99'));
    expect(odds).to.equal(20000);

    await this.exotic.placeBet(nextRoll, 1, {value: ethers.utils.parseEther('1')});

    odds = await this.lens.estimateOdds(nextRoll, 2, ethers.utils.parseEther('.99'));
    expect(odds).to.equal(30000);

    await this.exotic.placeBet(nextRoll, 2, {value: ethers.utils.parseEther('4')});
    odds = await this.lens.estimateOdds(nextRoll, 2, ethers.utils.parseEther('.99'));
    expect(odds).to.equal(14000);
  })

  it("should reduce rewards as race closer to starting", async function () {

  });
});
