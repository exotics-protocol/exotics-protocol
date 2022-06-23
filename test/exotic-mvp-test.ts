import { expect } from "chai";
import { deployments, ethers, network } from "hardhat";

describe("Exotics MVP test case", function () {
  before(async function () {
    this.signers = await ethers.getSigners();
  });

  beforeEach(async function () {
    await deployments.fixture(["Exotic"]);
    this.exotic = await ethers.getContract("Exotic");
	this.vrf = await ethers.getContract('MockVRFCoordinator');
  });

  it("should show the time of the next race", async function () {
	const nextRace = await this.exotic.nextRaceId();
   	expect(nextRace).is.gt(0);
  });

  it("should allow a win bet", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.win(nextRace, 0);
  });

  it("should return the odds for a bet", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.win(nextRace, 0, {value: ethers.utils.parseEther('1')});
	const odds = await this.exotic.odds(nextRace, [0]);
	console.log('odds ', odds);
	expect(odds).to.equal(1*10**10);
	await this.exotic.win(nextRace, 1, {value: ethers.utils.parseEther('1')});
	expect(await this.exotic.odds(nextRace, [0])).to.equal(5*10**9);  // 5*10**9
	expect(await this.exotic.odds(nextRace, [1])).to.equal(5*10**9);  // 5*10**9
	expect(await this.exotic.odds(nextRace, [2])).to.equal(0);
  });

  it("simple end to end with payout", async function () {
	const nextRace = await this.exotic.nextRaceId();
	await this.exotic.win(nextRace, 0, {value: ethers.utils.parseEther('1')});
	await this.exotic.win(nextRace, 1, {value: ethers.utils.parseEther('1')});
	await network.provider.send("evm_increaseTime", [1199])  // Maximum time possible for race to end as we don't fully control starttime.
	await this.exotic.endRace(nextRace);
	await this.vrf.fulfill();
	console.log('result is ', await this.exotic.results(nextRace));
	let i = 0;
	while (i < 100) {
		console.log("TEST THE PAYOUT FUNCITON");
		i++;
	}
	await this.exotic.payout(nextRace, 1);
  });
});
