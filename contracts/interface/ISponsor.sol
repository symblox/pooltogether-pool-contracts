pragma solidity >=0.6.0 <0.7.0;

interface ISponsor {
  function ticketHolder() external view returns (address);

  function getReward() external;

  function deposit(
    address tokenIn,
    uint256 tokenAmountIn,
    uint256 minPoolAmountOut
  ) external;

  function depositAll(address tokenIn, uint256 minPoolAmountOut) external;
}
