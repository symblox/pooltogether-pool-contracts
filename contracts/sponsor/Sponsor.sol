pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "../interface/IRewardManager.sol";
import "../interface/IBPool.sol";
import "../interface/ISyxPrizePool.sol";

contract Sponsor is OwnableUpgradeable {
  using SafeMathUpgradeable for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  address public ticket;
  ISyxPrizePool public prizePool;
  IRewardManager public rewardManager;
  uint8 public rewardPoolId;
  address public lpToken; //bpt

  event LogDeposit(address indexed dst, uint256 amount);
  event LogWithdrawal(address indexed src, uint256 amount);
  event LogStake(address indexed dst, uint256 amount);
  event LogUnstake(address indexed src, uint256 amount);
  event LogReward(address indexed src, uint256 amount);

  function initialize(
    address _prizePool,
    address _ticket,
    address _lpToken,
    address _rewardManager,
    uint8 _rewardPoolId
  ) public initializer {
    __Ownable_init();
    lpToken = _lpToken;
    prizePool = ISyxPrizePool(uint160(_prizePool));
    ticket = _ticket;
    rewardManager = IRewardManager(_rewardManager);
    rewardPoolId = _rewardPoolId;
  }

  modifier validBpt(address token) {
    require(IBPool(lpToken).isBound(token), "Sponsor/invalid-token");
    _;
  }

  receive() external payable {
    // prizePool.depositVlxTo{ value: balance }(address(this), balance, ticket, address(0));
    depositAndStake(0);
  }

  function balanceOfLpToken() external view returns (uint256) {
    (uint256 amount, ) = rewardManager.userInfo(uint256(rewardPoolId), address(this));
    return amount;
  }

  function earned() external view returns (uint256) {
    return
      rewardManager.pendingSyx(uint256(rewardPoolId), address(this)) +
      IERC20Upgradeable(rewardManager.syx()).balanceOf(address(prizePool));
  }

  function claimRewards() external {
    IERC20Upgradeable syx = IERC20Upgradeable(rewardManager.syx());
    rewardManager.getReward(uint256(rewardPoolId));

    uint256 syxAmount = syx.balanceOf(address(this));

    syx.safeTransfer(address(prizePool), syxAmount);

    emit LogReward(address(prizePool), syxAmount);
  }

  /**
   * @dev Don't need to check onlyOwner as the caller needs to check that
   */
  function stakeLpToken(uint256 amount) internal {
    IERC20Upgradeable syx = IERC20Upgradeable(rewardManager.syx());
    (uint256 currBalance, ) = rewardManager.userInfo(uint256(rewardPoolId), address(this));
    if (IERC20Upgradeable(lpToken).allowance(address(this), address(rewardManager)) < amount) {
      IERC20Upgradeable(lpToken).approve(address(rewardManager), amount);
    }
    uint256 newBalance = rewardManager.deposit(uint256(rewardPoolId), amount);
    require(newBalance - currBalance == amount, "ERR_STAKE_REWARD");
    uint256 syxAmount = syx.balanceOf(address(this));
    syx.safeTransfer(address(prizePool), syxAmount);

    emit LogReward(address(prizePool), syxAmount);
    emit LogStake(msg.sender, newBalance);
  }

  /**
   * @dev Don't need to check onlyOwner as the caller needs to check that
   */
  function unstakeLpToken(uint256 lpTokenAmount) internal {
    IERC20Upgradeable syx = IERC20Upgradeable(rewardManager.syx());
    (uint256 currBalance, ) = rewardManager.userInfo(uint256(rewardPoolId), address(this));
    require(currBalance >= lpTokenAmount, "ERR_NOT_ENOUGH_BAL");

    uint256 newBalance = rewardManager.withdraw(uint256(rewardPoolId), lpTokenAmount);

    require(currBalance - newBalance == lpTokenAmount, "ERR_UNSTAKE_REWARD");

    uint256 syxAmount = syx.balanceOf(address(this));
    syx.safeTransfer(address(prizePool), syxAmount);

    emit LogReward(address(prizePool), syxAmount);
    emit LogUnstake(msg.sender, lpTokenAmount);
  }

  // /**
  //  * @dev Deposit first to the liquidity pool and then the reward pool to earn rewards
  //  * @param tokenIn ERC20 address to deposit
  //  * @param tokenAmountIn deposit amount, in wei
  //  */
  // function deposit(
  //   address tokenIn,
  //   uint256 tokenAmountIn,
  //   uint256 minPoolAmountOut
  // ) external validBpt(tokenIn) returns (uint256) {
  //   IERC20Upgradeable tokenDeposit = IERC20Upgradeable(tokenIn);
  //   require(tokenDeposit.allowance(msg.sender, address(this)) >= tokenAmountIn, 'ERR_ALLOWANCE');
  //   // transfer the tokens here
  //   tokenDeposit.safeTransferFrom(msg.sender, address(this), tokenAmountIn);
  //   return depositAll(tokenIn, minPoolAmountOut);
  // }

  //   function depositAll(address tokenIn, uint256 minPoolAmountOut)
  //     public
  //     validBpt(tokenIn)
  //     returns (uint256 poolAmountOut)
  //   {
  //     IERC20Upgradeable tokenDeposit = IERC20Upgradeable(tokenIn);
  //     // deposit to the bpool
  //     uint256 balance = tokenDeposit.balanceOf(address(this));
  //     if (tokenDeposit.allowance(address(this), lpToken) < balance) {
  //       tokenDeposit.approve(lpToken, balance);
  //     }
  //     poolAmountOut = IBPool(lpToken).joinswapExternAmountIn(tokenIn, balance, minPoolAmountOut);
  //     require(poolAmountOut > 0, 'ERR_BPOOL_DEPOSIT');

  //     // stake to RewardManager
  //     stakeLpToken(poolAmountOut);

  //     emit LogDeposit(msg.sender, poolAmountOut);
  //   }

  function depositAndStake(uint256 minPoolAmountOut) public payable returns (uint256 poolAmountOut) {
    poolAmountOut = IBPool(lpToken).joinswapWTokenIn{ value: address(this).balance }(minPoolAmountOut);
    require(poolAmountOut > 0, "ERR_BPOOL_DEPOSIT");
    // stake to RewardManager
    stakeLpToken(poolAmountOut);

    emit LogDeposit(msg.sender, poolAmountOut);
  }

  /**
   * @dev Unstake from the reward pool, then withdraw from the liquidity pool
   * @param tokenOut withdraw token address
   * @param amount withdraw amount, in wei
   */
  function withdraw(
    address tokenOut,
    uint256 amount,
    uint256 minAmountOut
  ) external validBpt(tokenOut) onlyOwner returns (uint256 tokenAmountOut) {
    // Withdraw the liquidity pool tokens from RewardManager
    unstakeLpToken(amount);

    // Remove liquidity from the bpool
    tokenAmountOut = IBPool(lpToken).exitswapPoolAmountIn(tokenOut, amount, minAmountOut);
    IERC20Upgradeable(tokenOut).safeTransfer(address(prizePool), tokenAmountOut);

    emit LogWithdrawal(tokenOut, tokenAmountOut);
  }
}
