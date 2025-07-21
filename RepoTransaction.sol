// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RepoTransaction is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Repo {
        string sellerDID;
        string buyerDID;
        uint256 principal;
        uint256 interestRate; // in basis points (bps)
        uint256 startDate;
        uint256 maturityDate;
        uint256 preCalculatedInterest;
        bool settled;
        bool deposited;
    }

    event Deposited(address indexed by, uint256 amount);
    event Settled(address indexed by, uint256 totalPaid);
    event InterestCalculated(uint256 interestAmount);

    IERC20 public token; // WRP
    Repo public repo;
    address public seller;
    address public buyer;

    constructor(
        address tokenAddress,
        string memory _sellerDID,
        string memory _buyerDID,
        uint256 _principal,
        uint256 _interestRateBPS,
        uint256 _startDate,
        uint256 _maturityDate,
        address _buyer
    ) {
        require(_maturityDate > _startDate, "Invalid dates");
        require(_principal > 0, "Principal must be > 0");
        require(_interestRateBPS <= 10000, "Max 100% interest");

        token = IERC20(tokenAddress);
        seller = msg.sender;
        buyer = _buyer;

        uint256 duration = (_maturityDate - _startDate) / 1 days;
        uint256 interest = (_principal * _interestRateBPS * duration) / (365 * 10000);

        repo = Repo({
            sellerDID: _sellerDID,
            buyerDID: _buyerDID,
            principal: _principal,
            interestRate: _interestRateBPS,
            startDate: _startDate,
            maturityDate: _maturityDate,
            preCalculatedInterest: interest,
            settled: false,
            deposited: false
        });

        emit InterestCalculated(interest);
    }

    function deposit() external nonReentrant {
    require(msg.sender == seller, "Only seller can deposit");
    require(!repo.deposited, "Already deposited");

    token.safeTransferFrom(seller, address(this), repo.principal);

    token.safeTransfer(buyer, repo.principal);

    repo.deposited = true;

    emit Deposited(msg.sender, repo.principal);
}


    function settle() external nonReentrant {
        require(msg.sender == buyer, "Only buyer can settle");
        require(block.timestamp >= repo.maturityDate, "Not yet matured");
        require(!repo.settled, "Already settled");
        require(repo.deposited, "Principal not deposited");

        uint256 totalOwed = repo.principal + repo.preCalculatedInterest;

        token.safeTransferFrom(buyer, seller, totalOwed);
        token.safeTransfer(buyer, repo.principal); // Buyer receives the principal

        repo.settled = true;

        emit Settled(msg.sender, totalOwed);
    }

    function calculateInterest() external view returns (uint256) {
        return repo.preCalculatedInterest;
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external {
        require(msg.sender == seller, "Only seller can recover tokens");
        IERC20(tokenAddress).safeTransfer(seller, tokenAmount);
    }
}
