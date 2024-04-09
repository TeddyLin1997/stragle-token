// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StragleToken is ERC20, Ownable {
    using SafeMath for uint256;

    // 主網地址
    address constant USDT_ADDRESS = 0x3e608899Ef527a8CD78B6498e58258b76CC95E97;
    uint256 public constant APY = 12;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    IERC20 public USDT_TOKEN;
    uint256 public maxSupply;

    // staking
    mapping(address => Staker) public stakers;
    struct Staker {
        uint256 balance;
        uint256 rewardUpdateTime;
        uint256 reward;
        uint256 firstJoinTime;
    }

    constructor()
        ERC20("Stragle Token", "STRAG")
        Ownable(msg.sender)
    {
        maxSupply = 5000000 * (10 ** 18);
        USDT_TOKEN = IERC20(USDT_ADDRESS);
        _mint(msg.sender, 1500000);
    }

    event Mint(address indexed staker, uint256 tokenAmount, uint256 time);
    event Stake(address indexed staker, uint256 tokenAmount, uint256 time);
    event Unstake(address indexed staker, uint256 tokenAmount, uint256 time);
    event ClaimRewards(address indexed staker, uint256 rewards, uint256 time);

    // Mint
    function mint(uint256 amount) external  {
        require(amount > 0, "Amount must be > 0");
        require((totalSupply().add(amount)) <= maxSupply, "Exceeds maximum supply");
        require(USDT_TOKEN.allowance(msg.sender, address(this)) >= amount, "Not allowed to spend");
        require(USDT_TOKEN.transferFrom(msg.sender, address(this), amount), "USDT Transfer failed, ensure you have approved the correct allowance");

        _mint(msg.sender, amount);
        emit Mint(msg.sender, amount, block.timestamp);
    }

    // Stake
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(allowance(msg.sender, address(this)) >= amount, "Not allowed to spend");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        transfer(address(this), amount);
        updateRewards(msg.sender);
        stakers[msg.sender].balance += amount;
        stakers[msg.sender].firstJoinTime = block.timestamp;

        emit Stake(msg.sender, amount, block.timestamp);
    }

    // Unstake 
    function unstake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(stakers[msg.sender].balance > 0, "Insufficient balance");
        require(stakers[msg.sender].balance > amount, "Exceeds balance");

        stakers[msg.sender].balance -= amount;
        transfer(msg.sender, amount);
        updateRewards(msg.sender);

        emit Unstake(msg.sender, amount, block.timestamp);
    }

    // claim rewards
    function claimRewards() external {
        updateRewards(msg.sender);
        uint256 rewards = stakers[msg.sender].reward;

        stakers[msg.sender].reward = 0;
        USDT_TOKEN.transfer(msg.sender, rewards);

        emit ClaimRewards(msg.sender, rewards, block.timestamp);
    }

    // update staker rewards
    function updateRewards(address stakerAddress) internal {
        Staker storage staker = stakers[stakerAddress];

        uint256 elapsedTime = block.timestamp - staker.rewardUpdateTime;
        staker.rewardUpdateTime = block.timestamp;

        uint256 newRewards = staker.balance.mul(elapsedTime).mul(APY).div(SECONDS_PER_YEAR).div(100);
        staker.reward = staker.reward.add(newRewards);
    }

    // Owner
    function ownerWithdraw(uint256 amount) external onlyOwner {
        require(amount <= USDT_TOKEN.balanceOf(address(this)), "USDT Transfer failed, ensure you have approved the correct allowance");

        USDT_TOKEN.transfer(msg.sender, amount);
    }

    function renounceOwnership() public pure override {
        revert("renounceOwnership disabled");
    }
}