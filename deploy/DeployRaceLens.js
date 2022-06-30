module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  const exoticAddress = (await deployments.get('Exotic')).address;
  const exotic = await deploy('RaceLens', {
    contract: 'RaceLens',
    from: deployer,
    args: [exoticAddress],
    log: true,
  });
};

module.exports.tags = ["RaceLens"];
module.exports.dependencies = ['Exotic']
