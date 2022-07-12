module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();


  const rewarder = await deploy('EquityFarm', {
    contract: 'EquityFarm',
    args: [],
    from: deployer,
    log: true,
  });
};

module.exports.tags = ["EquityFarm"];
