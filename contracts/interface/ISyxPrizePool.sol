pragma solidity >=0.6.0 <0.7.0;

interface ISyxPrizePool {
  function depositVlxTo(
    address to,
    uint256 amount,
    address controlledToken,
    address referrer
  ) external payable;
}
