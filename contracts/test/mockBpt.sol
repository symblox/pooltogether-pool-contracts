pragma solidity >=0.6.0 <0.7.0;
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol';

contract mockBpt is ERC20UpgradeSafe {
  using SafeERC20 for IERC20;

  function isBound(address t) external view returns (bool) {
    return true;
  }

  function joinswapExternAmountIn(
    address tokenIn,
    uint256 tokenAmountIn,
    uint256 minPoolAmountOut
  ) external returns (uint256 poolAmountOut) {
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenAmountIn);
    return tokenAmountIn;
  }

  function exitswapPoolAmountIn(
    address tokenOut,
    uint256 poolAmountIn,
    uint256 minAmountOut
  ) external returns (uint256 tokenAmountOut) {
    IERC20(tokenOut).safeTransfer(msg.sender, poolAmountIn);
    return poolAmountIn;
  }
}
