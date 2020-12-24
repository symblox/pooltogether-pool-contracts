pragma solidity >=0.6.0 <0.7.0;

interface ISvlx {
  function deposit() external payable;

  function withdraw(uint256 wad) external returns(uint256);

  function claimInterest() external;

  function claimable(address account) external returns(uint256);

  function withdrawableAmount() external returns(uint256);
}
