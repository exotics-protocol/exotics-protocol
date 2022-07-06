module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  let randomProviderAddress, fee, jackpotContribution, feeAddress, jackpotAddress, maxBet, frequency;

  fee = 50;
  jackpotContribution = 50;

  if (chainId == 43114) {
    // Avalanche mainnet uses chainlink
    maxBet = ethers.utils.parseEther("1");
    frequency = 60*10;
  }
  else if (chainId == 43113) {
    jackpotAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';
    maxBet = ethers.utils.parseEther("10");
    frequency = 60*5;
  }
  else if (chainId == 31337) {
    jackpotAddress = '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE';
    maxBet = ethers.utils.parseEther("100");
    frequency = 60*5;
  }

  randomProviderAddress = (await deployments.get('RandomProvider')).address;
  feeAddress = (await deployments.get('EquityFarm')).address;

  const exotic = await deploy('Exotic', {
    contract: 'Exotic',
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            randomProviderAddress,
            fee,
            jackpotContribution,
            feeAddress,
            jackpotAddress,
            maxBet,
            frequency
          ],
        },
      },
    },
    log: true,
  });

  if (exotic.newlyDeployed) {
    const randomProvider = await ethers.getContract('RandomProvider');
    await randomProvider.setExoticAddress(exotic.address);
  }

};

module.exports.tags = ["Exotic"];
module.exports.dependencies = ['RandomProvider', "EquityFarm"]
