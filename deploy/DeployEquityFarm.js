module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  const tokenAddress = (await deployments.get("XTCToken")).address;

  const rewarder = await deploy('EquityFarm', {
    contract: 'EquityFarm',
    args: [tokenAddress],
    from: deployer,
    log: true,
  });
};

module.exports.tags = ["EquityFarm"];
module.exports.dependencies = ['XTCToken']
