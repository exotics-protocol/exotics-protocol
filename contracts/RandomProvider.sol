//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IExotic.sol";


/// @title Random source for results of games.
contract RandomProvider is VRFConsumerBaseV2, Ownable {

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;
    address vrfCoordinator;
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;
    uint32 callbackGasLimit = 200000;
    uint16 requestConfirmations = 3;
    uint32 numWords =  1;

    IExotic public exotic;

    constructor(
        uint64 subscriptionId,
        address _vrfCoordinator
    ) VRFConsumerBaseV2(_vrfCoordinator) {
		COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
		s_subscriptionId = subscriptionId;
    }

    function setExoticAddress(address _exoticAddress) public onlyOwner {
        require(_exoticAddress != address(0), "Address can't be 0 address");
        exotic = IExotic(_exoticAddress);
    }

    function requestRandomWords() external returns (uint256) {
        require(msg.sender == address(exotic), "Caller not Exotic");
	 	return COORDINATOR.requestRandomWords(
		  keyHash,
		  s_subscriptionId,
		  requestConfirmations,
		  callbackGasLimit,
		  numWords
		);
    }

    /// @notice VRF callback function.
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        exotic.endRace(requestId, randomWords);
    }

}
