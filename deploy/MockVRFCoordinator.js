module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  // Avalanche mainnet uses chainlink
  if (chainId == 43114) {
  }
  // avalanche fuji uses chainlink
  else if (chainId == 43113) {
  }
  // hardhat uses mock vrf
  else if (chainId == 31337) {
    await deploy('MockVRFCoordinator', {
      contract: 'MockVRFCoordinator',
      from: deployer,
      log: true,
    });
  }
};

module.exports.tags = ["MockVRFCoordinator"];
