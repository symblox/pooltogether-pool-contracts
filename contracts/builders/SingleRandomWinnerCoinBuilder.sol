// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import '@pooltogether/pooltogether-rng-contracts/contracts/RNGInterface.sol';
import '../token/TokenListenerInterface.sol';
import '../prize-pool/PrizePool.sol';
import '../prize-strategy/single-random-winner/SingleRandomWinnerCoinFactory.sol';
import '../token/ControlledTokenProxyFactory.sol';
import '../token/TicketProxyFactory.sol';
import '../external/openzeppelin/OpenZeppelinProxyFactoryInterface.sol';

/* solium-disable security/no-block-members */
contract SingleRandomWinnerCoinBuilder {
  using SafeCast for uint256;

  event SingleRandomWinnerCoinCreated(
    address indexed singleRandomWinner,
    address indexed ticket,
    address indexed sponsorship
  );

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
    address[] externalERC20Awards;
  }

  struct PrizeStrategyConfig {
    address ticket;
    address sponsorship;
  }

  ControlledTokenProxyFactory public controlledTokenProxyFactory;
  TicketProxyFactory public ticketProxyFactory;
  SingleRandomWinnerCoinFactory public singleRandomWinnerCoinFactory;

  constructor(
    SingleRandomWinnerCoinFactory _singleRandomWinnerCoinFactory,
    ControlledTokenProxyFactory _controlledTokenProxyFactory,
    TicketProxyFactory _ticketProxyFactory
  ) public {
    require(
      address(_singleRandomWinnerCoinFactory) != address(0),
      'SingleRandomWinnerBuilder/single-random-winner-factory-not-zero'
    );
    require(
      address(_controlledTokenProxyFactory) != address(0),
      'SingleRandomWinnerBuilder/controlled-token-proxy-factory-not-zero'
    );
    require(address(_ticketProxyFactory) != address(0), 'SingleRandomWinnerBuilder/ticket-proxy-factory-not-zero');
    ticketProxyFactory = _ticketProxyFactory;
    singleRandomWinnerCoinFactory = _singleRandomWinnerCoinFactory;
    controlledTokenProxyFactory = _controlledTokenProxyFactory;
  }

  function createSingleRandomWinner(
    PrizePool prizePool,
    SingleRandomWinnerConfig calldata config,
    uint8 decimals,
    address owner
  ) external returns (SingleRandomWinnerCoin) {
    PrizeStrategyConfig memory prizeStrategyConfig;
    prizeStrategyConfig.ticket = address(_createTicket(prizePool, config.ticketName, config.ticketSymbol, decimals));

    prizeStrategyConfig.sponsorship = address(
      _createControlledToken(prizePool, config.sponsorshipName, config.sponsorshipSymbol, decimals)
    );

    SingleRandomWinnerCoin prizeStrategy = singleRandomWinnerCoinFactory.create();
    prizeStrategy.initialize(
      config.prizePeriodStart,
      config.prizePeriodSeconds,
      prizePool,
      prizeStrategyConfig.ticket,
      prizeStrategyConfig.sponsorship,
      config.rngService,
      config.externalERC20Awards
    );

    prizeStrategy.transferOwnership(owner);

    emit SingleRandomWinnerCoinCreated(
      address(prizeStrategy),
      prizeStrategyConfig.ticket,
      prizeStrategyConfig.sponsorship
    );

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