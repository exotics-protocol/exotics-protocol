module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  await deploy('MockVRFCoordinator', {
    contract: 'MockVRFCoordinator',
    from: deployer,
    log: true,
  });
};

module.exports.tags = ["MockVRFCoordinator"];
