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
        uint256 unstakeTime;
        uint256 unlockTime;
    }

    constructor()
        ERC20("Stragle Token", "STRAG")
        Ownable(msg.sender)
    {
        maxSupply = 2000000 * (10 ** 18);
        USDT_TOKEN = IERC20(USDT_ADDRESS);
    }

    function getBlockTimestamp () external  view returns (uint256) {
        return block.timestamp;
    }

    // USDT Balance
    function getUSDTBalance() external view returns (uint256) {
        return USDT_TOKEN.balanceOf(address(this));
    }

    // Minted STRAG amount
    function getTotalSupply() external view returns (uint256) {
        return totalSupply();
    }

    // Mint token
    function mint(uint256 amount) external  {
        require(amount > 0, "Amount must be > 0");
        require((totalSupply().add(amount)) <= maxSupply, "Exceeds maximum supply");
        require(USDT_TOKEN.allowance(msg.sender, address(this)) >= amount, "Not allowed to spend");
        require(USDT_TOKEN.transferFrom(msg.sender, address(this), amount), "USDT Transfer failed, ensure you have approved the correct allowance");

        _mint(msg.sender, amount);
    }

    // get Address Rewards
    function getAddressRewards() public view returns (uint256) {
        Staker memory staker = stakers[msg.sender];

        uint256 elapsedTime = block.timestamp - staker.rewardUpdateTime;
        uint256 newRewards = staker.balance.mul(elapsedTime).mul(APY).div(SECONDS_PER_YEAR).div(100);
        return staker.reward + newRewards;
    }

    // staking
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(allowance(msg.sender, address(this)) >= amount, "Not allowed to spend");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        transfer(address(this), amount);
        updateRewards(msg.sender);
        stakers[msg.sender].balance += amount;
        stakers[msg.sender].unstakeTime = block.timestamp + 365 days; // stake 至少一年
    }

    // unstake
    function unstake() external {
        require(stakers[msg.sender].unstakeTime <= block.timestamp, "Staking is still locked");
        require(stakers[msg.sender].balance <= 0, "Insufficient balance");

        stakers[msg.sender].unlockTime = block.timestamp + 180 days;
    }


    // withdraw token
    function withdrawStake() external {
        require(stakers[msg.sender].unlockTime <= block.timestamp, "Token unlock");
        require(stakers[msg.sender].balance >= 0, "Insufficient balance");

        uint balance = stakers[msg.sender].balance;
        stakers[msg.sender].balance = 0;
        transfer(msg.sender, balance);
    }

    // withdraw rewards
    function withdrawRewards() external {
        updateRewards(msg.sender);

        uint256 rewards = stakers[msg.sender].reward;
        require(rewards > 0, "No rewards to withdraw");

        stakers[msg.sender].reward = 0;
        USDT_TOKEN.transferFrom(address(this), msg.sender, rewards);
    }

    // update staker rewards
    function updateRewards(address stakerAddress) internal {
        Staker storage staker = stakers[stakerAddress];
        uint256 elapsedTime = block.timestamp - staker.rewardUpdateTime;
        staker.rewardUpdateTime = block.timestamp;

        uint256 newRewards = staker.balance.mul(elapsedTime).mul(APY).div(SECONDS_PER_YEAR).div(100);
        staker.reward.add(newRewards);        
    }
}