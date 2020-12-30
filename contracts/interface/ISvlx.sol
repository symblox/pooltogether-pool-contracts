pragma solidity >=0.6.0 <0.7.0;

interface ISvlx {
  function deposit() external payable;

  function withdraw(uint256 wad) external returns(uint256);

  function claimRewards() external;

  function claimable(address account) external returns(uint256);

  function getTotalWithdrawable() external returns(uint256);
}
