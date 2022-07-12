module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  let founderOneAddress, founderTwoAddress, treasuryAddress, rewarderAddress;

  rewarderAddress = (await deployments.get('Rewarder')).address;
  founderOneAddress = (await deployments.get('VestingFounderOne')).address;
  founderTwoAddress = (await deployments.get('VestingFounderTwo')).address;
  treasuryAddress = (await deployments.get('VestingTreasury')).address;


  if (chainId == 31337) {
      founderOneAddress = deployer;
      founderTwoAddress = deployer;
      treasuryAddress = deployer;
  }

  const xtc = await deploy('XTCToken', {
    contract: 'XTCToken',
    from: deployer,
    args: [
        "Exotic Token",
        "XTC",
        founderOneAddress,
        founderTwoAddress,
        treasuryAddress,
        rewarderAddress
    ],
    log: true,
  });

  if (xtc.newlyDeployed) {
    const rewarder = await ethers.getContract('Rewarder');
    let tx = await rewarder.setToken(xtc.address);
    await tx.wait();

    const equity = await ethers.getContract('EquityFarm');
    tx = await equity.setToken(xtc.address);
    await tx.wait();
  }
};

module.exports.tags = ["XTCToken"];
module.exports.dependencies = ['Rewarder', "EquityFarm", "VestingFounderOne", "VestingFounderTwo", "VestingTreasury"]
