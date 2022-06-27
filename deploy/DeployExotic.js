module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  let vrfAddress, vrfSubscription;
  if (chainId == 43114) {
    // Avalanche mainnet uses chainlink

  }
  else if (chainId == 43113) {
    // avalanche fuji uses chainlink
    vrfAddress = '0x2eD832Ba664535e5886b75D64C46EB9a228C2610';
    // TODO: key hash
    vrfSubscription = 167;
  }
  else if (chainId == 31337) {
    // hardhat uses mock vrf
    vrfAddress = (await deployments.get('MockVRFCoordinator')).address;
    vrfSubscription = 0;
  }

  await deploy('Exotic', {
    contract: 'Exotic',
    args: [vrfSubscription, vrfAddress],
    from: deployer,
    log: true,
  });

};

module.exports.tags = ["Exotic"];
module.exports.dependencies = ['MockVRFCoordinator']
