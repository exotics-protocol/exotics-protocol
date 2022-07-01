module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  const exoticAddress = (await deployments.get('Exotic')).address;
  const tokenAddress = (await deployments.get("XTCToken")).address;
  const rate = 10000;

  const rewarder = await deploy('Rewarder', {
    contract: 'Rewarder',
    args: [tokenAddress, rate, exoticAddress],
    from: deployer,
    log: true,
  });
  if (rewarder.newlyDeployed) {
    const exotic = await ethers.getContract("Exotic");
    await exotic.updateRewarder(rewarder.address);
  }
};

module.exports.tags = ["Rewarder"];
module.exports.dependencies = ['XTCToken', "Exotic"]
