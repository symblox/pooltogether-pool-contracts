// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@symblox/pvlx-rng-contracts/contracts/RNGInterface.sol";
import "../token/TokenListenerInterface.sol";
import "../prize-pool/PrizePool.sol";
import "../prize-strategy/syx-single-winner/SyxSingleWinnerFactory.sol";
import "../token/ControlledTokenProxyFactory.sol";
import "../token/TicketProxyFactory.sol";
import "../token/TicketInterface.sol";
import "../token/Ticket.sol";

import "../external/openzeppelin/OpenZeppelinProxyFactoryInterface.sol";

/* solium-disable security/no-block-members */
contract SyxSingleWinnerBuilder {
  using SafeCastUpgradeable for uint256;

  event SyxSingleWinnerCreated(address indexed singleRandomWinner, address indexed ticket, address indexed sponsorship);

  struct SingleRandomWinnerConfig {
    RNGInterface rngService;
    uint256 prizePeriodStart;
    uint256 prizePeriodSeconds;
    string ticketName;
    string ticketSymbol;
    string sponsorshipName;
    string sponsorshipSymbol;
    uint256 ticketCreditLimitMantissa;
    uint256 ticketCreditRateMantissa;
    IERC20Upgradeable[] externalERC20Awards;
  }

  struct PrizeStrategyConfig {
    address ticket;
    address sponsorship;
  }

  ControlledTokenProxyFactory public controlledTokenProxyFactory;
  TicketProxyFactory public ticketProxyFactory;
  SyxSingleWinnerFactory public syxSingleWinnerFactory;

  constructor(
    SyxSingleWinnerFactory _syxSingleWinnerFactory,
    ControlledTokenProxyFactory _controlledTokenProxyFactory,
    TicketProxyFactory _ticketProxyFactory
  ) public {
    require(
      address(_syxSingleWinnerFactory) != address(0),
      "SingleRandomWinnerBuilder/single-random-winner-factory-not-zero"
    );
    require(
      address(_controlledTokenProxyFactory) != address(0),
      "SingleRandomWinnerBuilder/controlled-token-proxy-factory-not-zero"
    );
    require(address(_ticketProxyFactory) != address(0), "SingleRandomWinnerBuilder/ticket-proxy-factory-not-zero");
    ticketProxyFactory = _ticketProxyFactory;
    syxSingleWinnerFactory = _syxSingleWinnerFactory;
    controlledTokenProxyFactory = _controlledTokenProxyFactory;
  }

  function createSyxSingleWinner(
    PrizePool prizePool,
    SingleRandomWinnerConfig calldata config,
    uint8 decimals,
    address owner
  ) external returns (SyxSingleWinner) {
    PrizeStrategyConfig memory prizeStrategyConfig;
    prizeStrategyConfig.ticket = address(_createTicket(prizePool, config.ticketName, config.ticketSymbol, decimals));

    prizeStrategyConfig.sponsorship = address(
      _createControlledToken(prizePool, config.sponsorshipName, config.sponsorshipSymbol, decimals)
    );

    SyxSingleWinner prizeStrategy = syxSingleWinnerFactory.create();
    prizeStrategy.initialize(
      config.prizePeriodStart,
      config.prizePeriodSeconds,
      prizePool,
      TicketInterface(prizeStrategyConfig.ticket),
      IERC20Upgradeable(prizeStrategyConfig.sponsorship),
      config.rngService,
      config.externalERC20Awards
    );

    prizeStrategy.transferOwnership(owner);

    emit SyxSingleWinnerCreated(address(prizeStrategy), prizeStrategyConfig.ticket, prizeStrategyConfig.sponsorship);

    return prizeStrategy;
  }

  function _createControlledToken(
    TokenControllerInterface controller,
    string memory name,
    string memory symbol,
    uint8 decimals
  ) internal returns (ControlledToken) {
    ControlledToken token = controlledTokenProxyFactory.create();
    token.initialize(string(name), string(symbol), decimals, controller);
    return token;
  }

  function _createTicket(
    TokenControllerInterface controller,
    string memory name,
    string memory symbol,
    uint8 decimals
  ) internal returns (Ticket) {
    Ticket ticket = ticketProxyFactory.create();
    ticket.initialize(string(name), string(symbol), decimals, controller);
    return ticket;
  }
}
