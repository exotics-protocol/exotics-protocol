module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  const exoticAddress = (await deployments.get('Exotic')).address;
  const rate = 10000;

  const rewarder = await deploy('Rewarder', {
    contract: 'Rewarder',
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [rate, exoticAddress],
        },
      },
    },
    log: true,
  });
  if (rewarder.newlyDeployed) {
    const exotic = await ethers.getContract("Exotic");
    let tx = await exotic.updateRewarder(rewarder.address);
    await tx.wait();
  }
};

module.exports.tags = ["Rewarder"];
module.exports.dependencies = ["Exotic"]
