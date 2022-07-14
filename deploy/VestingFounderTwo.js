module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  const founderAddress = '0xC357F6cB15d26D2a6e988C055d3E24E8EFEdB044';
  const startTimestamp = 1657789750;
  const durationSeconds = 60*60*24*365;

  await deploy('VestingFounderTwo', {
    contract: 'VestingWallet',
    from: deployer,
    args: [
      founderAddress,
      startTimestamp,
      durationSeconds
    ],
    log: true,
  });
};

module.exports.tags = ["VestingFounderTwo"];
