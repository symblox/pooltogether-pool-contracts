// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../../interface/ISponsor.sol";
import "../../interface/ISvlx.sol";
import "../PrizePool.sol";

contract SyxPrizePool is PrizePool {
  using AddressUpgradeable for address payable;

  IERC20Upgradeable private stakeToken;
  ISponsor public sponsor;

  event SyxPrizePoolInitialized(address indexed stakeToken);

  function initialize(
    RegistryInterface _reserveRegistry,
    ControlledTokenInterface[] memory _controlledTokens,
    uint256 _maxExitFeeMantissa,
    uint256 _maxTimelockDuration,
    IERC20Upgradeable _stakeToken
  ) public initializer {
    PrizePool.initialize(_reserveRegistry, _controlledTokens, _maxExitFeeMantissa, _maxTimelockDuration);
    stakeToken = _stakeToken;

    emit SyxPrizePoolInitialized(address(stakeToken));
  }

  receive() external payable {}

  function setSponsor(address _sponsor) external onlyOwner {
    sponsor = ISponsor(_sponsor);
  }

  /// @notice Determines whether the passed token can be transferred out as an external award.
  /// @dev Different yield sources will hold the deposits as another kind of token: such a Compound's cToken.  The
  /// prize strategy should not be allowed to move those tokens.
  /// @param _externalToken The address of the token to check
  /// @return True if the token may be awarded, false otherwise
  function _canAwardExternal(address _externalToken) internal view override returns (bool) {
    return address(stakeToken) != _externalToken;
  }

  /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
  /// @return The underlying balance of asset tokens
  function _balance() internal override returns (uint256) {
    return stakeToken.balanceOf(address(this));
  }

  function _token() internal view override returns (IERC20Upgradeable) {
    return stakeToken;
  }

  /// @notice Supplies asset tokens to the yield source.
  /// @param mintAmount The amount of asset tokens to be supplied
  function _supply(uint256 mintAmount) internal override {
    // no-op because nothing else needs to be done
  }

  /// @notice Redeems asset tokens from the yield source.
  /// @param redeemAmount The amount of yield-bearing tokens to be redeemed
  /// @return The actual amount of tokens that were redeemed.
  function _redeem(uint256 redeemAmount) internal override returns (uint256) {
    return redeemAmount;
  }

  function depositVlxTo(
    address to,
    uint256 amount,
    address controlledToken,
    address referrer
  ) external payable onlyControlledToken(controlledToken) canAddLiquidity(amount) nonReentrant {
    require(amount == msg.value, "PrizePool/invalid-amount");
    address operator = _msgSender();

    _mint(to, amount, controlledToken, referrer);

    ISvlx(address(_token())).deposit{ value: msg.value }();
    _supply(amount);

    emit Deposited(operator, to, controlledToken, amount, referrer);
  }

  function withdrawInstantlyFrom(
    address from,
    uint256 amount,
    address controlledToken,
    uint256 maximumExitFee
  ) external override nonReentrant onlyControlledToken(controlledToken) returns (uint256) {
    uint256 withdrawAmount = _redeem(amount);
    //When the amount of SVLX available is less than the amount entered, only the available amount is withdrawn
    uint256 actualWithdrawAmount = ISvlx(address(_token())).withdraw(withdrawAmount);

    if (actualWithdrawAmount > 0) {
      (uint256 exitFee, uint256 burnedCredit) =
        _calculateEarlyExitFeeLessBurnedCredit(from, controlledToken, actualWithdrawAmount);
      require(exitFee <= maximumExitFee, "PrizePool/exit-fee-exceeds-user-maximum");
      // burn the credit
      _burnCredit(from, controlledToken, burnedCredit);
      // burn the tickets
      ControlledToken(controlledToken).controllerBurnFrom(_msgSender(), from, actualWithdrawAmount);
      // redeem the tickets less the fee
      uint256 amountLessFee = actualWithdrawAmount.sub(exitFee);
      uint256 redeemed = _redeem(amountLessFee);
      // if (exitFee > 0) {
      //   uint256 curBalance = address(this).balance;
      //   if (address(sponsor) != address(0) && curBalance > 0) {
      //     sponsor.depositAndStake{value: curBalance}(0);
      //   }
      // }
      msg.sender.transfer(redeemed);

      emit InstantWithdrawal(_msgSender(), from, controlledToken, amount, redeemed, exitFee);
      return exitFee;
    } else {
      emit InstantWithdrawal(_msgSender(), from, controlledToken, amount, 0, 0);
      return 0;
    }
  }

  /// @notice Withdraw assets from the Prize Pool by placing them into the timelock.
  /// The timelock is used to ensure that the tickets have contributed their fair share of the prize.
  /// @dev Note that if the user has previously timelocked funds then this contract will try to sweep them.
  /// If the existing timelocked funds are still locked, then the incoming
  /// balance is added to their existing balance and the new timelock unlock timestamp will overwrite the old one.
  /// @param from The address to withdraw from
  /// @param amount The amount to withdraw
  /// @param controlledToken The type of token being withdrawn
  /// @return The timestamp from which the funds can be swept
  function withdrawWithTimelockFrom(
    address from,
    uint256 amount,
    address controlledToken
  ) external override nonReentrant onlyControlledToken(controlledToken) returns (uint256) {
    ISvlx svlx = ISvlx(address(_token()));
    uint256 maxWithdrawableAmount = svlx.withdrawableAmount();
    uint256 actualWithdrawAmount = amount;
    if (maxWithdrawableAmount < amount) {
      actualWithdrawAmount = maxWithdrawableAmount;
    }
    uint256 blockTime = _currentTime();
    (uint256 lockDuration, uint256 burnedCredit) =
      _calculateTimelockDuration(from, controlledToken, actualWithdrawAmount);
    uint256 unlockTimestamp = blockTime.add(lockDuration);
    _burnCredit(from, controlledToken, burnedCredit);
    ControlledToken(controlledToken).controllerBurnFrom(_msgSender(), from, actualWithdrawAmount);
    _mintTimelock(from, actualWithdrawAmount, unlockTimestamp);
    emit TimelockedWithdrawal(_msgSender(), from, controlledToken, actualWithdrawAmount, unlockTimestamp);

    // return the block at which the funds will be available
    return unlockTimestamp;
  }

  /// @notice Sweep available timelocked balances to their owners.  The full balances will be swept to the owners.
  /// @param users An array of owner addresses
  /// @return The total amount of assets swept from the Prize Pool
  function _sweepTimelockBalances(address[] memory users) internal override returns (uint256) {
    address operator = _msgSender();

    uint256[] memory balances = new uint256[](users.length);

    uint256 totalWithdrawal;

    uint256 i;
    for (i = 0; i < users.length; i++) {
      address user = users[i];
      if (_unlockTimestamps[user] <= _currentTime()) {
        totalWithdrawal = totalWithdrawal.add(_timelockBalances[user]);
        balances[i] = _timelockBalances[user];
        delete _timelockBalances[user];
      }
    }

    // if there is nothing to do, just quit
    if (totalWithdrawal == 0) {
      return 0;
    }

    timelockTotalSupply = timelockTotalSupply.sub(totalWithdrawal);

    uint256 redeemed = _redeem(totalWithdrawal);

    for (i = 0; i < users.length; i++) {
      if (balances[i] > 0) {
        delete _unlockTimestamps[users[i]];
        uint256 shareMantissa = FixedPoint.calculateMantissa(balances[i], totalWithdrawal);
        uint256 transferAmount = FixedPoint.multiplyUintByMantissa(redeemed, shareMantissa);
        //When the amount of SVLX available is less than the amount entered, only the available amount is withdrawn
        uint256 actualTransferAmount = ISvlx(address(_token())).withdraw(transferAmount);
        require(actualTransferAmount >= transferAmount, "withdraw amount error");
        address(uint160(users[i])).transfer(transferAmount);
        emit TimelockedWithdrawalSwept(operator, users[i], balances[i], transferAmount);
      }
    }

    return totalWithdrawal;
  }

  function claimAndDepositInterest() public payable {
    claimInterest();
    depositInterest();
  }

  function claimInterest() public {
    ISvlx(address(_token())).claimInterest();
  }

  function depositInterest() public payable {
    uint256 curBalance = address(this).balance;
    if (curBalance > 0) {
      sponsor.depositAndStake{ value: curBalance }(0);
    }
  }
}
