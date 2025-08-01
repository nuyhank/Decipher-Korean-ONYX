// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Collateral is ERC721 {
    uint256 public nextTokenId;
    address public admin;

    constructor() ERC721("Won Repo 07", "WRP07") {
        admin = msg.sender;
    }

    function mint(address to) external {
        require(msg.sender == admin, "Only admin can mint");
        _safeMint(to, nextTokenId);
        nextTokenId++;
    }
}
