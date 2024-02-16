// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/token/IERC20.sol";

contract StakingRewards {
    
    IERC20 public immutable rewardsToken;

    address public owner;

    Pool[] public pools; // Staking poolsx

    // Mapping poolId => staker address => PoolStaker
    mapping(uint256 => mapping(address => PoolStaker)) public poolStakers;

    // Staking user for a pool
    struct PoolStaker {
        uint256 amount; // The tokens quantity the user has staked.
        uint256 rewards; // The reward tokens quantity the user can harvest
        uint256 userRewardPerTokenPaid; 
    }

    // Staking pool
    struct Pool {
        IERC20 stakeToken; // Token to be staked
        uint256 tokensStaked; // Total tokens staked
        uint256 updatedAt; // Last block number the user had their rewards calculated
        uint256 finishAt; // Timestamp of when the rewards finish
        uint duration; // Duration of rewards to be paid out (in seconds)
        uint256 rewardRate; // Reward to be paid out per second
        uint256 rewardPerTokenStored; // Sum of (reward rate * dt * 1e18 / total supply)
    }

    // Events
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount);
    event HarvestRewards(address indexed user, uint256 indexed poolId, uint256 amount);
    event PoolCreated(uint256 poolId);

    constructor(address _rewardToken) {
        owner = msg.sender;
        rewardsToken = IERC20(_rewardToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    /**
     * @dev Create a new staking pool
     */
    function createPool(IERC20 _stakeToken) external onlyOwner {
        Pool memory pool;
        pool.stakeToken =  _stakeToken;
        pools.push(pool);
        uint256 poolId = pools.length - 1;
        emit PoolCreated(poolId);
    }

    modifier updateReward(uint256 _poolId, address _account) {
        Pool storage pool = pools[_poolId];
        PoolStaker storage staker = poolStakers[_poolId][_account];

        pool.rewardPerTokenStored = rewardPerToken(_poolId);
        pool.updatedAt = lastTimeRewardApplicable(_poolId);

        if (_account != address(0)) {
            staker.rewards = earned(_poolId, _account);
            staker.userRewardPerTokenPaid = pool.rewardPerTokenStored;
        }

        _;
    }

    function lastTimeRewardApplicable(uint256 _poolId) public view returns (uint) {
        Pool storage pool = pools[_poolId];
        return _min(pool.finishAt, block.timestamp);
    }

    function rewardPerToken(uint256 _poolId) public view returns (uint) {
        Pool storage pool = pools[_poolId];

        if (pool.tokensStaked == 0) {
            return pool.rewardPerTokenStored;
        }

        return
            pool.rewardPerTokenStored +
            (pool.rewardRate * (lastTimeRewardApplicable(_poolId) - pool.updatedAt) * 1e18) /
            pool.tokensStaked;
    }

    function stake(uint256 _poolId, uint _amount) external updateReward(_poolId, msg.sender) {
        require(_amount > 0, "amount = 0");

        Pool storage pool = pools[_poolId];
        PoolStaker storage staker = poolStakers[_poolId][msg.sender];

        pool.stakeToken.transferFrom(msg.sender, address(this), _amount);
        staker.amount += _amount;
        pool.tokensStaked += _amount;
        emit Deposit(msg.sender, _poolId, _amount);
    }

    function withdraw(uint256 _poolId, uint _amount) external updateReward(_poolId, msg.sender) {
        require(_amount > 0, "amount = 0");

        Pool storage pool = pools[_poolId];
        PoolStaker storage staker = poolStakers[_poolId][msg.sender];

        staker.amount -= _amount;
        pool.tokensStaked -= _amount;
        pool.stakeToken.transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _poolId, _amount);
    }

    function earned(uint256 _poolId, address _account) public view returns (uint) {
        PoolStaker storage staker = poolStakers[_poolId][_account];

        return
            ((staker.amount *
                (rewardPerToken(_poolId) - staker.userRewardPerTokenPaid)) / 1e18) +
            staker.rewards;
    }

    function getReward(uint256 _poolId) external updateReward(_poolId, msg.sender) {
        PoolStaker storage staker = poolStakers[_poolId][msg.sender];

        uint reward = staker.rewards;
        if (reward > 0) {
            staker.rewards = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
        emit HarvestRewards(msg.sender, _poolId, reward);
    }

    function setRewardsDuration(uint256 _poolId, uint _duration) external onlyOwner {
        Pool storage pool = pools[_poolId];
        require(pool.finishAt < block.timestamp, "reward duration not finished");
        
        pool.duration = _duration;
    }

    function notifyRewardAmount(
        uint256 _poolId,
        uint256 _amount
    ) external onlyOwner updateReward(0, address(0)) {
        Pool storage pool = pools[_poolId];

        if (block.timestamp >= pool.finishAt) {   //     18218670             finishAt: 19218674
            pool.rewardRate = _amount / pool.duration;
        } else {
            uint remainingRewards = (pool.finishAt - block.timestamp) * pool.rewardRate;
            pool.rewardRate = (_amount + remainingRewards) / pool.duration;
        }

        require(pool.rewardRate > 0, "reward rate = 0");
        require(
            pool.rewardRate * pool.duration <= rewardsToken.balanceOf(address(this)),
            "reward amount > balance"
        );

        pool.finishAt = block.timestamp + pool.duration;
        pool.updatedAt = block.timestamp;
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}
