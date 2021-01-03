const buidler = require("@nomiclabs/buidler")

let addresses = {
  106: {
    syx: "0x01Db6ACFA20562Ba835aE9F5085859580A0b1386",
    svlx: "0xb800D28E0dbb6C3D66c1d386c0ac37C187211eAE",
    rewardPoolId: 0, //vlxSyx reward pool id
    rngService: "0xc7c6Dd702dc22165f241fF75f347887fBAa7c9c2",
    registry: ""
  },
  111: {
    syx: "0x28a6312D786e9d7a78637dD137AbeF5332F3b2Aa",
    svlx: "0x6a63011a41Df162921E2eDF7f10fabb7C93F3FB0",
    bpt: "0x3FBaf23119a999336bb9bB0744bcC6f60540B4B4", //vlxSyx reward pool bpt token
    rewardPool: "0x2c140E4561ef42c20B60E600CA52B86147858AC5",
    rewardPoolId: 0, //vlxSyx reward pool id
    rngService: "0xB4fb2B1FBB995bBb9A2c8481c61c5Be1c63e081b",
    registry: "0xb7f78917e52D05346c7fbD82ea8006bF407886f4"
  },
  1337: {
    rewardPoolId: 0
  },
  31337: {
    rewardPoolId: 0
  }
}

const setup = async () => {
  const { ethers, getChainId, deployments, upgrades } = buidler
  const toWei = ethers.utils.parseEther

  let { deployer, rng, adminAccount, comptroller, reserveRegistry } = await getNamedAccounts()

  const chainId = parseInt(await getChainId(), 10)
  const isTestEnvironment = chainId === 31337 || chainId === 1337

  const [signer] = await ethers.getSigners()
  console.log(`Using wallet address: ${signer._address}`)

  let prizePeriodStart = 1609675200
  let prizePeriodSeconds = 60

  if (isTestEnvironment) {
    registry = await deployments.get("Reserve")
    addresses[chainId].registry = registry.address

    rngService = await deployments.get("RNGServiceMock")
    addresses[chainId].rngService = rngService.address

    svlx = await deployments.get("SVLX")
    addresses[chainId].svlx = svlx.address

    syx = await deployments.get("mockToken")
    addresses[chainId].syx = syx.address

    const bpt = await deployments.get("mockBpt")
    addresses[chainId].bpt = bpt.address
    const rewardPool = await deployments.get("mockRewardPool")
    addresses[chainId].rewardPool = rewardPool.address

    prizePeriodStart = 10
    prizePeriodSeconds = 10
  }

  syxSingleWinnerConfig = {
    proxyAdmin: ethers.constants.AddressZero,
    rngService: addresses[chainId].rngService,
    prizePeriodStart: prizePeriodStart,
    prizePeriodSeconds: prizePeriodSeconds,
    ticketName: "pooled Velas",
    ticketSymbol: "pVLX",
    sponsorshipName: "Sponsorship",
    sponsorshipSymbol: "SPON",
    ticketCreditLimitMantissa: toWei("0.1"),
    ticketCreditRateMantissa: toWei("0.001"),
    externalERC20Awards: [addresses[chainId].syx]
  }

  console.log({ syxSingleWinnerConfig })

  syxPrizePoolConfig = {
    token: addresses[chainId].svlx,
    maxExitFeeMantissa: toWei("0.5"),
    maxTimelockDuration: 1000
  }

  console.log({ syxPrizePoolConfig })

  let decimals = 18

  const { deploy } = deployments

  // Deploy the prize pool

  let initArgs = []

  initArgs = [
    addresses[chainId].registry,
    [],
    syxPrizePoolConfig.maxExitFeeMantissa.toString(),
    syxPrizePoolConfig.maxTimelockDuration
    // syxPrizePoolConfig.token
  ]

  console.log({ initArgs })

  const SyxPrizePoolFactory = await ethers.getContractFactory("SyxPrizePool")
  const syxPrizePool = await upgrades.deployProxy(SyxPrizePoolFactory, initArgs, { unsafeAllowCustomTypes: true })
  await syxPrizePool.deployed()
  console.log("PrizePool:", syxPrizePool.address)

  // const syxPrizePool = await deploy("SyxPrizePool", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: initArgs
  // })

  // Deploy ticket token

  initArgs = [syxSingleWinnerConfig.ticketName, syxSingleWinnerConfig.ticketSymbol, decimals, syxPrizePool.address]
  console.log({ initArgs })

  const TicketFactory = await ethers.getContractFactory("Ticket")
  const pVlx = await upgrades.deployProxy(TicketFactory, initArgs, { unsafeAllowCustomTypes: true })
  await pVlx.deployed()
  console.log("pVlx:", pVlx.address)

  // const pVlx = await deploy("Ticket", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: initArgs
  // })

  // Deploy sponsorship token

  initArgs = [
    syxSingleWinnerConfig.sponsorshipName,
    syxSingleWinnerConfig.sponsorshipSymbol,
    decimals,
    syxPrizePool.address
  ]
  console.log({ initArgs })

  const ControlledTokenFactory = await ethers.getContractFactory("ControlledToken")
  const sponsorship = await upgrades.deployProxy(ControlledTokenFactory, initArgs, { unsafeAllowCustomTypes: false })
  await sponsorship.deployed()
  console.log("sponsorship:", sponsorship.address)

  // const sponsorship = await deploy("ControlledToken", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: [
  //     syxSingleWinnerConfig.sponsorshipName,
  //     syxSingleWinnerConfig.sponsorshipSymbol,
  //     decimals,
  //     syxPrizePool.address
  //   ]
  // })

  // Deploy the strategy

  initArgs = [
    syxSingleWinnerConfig.prizePeriodStart,
    syxSingleWinnerConfig.prizePeriodSeconds,
    syxPrizePool.address,
    pVlx.address,
    sponsorship.address,
    addresses[chainId].rngService,
    syxSingleWinnerConfig.externalERC20Awards
  ]
  console.log({ initArgs })

  const SyxSingleWinnerFactory = await ethers.getContractFactory("SyxSingleWinner")
  const syxSingleWinner = await upgrades.deployProxy(SyxSingleWinnerFactory, initArgs, {
    unsafeAllowCustomTypes: true
  })
  await syxSingleWinner.deployed()
  console.log("syxSingleWinner:", syxSingleWinner.address)

  // const syxSingleWinner = await deploy("SyxSingleWinner", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: [
  //     syxSingleWinnerConfig.prizePeriodStart,
  //     syxSingleWinnerConfig.prizePeriodSeconds,
  //     syxPrizePool.address,
  //     pVlx.address,
  //     sponsorship.address,
  //     addresses[chainId].rngService,
  //     syxSingleWinnerConfig.externalERC20Awards
  //   ]
  // })

  const pVlxAddress = await syxSingleWinner.ticket()
  console.log({ pVlxAddress })
  const sponsorshipAddress = await syxSingleWinner.sponsorship()
  console.log({ sponsorshipAddress })

  await syxPrizePool.addControlledToken(pVlxAddress)
  await syxPrizePool.addControlledToken(sponsorshipAddress)

  await syxPrizePool.setPrizeStrategy(syxSingleWinner.address)

  await syxPrizePool.setCreditPlanOf(
    pVlxAddress,
    syxSingleWinnerConfig.ticketCreditRateMantissa,
    syxSingleWinnerConfig.ticketCreditLimitMantissa
  )

  // Deploy Sponsor

  initArgs = [
    syxPrizePool.address,
    pVlx.address,
    addresses[chainId].bpt,
    addresses[chainId].rewardPool,
    addresses[chainId].rewardPoolId
  ]
  console.log({ initArgs })

  const SponsorFactory = await ethers.getContractFactory("Sponsor")
  const sponsor = await upgrades.deployProxy(SponsorFactory, initArgs, { unsafeAllowCustomTypes: false })
  await sponsor.deployed()
  console.log("sponsor:", sponsor.address)

  // const sponsor = await deploy("Sponsor", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: [
  //     syxPrizePool.address,
  //     pVlx.address,
  //     addresses[chainId].bpt,
  //     addresses[chainId].rewardPool,
  //     addresses[chainId].rewardPoolId
  //   ]
  // })

  await syxSingleWinner.setSponsor(sponsor.address)
  await syxPrizePool.setSponsor(sponsor.address)
}

setup()
