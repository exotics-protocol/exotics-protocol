import { expect } from "chai";
import { deployments, ethers, network } from "hardhat";

describe("Exotics MVP test case", function () {
  before(async function () {
    this.signers = await ethers.getSigners();
  });

  beforeEach(async function () {
    await deployments.fixture(["RaceLens"]);
    this.exotic = await ethers.getContract("Exotic");
	this.vrf = await ethers.getContract('MockVRFCoordinator');
    this.lens = await ethers.getContract('RaceLens');
  });

  it("should take win bets and give correct odds", async function () {
    const nextRace = await this.exotic.nextRaceId();

    let odds = await this.exotic.odds(nextRace, [0]);
    expect(odds).to.eq(0);

    await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther("1")});
    odds = await this.exotic.odds(nextRace, [0]);
    expect(odds).to.eq(1*10**10);

    await this.exotic.placeBet(nextRace, [1], {value: ethers.utils.parseEther("1")});
    odds = await this.exotic.odds(nextRace, [0]);
    expect(odds).to.eq(5*10**9);
    odds = await this.exotic.odds(nextRace, [1]);
    expect(odds).to.eq(5*10**9);

    await this.exotic.placeBet(nextRace, [1], {value: ethers.utils.parseEther("1")});
    await this.exotic.placeBet(nextRace, [2], {value: ethers.utils.parseEther("1")});
    odds = await this.exotic.odds(nextRace, [1]);
    expect(odds).to.eq(5*10**9);
    odds = await this.exotic.odds(nextRace, [0]);
    expect(odds).to.eq(25*10**8);
    odds = await this.exotic.odds(nextRace, [2]);
    expect(odds).to.eq(25*10**8);
  });

  it("A one bet race should always win", async function () {
    const nextRace = await this.exotic.nextRaceId();
    await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther("1")});
	await network.provider.send("evm_increaseTime", [1199])  // Maximum time possible for race to end as we don't fully control starttime.
	await this.exotic.startRace(nextRace);
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
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
	const odds = await this.exotic.odds(nextRace, [0]);
	expect(odds).to.equal(1*10**10);
	await this.exotic.placeBet(nextRace, [1], {value: ethers.utils.parseEther('1')});
	expect(await this.exotic.odds(nextRace, [0])).to.equal(5*10**9);
	expect(await this.exotic.odds(nextRace, [1])).to.equal(5*10**9);
	expect(await this.exotic.odds(nextRace, [2])).to.equal(0);

	await this.exotic.placeBet(nextRace, [2], {value: ethers.utils.parseEther('2')});

	expect(await this.exotic.odds(nextRace, [0])).to.equal(25*10**8);
	expect(await this.exotic.odds(nextRace, [1])).to.equal(25*10**8);
	expect(await this.exotic.odds(nextRace, [2])).to.equal(5*10**9);
  });

  it("should payout winner and not loser", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
	await this.exotic.connect(this.signers[1]).placeBet(nextRace, [1], {value: ethers.utils.parseEther('1')});
	await network.provider.send("evm_increaseTime", [1199])  // Maximum time possible for race to end as we don't fully control starttime.
	await this.exotic.startRace(nextRace);
	await this.vrf.fulfill();
    const result = await this.exotic.raceResult(nextRace);
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

  it("should not allow ending a race twice", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
	await this.exotic.connect(this.signers[1]).placeBet(nextRace, [1], {value: ethers.utils.parseEther('1')});
	await network.provider.send("evm_increaseTime", [1199])  // Maximum time possible for race to end as we don't fully control starttime.
	await this.exotic.startRace(nextRace);
    await expect(this.exotic.startRace(nextRace)).to.be.reverted;
  });

  it("should return users bets", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
    expect(await this.exotic.userBetCount(this.signers[0].address)).to.equal(1);
	await this.exotic.placeBet(nextRace, [1], {value: ethers.utils.parseEther('1')});
    expect(await this.exotic.userBetCount(this.signers[0].address)).to.equal(2);

    const betOne = await this.exotic.userBet(this.signers[0].address, 0);
    expect(betOne[0]).to.equal(nextRace);
    expect(betOne[1]).to.equal(ethers.utils.parseEther('0.99'));
    expect(betOne[2]).to.equal(this.signers[0].address);
    expect(betOne[3][0]).to.equal(0);
    expect(betOne[4]).to.equal(false);
  });

  it("should not allow bet on invalid raceId", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await expect(this.exotic.placeBet(nextRace + 1, [0], {value: ethers.utils.parseEther('1')})).to.be.reverted;
  });

  it("should send the fee and jackpot contribution on bet", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
    expect(
      await ethers.provider.getBalance("0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE")
    ).to.eq(ethers.utils.parseEther('0.01'));
  });

  it("should return race from lens contract", async function (){
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [1], {value: ethers.utils.parseEther('1')});

    let race = await this.lens.race(nextRace)
    expect(race.raceResult).to.eql([
      ethers.BigNumber.from(0),
      ethers.BigNumber.from(0),
      ethers.BigNumber.from(0),
      ethers.BigNumber.from(0),
      ethers.BigNumber.from(0),
      ethers.BigNumber.from(0),
    ]);

	await network.provider.send("evm_increaseTime", [1199])
	await this.exotic.startRace(nextRace);
	await this.vrf.fulfill();

    race = await this.lens.race(nextRace)
    expect(race.raceResult.length).to.eq(6);

  });

  it("should return paginated list of bets", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
	await this.exotic.placeBet(nextRace, [1], {value: ethers.utils.parseEther('1')});
	await this.exotic.placeBet(nextRace, [2], {value: ethers.utils.parseEther('1')});
    const bets = await this.lens.userBets(this.signers[0].address, 3, 0);
    expect(bets.length).to.equal(3);
  });

  it("should trim users bet list to max available", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
	await this.exotic.placeBet(nextRace, [1], {value: ethers.utils.parseEther('1')});
	await this.exotic.placeBet(nextRace, [2], {value: ethers.utils.parseEther('1')});
    let bets;
    bets = await this.lens.userBets(this.signers[0].address, 3, 0);
    // All bets
    expect(bets.length).to.equal(3);
    expect(bets[0][3][0]).to.equal(2);
    expect(bets[1][3][0]).to.equal(1);
    expect(bets[2][3][0]).to.equal(0);

    bets = await this.lens.userBets(this.signers[0].address, 2, 0);
    // Most recent 2
    expect(bets.length).to.equal(2);
    expect(bets[0][3][0]).to.equal(2);
    expect(bets[1][3][0]).to.equal(1);

    bets = await this.lens.userBets(this.signers[0].address, 2, 1);
    // Last bet
    expect(bets.length).to.equal(1);
    expect(bets[0][3][0]).to.equal(0);

    await this.exotic.placeBet(nextRace, [3], {value: ethers.utils.parseEther('1')});
	await this.exotic.placeBet(nextRace, [4], {value: ethers.utils.parseEther('1')});
	await this.exotic.placeBet(nextRace, [5], {value: ethers.utils.parseEther('1')});

    bets = await this.lens.userBets(this.signers[0].address, 10, 0);
    expect(bets.length).to.equal(6);
    expect(bets[0][3][0]).to.equal(5);
    expect(bets[1][3][0]).to.equal(4);
    expect(bets[2][3][0]).to.equal(3);
    expect(bets[3][3][0]).to.equal(2);
    expect(bets[4][3][0]).to.equal(1);
    expect(bets[5][3][0]).to.equal(0);

    bets = await this.lens.userBets(this.signers[0].address, 10, 3);
    expect(bets.length).to.equal(0);

    bets = await this.lens.userBets(this.signers[0].address, 2, 1);
    expect(bets.length).to.equal(2);
    expect(bets[0][3][0]).to.equal(3);
    expect(bets[1][3][0]).to.equal(2);

    bets = await this.lens.userBets(this.signers[0].address, 5, 1);
    expect(bets.length).to.equal(1);
    expect(bets[0][3][0]).to.equal(0);
  });

  it("should respect the maxBet parameter", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
    await expect(
	    this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1000')})
    ).to.be.reverted;
    await this.exotic.updateMaxBet(ethers.utils.parseEther("5"));
    await expect(
	    this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('6')})
    ).to.be.reverted;
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('4')});
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('5')});
  });

  it("should auto start race if bet placed after frequency", async function (){
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
	await network.provider.send("evm_increaseTime", [1199])
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
	await this.vrf.fulfill();
    const race = await this.exotic.race(nextRace);
    expect(race[2]).to.be.gt(0);
  });

  it("should return all bets on a race", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
    let bets = await this.exotic.betsOnRace(this.signers[0].address, nextRace);
    expect(bets.length).to.eq(1);
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
	await this.exotic.placeBet(nextRace, [0], {value: ethers.utils.parseEther('1')});
    bets = await this.exotic.betsOnRace(this.signers[0].address, nextRace);
    expect(bets.length).to.eq(3);
  });

});
