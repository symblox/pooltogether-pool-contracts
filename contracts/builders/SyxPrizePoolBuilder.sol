// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./PrizePoolBuilder.sol";
import "../registry/RegistryInterface.sol";
import "./SyxSingleWinnerBuilder.sol";
import "../sponsor/SponsorProxyFactory.sol";
import "../prize-pool/syx/SyxPrizePoolProxyFactory.sol";
import "../token/ControlledTokenInterface.sol";

/* solium-disable security/no-block-members */
contract SyxPrizePoolBuilder is PrizePoolBuilder {
  using SafeMathUpgradeable for uint256;
  using SafeCastUpgradeable for uint256;

  struct SyxPrizePoolConfig {
    IERC20Upgradeable token;
    uint256 maxExitFeeMantissa;
    uint256 maxTimelockDuration;
  }

  RegistryInterface public reserveRegistry;
  SyxPrizePoolProxyFactory public syxPrizePoolProxyFactory;
  SyxSingleWinnerBuilder public syxSingleWinnerBuilder;
  SponsorProxyFactory public sponsorProxyFactory;

  event SponsorCreated(address sender, address sponsor);

  constructor(
    RegistryInterface _reserveRegistry,
    SyxPrizePoolProxyFactory _syxPrizePoolProxyFactory,
    SyxSingleWinnerBuilder _syxSingleWinnerBuilder,
    SponsorProxyFactory _sponsorProxyFactory
  ) public {
    require(address(_reserveRegistry) != address(0), "SyxPrizePoolBuilder/reserveRegistry-not-zero");
    require(
      address(_syxSingleWinnerBuilder) != address(0),
      "SyxPrizePoolBuilder/single-random-winner-builder-not-zero"
    );
    require(
      address(_syxPrizePoolProxyFactory) != address(0),
      "SyxPrizePoolBuilder/syx-prize-pool-proxy-factory-not-zero"
    );
    require(address(_sponsorProxyFactory) != address(0), "SyxPrizePoolBuilder/sponsor-factory-not-zero");
    reserveRegistry = _reserveRegistry;
    syxSingleWinnerBuilder = _syxSingleWinnerBuilder;
    sponsorProxyFactory = _sponsorProxyFactory;
    syxPrizePoolProxyFactory = _syxPrizePoolProxyFactory;
  }

  function _setupSingleRandomWinner(
    PrizePool prizePool,
    SyxSingleWinner singleRandomWinner,
    uint256 ticketCreditRateMantissa,
    uint256 ticketCreditLimitMantissa
  ) internal {
    address ticket = address(singleRandomWinner.ticket());
    address sponsorship = address(singleRandomWinner.sponsorship());

    prizePool.setPrizeStrategy(singleRandomWinner);

    prizePool.addControlledToken(ControlledTokenInterface(ticket));
    prizePool.addControlledToken(ControlledTokenInterface(sponsorship));

    prizePool.setCreditPlanOf(ticket, ticketCreditRateMantissa.toUint128(), ticketCreditLimitMantissa.toUint128());
  }

  function createSyxSingleWinner(
    SyxPrizePoolConfig calldata prizePoolConfig,
    SyxSingleWinnerBuilder.SingleRandomWinnerConfig calldata prizeStrategyConfig,
    uint8 decimals
  ) external returns (SyxPrizePool) {
    SyxPrizePool prizePool = syxPrizePoolProxyFactory.create();

    SyxSingleWinner prizeStrategy =
      syxSingleWinnerBuilder.createSyxSingleWinner(prizePool, prizeStrategyConfig, decimals, msg.sender);

    ControlledTokenInterface[] memory tokens;

    prizePool.initialize(
      reserveRegistry,
      tokens,
      prizePoolConfig.maxExitFeeMantissa,
      prizePoolConfig.maxTimelockDuration,
      prizePoolConfig.token
    );

    _setupSingleRandomWinner(
      prizePool,
      prizeStrategy,
      prizeStrategyConfig.ticketCreditRateMantissa,
      prizeStrategyConfig.ticketCreditLimitMantissa
    );

    prizePool.transferOwnership(msg.sender);

    emit PrizePoolCreated(msg.sender, address(prizePool));

    return prizePool;
  }

  function createSyxPrizePool(SyxPrizePoolConfig calldata config) external returns (SyxPrizePool) {
    SyxPrizePool prizePool = syxPrizePoolProxyFactory.create();
    ControlledTokenInterface[] memory tokens;

    prizePool.initialize(reserveRegistry, tokens, config.maxExitFeeMantissa, config.maxTimelockDuration, config.token);

    prizePool.transferOwnership(msg.sender);

    emit PrizePoolCreated(msg.sender, address(prizePool));

    return prizePool;
  }

  function createSponsor() external returns (Sponsor) {
    Sponsor sponsor = sponsorProxyFactory.create();
    emit SponsorCreated(msg.sender, address(sponsor));
    return sponsor;
  }
}
