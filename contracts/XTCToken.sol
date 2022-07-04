//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract XTCToken is ERC20Burnable {
    constructor(
        string memory name,
        string memory symbol,
        address founderOne,
        address founderTwo,
        address treasury,
        address rewarder
    ) ERC20(name, symbol) {
        _mint(founderOne, 15000000e18);
        _mint(founderTwo, 15000000e18);
        _mint(treasury,   20000000e18);
        _mint(rewarder,   50000000e18);
    }
}
