// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DeFiLending is Ownable {
    IERC20 public token;

    struct UserAccount {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastInterestBlock;
    }

    mapping(address => UserAccount) public accounts;
    uint256 public totalDeposits;
    uint256 public totalBorrowed;
    uint256 public baseRate = 5;
    uint256 public utilizationMultiplier = 20;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function calculateInterestRate() public view returns (uint256) {
        if (totalDeposits == 0) return baseRate;
        uint256 utilization = (totalBorrowed * 100) / totalDeposits;
        return baseRate + (utilization * utilizationMultiplier) / 100;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount > 0");
        updateInterest(msg.sender);
        token.transferFrom(msg.sender, address(this), amount);
        accounts[msg.sender].deposited += amount;
        totalDeposits += amount;
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "Amount > 0");
        updateInterest(msg.sender);
        uint256 maxBorrow = (accounts[msg.sender].deposited * 60) / 100;
        require(accounts[msg.sender].borrowed + amount <= maxBorrow, "Exceeds borrow limit");
        accounts[msg.sender].borrowed += amount;
        totalBorrowed += amount;
        token.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "Amount > 0");
        updateInterest(msg.sender);
        token.transferFrom(msg.sender, address(this), amount);
        uint256 repayAmount = amount > accounts[msg.sender].borrowed ? accounts[msg.sender].borrowed : amount;
        accounts[msg.sender].borrowed -= repayAmount;
        totalBorrowed -= repayAmount;
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount > 0");
        updateInterest(msg.sender);
        require(accounts[msg.sender].borrowed == 0, "Repay loan first");
        require(accounts[msg.sender].deposited >= amount, "Insufficient balance");
        accounts[msg.sender].deposited -= amount;
        totalDeposits -= amount;
        token.transfer(msg.sender, amount);
    }

    function updateInterest(address user) internal {
        UserAccount storage account = accounts[user];
        if (account.lastInterestBlock == 0) {
            account.lastInterestBlock = block.number;
            return;
        }

        uint256 blocksElapsed = block.number - account.lastInterestBlock;
        if (account.borrowed > 0 && blocksElapsed > 0) {
            uint256 rate = calculateInterestRate();
            uint256 interest = (account.borrowed * rate * blocksElapsed) / (100 * 2102400);
            account.borrowed += interest;
            totalBorrowed += interest;
        }

        account.lastInterestBlock = block.number;
    }

    function getAccountDetails(address user) external view returns (uint256 deposited, uint256 borrowed) {
        UserAccount memory account = accounts[user];
        return (account.deposited, account.borrowed);
    }
}
