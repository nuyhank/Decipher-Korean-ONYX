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
        uint256 interestRate; // BPS
        uint256 startDate;
        uint256 maturityDate;
        bool settled;
        bool deposited;
    }

    event Deposited(address indexed by, uint256 amount);
    event Settled(address indexed by, uint256 amount);
    event InterestCalculated(uint256 interestAmount);

    IERC20 public token;
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
        require(_maturityDate > _startDate, "Maturity date must be after start date");
        require(_principal > 0, "Principal must be greater than zero");
        require(_interestRateBPS <= 10000, "Interest rate cannot exceed 100%");

        token = IERC20(tokenAddress);
        seller = msg.sender;
        buyer = _buyer;

        repo = Repo({
            sellerDID: _sellerDID,
            buyerDID: _buyerDID,
            principal: _principal,
            interestRate: _interestRateBPS,
            startDate: _startDate,
            maturityDate: _maturityDate,
            settled: false,
            deposited: false
        });
    }

    function deposit() external nonReentrant {
        require(msg.sender == seller, "RepoTransaction: Only seller can deposit");
        require(!repo.deposited, "RepoTransaction: Already deposited");

        token.safeTransferFrom(seller, address(this), repo.principal);
        repo.deposited = true;

        emit Deposited(seller, repo.principal);
    }

    function settle() external nonReentrant {
        require(msg.sender == buyer, "RepoTransaction: Only buyer can settle");
        require(block.timestamp >= repo.maturityDate, "RepoTransaction: Not matured yet");
        require(!repo.settled, "RepoTransaction: Already settled");
        require(repo.deposited, "RepoTransaction: Principal not deposited");

        uint256 interest = calculateInterest();
        uint256 total = repo.principal + interest;

        token.safeTransferFrom(buyer, seller, total);
        token.safeTransfer(seller, repo.principal);

        repo.settled = true;

        emit Settled(buyer, total);
    }

    function calculateInterest() public view returns (uint256) {
        uint256 duration = repo.maturityDate - repo.startDate;
        uint256 annualInterest = (repo.principal * repo.interestRate) / 10000;
        uint256 interest = (annualInterest * duration) / (365 days);
        return interest;
    }

    // This function should be protected or removed in production
    function forceSettle() external nonReentrant {
        require(msg.sender == buyer, "RepoTransaction: Only buyer can settle");
        require(!repo.settled, "RepoTransaction: Already settled");
        require(repo.deposited, "RepoTransaction: Principal not deposited");

        uint256 interest = calculateInterest();
        uint256 total = repo.principal + interest;

        token.safeTransferFrom(buyer, seller, total);
        token.safeTransfer(seller, repo.principal);

        repo.settled = true;
        emit Settled(buyer, total);
    }

    function getRepoInfo() external view returns (
        string memory sellerDID,
        string memory buyerDID,
        uint256 principal,
        uint256 interest,
        uint256 maturityAmount,
        bool deposited,
        bool settled
    ) {
        sellerDID = repo.sellerDID;
        buyerDID = repo.buyerDID;
        principal = repo.principal;
        interest = calculateInterest();
        maturityAmount = principal + interest;
        deposited = repo.deposited;
        settled = repo.settled;
    }

    // Emergency function to recover ERC20 tokens sent to the contract by mistake
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external {
        require(msg.sender == seller, "RepoTransaction: Only seller can recover tokens");
        IERC20(tokenAddress).safeTransfer(seller, tokenAmount);
    }
}
