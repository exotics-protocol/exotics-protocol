module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  let randomProviderAddress, fee, jackpotContribution, feeAddress, jackpotAddress;

  fee = 50;
  jackpotContribution = 50;

  if (chainId == 43114) {
    // Avalanche mainnet uses chainlink

  }
  else if (chainId == 43113) {
    feeAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';
    jackpotAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';

  }
  else if (chainId == 31337) {
    feeAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';
    jackpotAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';
  }

  randomProviderAddress = (await deployments.get('RandomProvider')).address;

  const exotic = await deploy('Exotic', {
    contract: 'Exotic',
    args: [
        randomProviderAddress,
        fee,
        jackpotContribution,
        feeAddress,
        jackpotAddress
    ],
    from: deployer,
    log: true,
  });

  if (exotic.newlyDeployed) {
    const randomProvider = await ethers.getContract('RandomProvider');
    await randomProvider.setExoticAddress(exotic.address);
  }

};

module.exports.tags = ["Exotic"];
module.exports.dependencies = ['RandomProvider']
