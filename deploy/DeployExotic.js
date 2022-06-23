module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();
  const vrf = await deployments.get('MockVRFCoordinator');
  await deploy('Exotic', {
    contract: 'Exotic',
    args: [167, vrf.address],
    from: deployer,
    log: true,
  });
};

module.exports.tags = ["Exotic"];
module.exports.dependencies = ['MockVRFCoordinator']
