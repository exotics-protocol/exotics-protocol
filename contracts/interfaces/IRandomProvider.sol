//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IRandomProvider {
    function requestRandomWords() external returns (uint256);
}
