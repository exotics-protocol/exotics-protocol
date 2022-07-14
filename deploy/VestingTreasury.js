module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();

  const treasuryAddress = '0xfC0EdEFC1e852Fa2226CAa038047D73006Ce00Aa';
  const startTimestamp = 1657789750;
  const durationSeconds = 60*60*24*365;

  await deploy('VestingTreasury', {
    contract: 'VestingWallet',
    from: deployer,
    args: [
      treasuryAddress,
      startTimestamp,
      durationSeconds
    ],
    log: true,
  });
};

module.exports.tags = ["VestingTreasury"];
