//SPDX-License-Identifier: MIT
// Courtesy of glinda93 https://stackoverflow.com/a/71389949
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// Single threaded extension to allow testing request IDs.
contract MockVRFCoordinator {
    uint256 internal counter = 1111111111111111111111111111;
	address internal sender;
	uint256 internal raceId;

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32
    ) external returns (uint256 requestId) {
		sender = msg.sender;
		requestId = counter;
    }

	function fulfill() external {
        VRFConsumerBaseV2 consumer = VRFConsumerBaseV2(sender);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = counter;
		uint256 requestId = counter;
        consumer.rawFulfillRandomWords(requestId, randomWords);
        counter += 1;
	}
}
