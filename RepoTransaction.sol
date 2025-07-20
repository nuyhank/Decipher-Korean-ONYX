// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract RepoTransaction {
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

    // 매도자가 approve 후 호출해서 토큰 입금
    function deposit() external {
        require(msg.sender == seller, "Only seller can deposit");
        require(!repo.deposited, "Already deposited");

        bool success = token.transferFrom(seller, address(this), repo.principal);
        require(success, "Token transfer failed");

        repo.deposited = true;
    }

    function settle() external {
        require(msg.sender == buyer, "Only buyer can settle");
        require(block.timestamp >= repo.maturityDate, "Not matured yet");
        require(!repo.settled, "Already settled");
        require(repo.deposited, "Principal not deposited");

        uint256 interest = calculateInterest();
        uint256 total = repo.principal + interest;

        // 매수자가 approve 한 토큰을 컨트랙트가 받음
        bool success = token.transferFrom(buyer, seller, total);
        require(success, "Buyer payment failed");

        // 매도자에게 예치 토큰 반환 (원금)
        success = token.transfer(seller, repo.principal);
        require(success, "Return principal failed");

        repo.settled = true;
    }

    function calculateInterest() public view returns (uint256) {
        uint256 duration = (repo.maturityDate - repo.startDate) / 1 days;
        uint256 annualInterest = (repo.principal * repo.interestRate) / 10000;
        uint256 interest = (annualInterest * duration) / 365;
        return interest;
    }

    // 시연용으로 기간 상관없이 바로 정산 가능하게 하는 함수
    function forceSettle() external {
        require(msg.sender == buyer, "Only buyer can settle");
        require(!repo.settled, "Already settled");
        require(repo.deposited, "Principal not deposited");

        uint256 interest = calculateInterest();
        uint256 total = repo.principal + interest;

        bool success = token.transferFrom(buyer, seller, total);
        require(success, "Buyer payment failed");

        success = token.transfer(seller, repo.principal);
        require(success, "Return principal failed");

        repo.settled = true;
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
}
