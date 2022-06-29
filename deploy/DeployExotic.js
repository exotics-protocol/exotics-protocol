module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  let vrfAddress, vrfSubscription, fee, jackpotContribution, feeAddress, jackpotAddress;

  fee = 50;
  jackpotContribution = 50;
  if (chainId == 43114) {
    // Avalanche mainnet uses chainlink

  }
  else if (chainId == 43113) {
    // avalanche fuji uses chainlink
    vrfAddress = '0x2eD832Ba664535e5886b75D64C46EB9a228C2610';
    // TODO: key hash
    vrfSubscription = 167;
    feeAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';
    jackpotAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';

  }
  else if (chainId == 31337) {
    // hardhat uses mock vrf
    vrfAddress = (await deployments.get('MockVRFCoordinator')).address;
    vrfSubscription = 0;
    feeAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';
    jackpotAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';
  }

  await deploy('Exotic', {
    contract: 'Exotic',
    args: [vrfSubscription, vrfAddress, fee, jackpotContribution, feeAddress, jackpotAddress],
    from: deployer,
    log: true,
  });

};

module.exports.tags = ["Exotic"];
module.exports.dependencies = ['MockVRFCoordinator']
