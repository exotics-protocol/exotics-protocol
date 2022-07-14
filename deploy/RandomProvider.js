module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  let vrfAddress, vrfSubscription;

  if (chainId == 43114) {
    // Avalanche mainnet uses chainlink
    vrfAddress = '0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634';
    vrfSubscription = 31;
    keyHash = '0x89630569c9567e43c4fe7b1633258df9f2531b62f2352fa721cf3162ee4ecb46';
  }
  else if (chainId == 43113) {
    // avalanche fuji uses chainlink
    vrfAddress = '0x2eD832Ba664535e5886b75D64C46EB9a228C2610';
    vrfSubscription = 167;
    keyHash = '0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61';
  }
  else if (chainId == 31337) {
    // hardhat uses mock vrf
    vrfAddress = (await deployments.get('MockVRFCoordinator')).address;
    vrfSubscription = 0;
    keyHash = '0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61';
  }

  await deploy('RandomProvider', {
    contract: 'RandomProvider',
    args: [vrfSubscription, vrfAddress, keyHash],
    from: deployer,
    log: true,
  });

};

module.exports.tags = ["RandomProvider"];
module.exports.dependencies = ['MockVRFCoordinator']
