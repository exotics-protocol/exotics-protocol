module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  let randomProviderAddress, fee, jackpotContribution, feeAddress, maxBet, frequency, houseAddress;

  fee = 50;
  jackpotContribution = 50;

  if (chainId == 43114) {
    // Avalanche mainnet uses chainlink
    maxBet = ethers.utils.parseEther("1");
    frequency = 60*60;
  }
  else if (chainId == 43113) {
    maxBet = ethers.utils.parseEther("10");
    frequency = 60*5;
  }
  else if (chainId == 31337) {
    maxBet = ethers.utils.parseEther("100");
    frequency = 60*5;
  }

  randomProviderAddress = (await deployments.get('RandomProvider')).address;
  feeAddress = (await deployments.get('EquityFarm')).address;
  houseAddress = (await deployments.get("House")).address;

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
            houseAddress,
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
    let tx = await randomProvider.setExoticAddress(exotic.address);
    await tx.wait();
  }

};

module.exports.tags = ["Exotic"];
module.exports.dependencies = ['RandomProvider', "EquityFarm", "House"]
