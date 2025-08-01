// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WRPToken is ERC20 {
    address public admin;

    constructor(uint256 initialSupply) ERC20("Won Repo", "WRP") {
        admin = msg.sender;
        _mint(admin, initialSupply);
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == admin, "Only admin can mint");
        _mint(to, amount);
    }
}
