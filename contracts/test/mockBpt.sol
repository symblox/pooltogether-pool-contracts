pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import '@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol';

contract mockBpt is ERC20Upgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  function isBound(address t) external view returns (bool) {
    return true;
  }

  function joinswapExternAmountIn(
    address tokenIn,
    uint256 tokenAmountIn,
    uint256 minPoolAmountOut
  ) external returns (uint256 poolAmountOut) {
    IERC20Upgradeable(tokenIn).safeTransferFrom(msg.sender, address(this), tokenAmountIn);
    return tokenAmountIn;
  }

  function exitswapPoolAmountIn(
    address tokenOut,
    uint256 poolAmountIn,
    uint256 minAmountOut
  ) external returns (uint256 tokenAmountOut) {
    IERC20Upgradeable(tokenOut).safeTransfer(msg.sender, poolAmountIn);
    return poolAmountIn;
  }
}
