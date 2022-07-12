module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  const founderAddress = '0x900b9Ac28DBE587c2650a070102bae4306100769';
  const startTimestamp = 1657411200;
  const durationSeconds = 60*60*24*365;

  await deploy('VestingFounderOne', {
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

module.exports.tags = ["VestingFounderOne"];
