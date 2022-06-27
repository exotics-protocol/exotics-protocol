import { expect } from "chai";
import { deployments, ethers, network } from "hardhat";

describe.only("Exotics MVP test case", function () {
  before(async function () {
    this.signers = await ethers.getSigners();
  });

  beforeEach(async function () {
    await deployments.fixture(["Exotic"]);
    this.exotic = await ethers.getContract("Exotic");
	this.vrf = await ethers.getContract('MockVRFCoordinator');
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
	await this.exotic.endRace(nextRace);
	await this.vrf.fulfill();
    const balanceBefore = await this.signers[0].getBalance();
    await this.exotic.payout(0);
    expect(
      await this.signers[0].getBalance()
    ).to.be.closeTo(
      balanceBefore.add(ethers.utils.parseEther('1')),
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
	await this.exotic.endRace(nextRace);
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
      winnerBefore.add(ethers.utils.parseEther('2')),
      ethers.utils.parseEther('0.001')
    );
    expect(
      await loser.getBalance()
    ).to.be.closeTo(
      loserBefore,
      ethers.utils.parseEther('0.001')
    );

  });

});
