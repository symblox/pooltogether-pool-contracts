pragma solidity >=0.6.0 <0.7.0;

interface ISponsor {
  function claimRewards() external;

  function depositAndStake(uint256 minPoolAmountOut) external payable;
}
