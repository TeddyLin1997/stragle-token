// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract StragleToken is ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;

    // address constant USDT_ADDRESS = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address constant USDT_ADDRESS = 0xA0419a28903961BdCa6999c4589Afc897a0211f4;
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

    uint256 public startTime = 0;

    constructor() {
        _disableInitializers();
    }



    function initialize() initializer public {
        __ERC20_init("Stragle Token", "STRAG");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        maxSupply = 5000000 * (10 ** 18);
        USDT_TOKEN = IERC20(USDT_ADDRESS);
        _mint(msg.sender, 1500000 * (10 ** 18));
    }

    event Mint(address indexed staker, uint256 tokenAmount, uint256 time);
    event Stake(address indexed staker, uint256 tokenAmount, uint256 time);
    event Unstake(address indexed staker, uint256 tokenAmount, uint256 time);
    event ClaimRewards(address indexed staker, uint256 rewards, uint256 time);

    // Mint (amount decimals = 6)
    function mint(uint256 amount) external  {
        require(amount > 0, "Amount must be > 0");
        require((totalSupply().add(amount * (10 ** 12))) <= maxSupply, "Exceeds maximum supply");
        require(USDT_TOKEN.allowance(msg.sender, address(this)) >= amount, "Not allowed to spend");
        require(USDT_TOKEN.transferFrom(msg.sender, address(this), amount), "USDT Transfer failed, ensure you have approved the correct allowance");

        _mint(msg.sender, amount * (10 ** 12));
        emit Mint(msg.sender, amount * (10 ** 12), block.timestamp);
    }

    // Stake (amount decimals = 18)
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

    // Unstake (amount decimals = 18)
    function unstake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(stakers[msg.sender].balance > 0, "Insufficient balance");
        require(stakers[msg.sender].balance >= amount, "Exceeds balance");

        stakers[msg.sender].balance -= amount;
        _transfer(address(this), msg.sender, amount);
        updateRewards(msg.sender);

        emit Unstake(msg.sender, amount, block.timestamp);
    }

    // claim rewards
    function claimRewards() external {
        updateRewards(msg.sender);
        uint256 rewards = stakers[msg.sender].reward;

        require(rewards > 0, "Rewards must be greater than 0");
        stakers[msg.sender].reward = 0;
        USDT_TOKEN.transfer(msg.sender, rewards);

        emit ClaimRewards(msg.sender, rewards * (10 ** 12), block.timestamp);
    }

    // update staker rewards
    function updateRewards(address stakerAddress) internal {
            Staker storage staker = stakers[stakerAddress];

            uint256 elapsedTime = block.timestamp - (startTime > staker.rewardUpdateTime ? startTime : staker.rewardUpdateTime);
            staker.rewardUpdateTime = block.timestamp;

        if (startTime > 0) {
            // (balance 18) * 12% / seconds / 10 ** 12
            uint256 newRewards = staker.balance.mul(elapsedTime).mul(APY).div(100).div(SECONDS_PER_YEAR).div(10 ** 12);
            staker.reward = staker.reward.add(newRewards);
        }
    }

    // Owner (amount decimals = 6)
    function ownerWithdraw(uint256 amount) external onlyOwner {
        require(amount <= USDT_TOKEN.balanceOf(address(this)), "USDT Transfer failed, ensure you have approved the correct allowance");

        USDT_TOKEN.transfer(msg.sender, amount);
    }

    function setStartTime () external onlyOwner {
        startTime = block.timestamp;
    }

    function cancelStartTime () external onlyOwner {
        startTime = 0;
    }

    function renounceOwnership() public pure override {
        revert("renounceOwnership disabled");
    }

    // upgrade
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {

    }

}