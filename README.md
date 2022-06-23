# Jumbo's Exotic Betting and Casino

This project contains the [solidity](https://docs.soliditylang.org) smart contracts and deployment files for an on-chain casino application.

Currently there is one game in development see [game design](GAME-DESIGN.md) for information. This documentation is laid out as a small guide to running, modifying and testing the contracts locally.

## 1 Installing dependencies

The project uses [yarn](https://yarnpkg.com) to manage dependencies. After install nodejs and yarn run `yarn` in a terminal window to install the dependencies

## 2 Running the application

To run the application run the following in a terminal

`yarn hardhat node`

This starts a development blockchain node running locally on your machine and set to auto mine blocks. To interact with it from a terminal console run `yarn hardhat console --network localhost` from a new terminal. Additionally you can connect a [metamask](https://metamask.io/) wallet to it by following the guide [metamask hardhat setup](https://support.chainstack.com/hc/en-us/articles/4408642503449-Using-MetaMask-with-a-Hardhat-node)

## 3 Running the tests

To run the test suite run `yarn hardhat test`, the tests are written using javascript and [ethers.js](https://docs.ethers.io) and are good examples for interacting with the contracts.

## 4 Manual testing

As VRF does not run on a local hardhat network a mock contract is used to provide a "random" number. In order for it to function you must call the `fulfill` method on the `MockVRFCoordinator` contract before a result will be available.
