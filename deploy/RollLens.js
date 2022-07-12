module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  const exoticAddress = (await deployments.get('Exotic')).address;
  const exotic = await deploy('RollLens', {
    contract: 'RollLens',
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [exoticAddress],
        },
      },
    },
    log: true,
  });
};

module.exports.tags = ["RollLens"];
module.exports.dependencies = ['Exotic']
