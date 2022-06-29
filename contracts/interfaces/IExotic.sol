//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IExotic{
    function endRace(
        uint256 requestId, uint256[] memory randomWords
    ) external;
}
