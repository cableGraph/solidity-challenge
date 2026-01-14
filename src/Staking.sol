// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Staking {
    IERC20 public immutable STAKING_TOKEN;  
    address public owner;
    
    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 pendingInterest;
    }
    
    mapping(address => Stake) public stakes;
    
    error InvalidAmount();
    error InsufficientBalance();
    error NoInterest();
    error NotOwner();
    error TransferFailed(); 
    
    constructor(address _token) {
        STAKING_TOKEN = IERC20(_token);  // FIXED
        owner = msg.sender;
    }
    
    function stake(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        
        Stake storage userStake = stakes[msg.sender];
        
        if (userStake.amount > 0) {
            uint256 interest = calculateInterest(msg.sender);
            if (interest > 0) {
                userStake.pendingInterest = 0;
                // FIXED: Check transfer return value
                bool success = STAKING_TOKEN.transfer(msg.sender, interest);
                if (!success) revert TransferFailed();
            }
        }
        
        userStake.amount += amount;
        userStake.timestamp = block.timestamp;
        
        bool transferSuccess = STAKING_TOKEN.transferFrom(msg.sender, address(this), amount);
        if (!transferSuccess) revert TransferFailed();
    }
    
    function redeem(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        
        Stake storage userStake = stakes[msg.sender];
        if (amount > userStake.amount) revert InsufficientBalance();
        
        userStake.pendingInterest = 0;
        userStake.amount -= amount;
        userStake.timestamp = block.timestamp;
        
        bool success = STAKING_TOKEN.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }
    
    function claimInterest() external {
        uint256 interest = calculateInterest(msg.sender);
        if (interest == 0) revert NoInterest();
        
        Stake storage userStake = stakes[msg.sender];
        userStake.pendingInterest = 0;
        userStake.timestamp = block.timestamp;
        
        bool success = STAKING_TOKEN.transfer(msg.sender, interest);
        if (!success) revert TransferFailed();
    }
    
    function getAccruedInterest(address user) public view returns (uint256) {
        return calculateInterest(user);
    }
    
    function sweep() external {
        if (msg.sender != owner) revert NotOwner();
        
        uint256 balance = STAKING_TOKEN.balanceOf(address(this));
        
        bool success = STAKING_TOKEN.transfer(owner, balance);
        if (!success) revert TransferFailed();
    }
    
    function calculateInterest(address user) private view returns (uint256) {
        Stake memory userStake = stakes[user];
        if (userStake.amount == 0) return 0;
        
        uint256 duration = block.timestamp - userStake.timestamp;
        
        if (duration < 1 days) return 0;
        else if (duration < 7 days) return (userStake.amount * 1) / 100; // 1%
        else return (userStake.amount * 10) / 100; // 10%
    }
}
