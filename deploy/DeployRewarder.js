module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  const exoticAddress = (await deployments.get('Exotic')).address;
  const rate = 10000;

  const rewarder = await deploy('Rewarder', {
    contract: 'Rewarder',
    args: [rate, exoticAddress],
    from: deployer,
    log: true,
  });
  if (rewarder.newlyDeployed) {
    const exotic = await ethers.getContract("Exotic");
    await exotic.updateRewarder(rewarder.address);
  }
};

module.exports.tags = ["Rewarder"];
module.exports.dependencies = ["Exotic"]
