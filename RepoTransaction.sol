// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract RepoTrade is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public wrpToken;           // 원금 토큰
    ERC721Burnable public collateralNFT;     // 담보 NFT

    address public seller;
    address public buyer;

    uint256 public collateralTokenId;
    uint256 public principalAmount;
    uint256 public interestRateBPS;
    uint256 public startDate;
    uint256 public maturityDate;
    uint256 public interestAmount;

    bool public collateralDeposited;
    bool public principalDeposited;
    bool public settled;

    event CollateralDeposited(address indexed seller, uint256 tokenId);
    event PrincipalDeposited(address indexed buyer, uint256 amount);
    event Settled(address indexed by, uint256 totalPaid);

    constructor(
        address _wrpToken,
        address _collateralNFT,
        address _buyer,
        uint256 _principalAmount,
        uint256 _interestRateBPS,
        uint256 _startDate,
        uint256 _maturityDate
    ) {
        require(_maturityDate > _startDate, "Invalid dates");
        require(_principalAmount > 0, "Principal must be > 0");
        require(_interestRateBPS <= 10000, "Interest max 100%");

        wrpToken = IERC20(_wrpToken);
        collateralNFT = ERC721Burnable(_collateralNFT);


        seller = msg.sender;
        buyer = _buyer;
        principalAmount = _principalAmount;
        interestRateBPS = _interestRateBPS;
        startDate = _startDate;
        maturityDate = _maturityDate;

        uint256 durationDays = (_maturityDate - _startDate) / 1 days;
        interestAmount = (principalAmount * interestRateBPS * durationDays) / (365 * 10000);
    }

    // 매도자가 담보 NFT 예치
    function depositCollateral(uint256 tokenId) external nonReentrant {
        require(msg.sender == seller, "Only seller");
        require(!collateralDeposited, "Collateral already deposited");

        collateralNFT.transferFrom(seller, address(this), tokenId);
        collateralTokenId = tokenId;
        collateralDeposited = true;

        emit CollateralDeposited(seller, tokenId);
    }

    // 매수자가 WRP 토큰으로 원금 지급
    function depositPrincipal() external nonReentrant {
        require(msg.sender == buyer, "Only buyer");
        require(!principalDeposited, "Principal already deposited");
        require(collateralDeposited, "Collateral not deposited yet");

        wrpToken.safeTransferFrom(buyer, seller, principalAmount);
        principalDeposited = true;

        emit PrincipalDeposited(buyer, principalAmount);
    }

    // 만기 시 매도자가 원금+이자 상환, 담보 반환
    function settle() external nonReentrant {
        require(msg.sender == seller, "Only seller can settle");
        require(block.timestamp >= maturityDate, "Not matured");
        require(collateralDeposited && principalDeposited, "Deposits incomplete");
        require(!settled, "Already settled");

        uint256 totalPayback = principalAmount + interestAmount;

        wrpToken.safeTransferFrom(seller, buyer, totalPayback);  // 원금+이자 상환
        collateralNFT.burn(collateralTokenId); // 담보 소

        settled = true;
        emit Settled(msg.sender, totalPayback);
    }

    function getFinalInterestAmount() external view returns (uint256) {
    uint256 durationDays = (maturityDate - startDate) / 1 days;
    return (principalAmount * interestRateBPS * durationDays) / (365 * 10000);
}
}
