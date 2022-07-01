module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId();
  await deploy('XTCToken', {
    contract: 'XTCToken',
    from: deployer,
    args: [
        "Exotic Token",
        "XTC",
        ethers.utils.parseEther("100000000"),
        deployer,
    ],
    log: true,
  });
};

module.exports.tags = ["XTCToken"];
